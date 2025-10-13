//
//  ContentView.swift
//  EasyDial
//
//  Created by Rajesh Solanki on 9/13/25.
//

import SwiftUI
import Contacts
import UIKit
import PhotosUI
import MessageUI
import UserNotifications
import CallKit

// MARK: - Call Detector

class CallDetector: NSObject, ObservableObject {
    static let shared = CallDetector()
    private var callObserver: CXCallObserver?
    private let canUseCallKit: Bool
    
    @Published var isOnCall: Bool = false
    
    private override init() {
        // Check if user is in China - CallKit is restricted there
        let locale = Locale.current
        let regionCode = locale.region?.identifier ?? ""
        
        if regionCode == "CN" || regionCode == "CHN" {
            print("⚠️ Current locale is China (\(regionCode)) - CallKit cannot be used")
            canUseCallKit = false
        } else {
            canUseCallKit = true
            print("✅ CallKit enabled for region: \(regionCode)")
        }
        
        super.init()
        
        // Setup CallKit observer if allowed
        if canUseCallKit {
            callObserver = CXCallObserver()
            callObserver?.setDelegate(self, queue: DispatchQueue.main)
        }
    }
    
    var hasActiveCall: Bool {
        guard canUseCallKit, let callObserver = callObserver else {
            return false
        }
        return callObserver.calls.contains { !$0.hasEnded }
    }
}

extension CallDetector: CXCallObserverDelegate {
    func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        guard canUseCallKit else { return }
        
        let wasOnCall = isOnCall
        isOnCall = callObserver.calls.contains { !$0.hasEnded }
        
        print("📞 Call state changed:")
        print("  - Has ended: \(call.hasEnded)")
        print("  - Is outgoing: \(call.isOutgoing)")
        print("  - On hold: \(call.isOnHold)")
        print("  - Has connected: \(call.hasConnected)")
        print("  - Currently on call: \(isOnCall)")
        
        // If call just ended and we were waiting to send notifications
        if wasOnCall && !isOnCall {
            print("📞 Call ended - checking if we need to send notifications")
            NotificationCenter.default.post(name: NSNotification.Name("CallEnded"), object: nil)
        }
    }
}

// MARK: - Image Storage Manager

class ImageStorageManager {
    static let shared = ImageStorageManager()
    
    private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private let imagesDirectory: URL
    
    private init() {
        imagesDirectory = documentsDirectory.appendingPathComponent("ContactImages")
        createImagesDirectoryIfNeeded()
    }
    
    private func createImagesDirectoryIfNeeded() {
        if !FileManager.default.fileExists(atPath: imagesDirectory.path) {
            try? FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        }
    }
    
    func saveImage(_ imageData: Data, for contactId: String) -> String? {
        let fileName = "\(contactId)_\(UUID().uuidString).jpg"
        let fileURL = imagesDirectory.appendingPathComponent(fileName)
        
        do {
            try imageData.write(to: fileURL)
            return fileName
        } catch {
            print("Failed to save image: \(error)")
            return nil
        }
    }
    
    func loadImage(named fileName: String) -> UIImage? {
        let fileURL = imagesDirectory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }
    
    func deleteImage(named fileName: String) {
        let fileURL = imagesDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    func cleanupOrphanedImages(validFileNames: Set<String>) {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: imagesDirectory.path) else { return }
        
        for file in files {
            if !validFileNames.contains(file) {
                deleteImage(named: file)
            }
        }
    }
}

// MARK: - Communication Enums

enum CommunicationMethod: String, CaseIterable, Codable {
    case voiceCall = "Voice Call"
    case videoCall = "Video Call"
    case textMessage = "Text Message"
    
    var icon: String {
        switch self {
        case .voiceCall: return "phone.fill"
        case .videoCall: return "video.fill"
        case .textMessage: return "message.fill"
        }
    }
    
    var iconName: String {
        return icon
    }
    
    var displayName: String {
        return self.rawValue
    }
}

enum CommunicationApp: String, CaseIterable, Codable {
    case phoneMessage = "Phone iOS"
    case whatsapp = "WhatsApp"
    case telegram = "Telegram"
    case facetime = "FaceTime"
    case signal = "Signal"
    case viber = "Viber"
    
    var icon: String {
        switch self {
        case .phoneMessage: return "phone.fill"
        case .whatsapp: return "message.fill"
        case .telegram: return "paperplane.fill"
        case .facetime: return "video.fill"
        case .signal: return "message.fill"
        case .viber: return "message.fill"
        }
    }
    
    var iconName: String {
        return icon
    }
    
    var displayName: String {
        return self.rawValue
    }
    
    var urlScheme: String {
        switch self {
        case .phoneMessage: return "tel"
        case .whatsapp: return "whatsapp"
        case .telegram: return "tg"
        case .facetime: return "facetime"
        case .signal: return "sgnl"
        case .viber: return "viber"
        }
    }
    
    var bundleIdentifier: String {
        switch self {
        case .phoneMessage: return "com.apple.mobilephone"
        case .whatsapp: return "net.whatsapp.WhatsApp"
        case .telegram: return "ph.telegra.Telegraph"
        case .facetime: return "com.apple.facetime"
        case .signal: return "org.whispersystems.signal"
        case .viber: return "com.viber"
        }
    }
}

/// Main view that displays favorites from the Contacts app
struct ContentView: View {
    @StateObject private var contactsManager = ContactsManager()
    @StateObject private var callDetector = CallDetector.shared
    @State private var showingAddToFavorites = false
    @State private var isEditMode = false
    @State private var currentContactIndex = 0
    @State private var showingContactDetail = false
    @State private var lastViewedContactIndex = 0
    @State private var hasLoadedInitialIndex = false
    @State private var showingInfoMenu = false
    @State private var showingHelp = false
    @State private var showingAbout = false
    @State private var showingSuggestions = false
    @AppStorage("alwaysBringToFocus") private var alwaysBringToFocus = false
    @State private var didEnterBackground = false
    @State private var waitingForCallToEnd = false
    
    // Detection variables for screen lock vs app switch
    @State private var didResignActive = false
    @State private var didSeeInactive = false
    @State private var switchedToAnotherApp = false
    @Environment(\.scenePhase) private var scenePhase
    
    private let lastViewedContactKey = "lastViewedContactIndex"
    
    var body: some View {
        NavigationStack {
            Group {
                if contactsManager.favorites.isEmpty && contactsManager.isLoadingContactsInBackground {
                    ProgressView("Loading contacts...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if contactsManager.favorites.isEmpty {
                    emptyStateView
                } else if hasLoadedInitialIndex && lastViewedContactIndex != -1 && !showingContactDetail {
                    // Show contact detail view directly if we have a valid lastViewedContactIndex
                    ContactDetailViewDirect(
                        favorites: contactsManager.favorites,
                        contactsManager: contactsManager,
                        initialIndex: lastViewedContactIndex,
                        onIndexChanged: { newIndex in
                            print("🔍 ContactDetailView onIndexChanged: \(newIndex)")
                            lastViewedContactIndex = newIndex
                            // Save to UserDefaults whenever the index changes
                            print("💾 Saving lastViewedContactIndex: \(newIndex)")
                            
                            // Debug: Check if there's already large data in UserDefaults
                            if let existingData = UserDefaults.standard.data(forKey: "favorites") {
                                print("⚠️ WARNING: Existing favorites data in UserDefaults: \(existingData.count) bytes")
                                if existingData.count > 4 * 1024 * 1024 {
                                    print("🚨 CRITICAL: Existing data exceeds 4MB limit!")
                                }
                            }
                            
                            // Debug: Check total UserDefaults size before saving
                            let userDefaults = UserDefaults.standard
                            let allKeys = userDefaults.dictionaryRepresentation().keys
                            var totalSize = 0
                            for key in allKeys {
                                if let data = userDefaults.data(forKey: key) {
                                    totalSize += data.count
                                    if data.count > 100000 { // 100KB
                                        print("🔍 Large UserDefaults key '\(key)': \(data.count) bytes")
                                    }
                                }
                            }
                            print("🔍 Total UserDefaults size: \(totalSize) bytes")
                            
                            // Check if we need to save favorites with clean data
                            if let existingData = UserDefaults.standard.data(forKey: "favorites"),
                               existingData.count > 1000000 { // 1MB threshold
                                print("🔄 Large favorites data detected (\(existingData.count) bytes), saving clean version...")
                                // Save favorites with clean data (no large CNContact image data)
                                contactsManager.saveFavorites()
                            }
                            
                            UserDefaults.standard.set(newIndex, forKey: lastViewedContactKey)
                            print("✅ Saved lastViewedContactIndex: \(newIndex)")
                        },
                        onReturnToFavorites: {
                            // Return to favorites view
                            lastViewedContactIndex = -1
                            UserDefaults.standard.set(-1, forKey: lastViewedContactKey)
                            print("🔍 Returned to favorites view")
                        }
                    )
                } else {
                    favoritesListView
                }
            }
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !contactsManager.favorites.isEmpty {
                        Button(isEditMode ? "Done" : "Add & Edit") {
                            withAnimation {
                                isEditMode.toggle()
                            }
                        }
                        .accessibilityLabel(isEditMode ? "Exit edit mode" : "Enter edit mode")
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    if !contactsManager.favorites.isEmpty && !isEditMode {
                        Button("My Dial") {
                            // If currently -1, change to 0, otherwise keep current value
                            if lastViewedContactIndex == -1 {
                                lastViewedContactIndex = 0
                                print("🔍 My Dial button pressed, changed lastViewedContactIndex from -1 to 0")
                                // The view will automatically update to show the contact detail view
                                // since lastViewedContactIndex is now != -1
                            } else {
                                print("🔍 My Dial button pressed, keeping lastViewedContactIndex: \(lastViewedContactIndex)")
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(8)
                        .font(.title2)
                        .fontWeight(.bold)
                        .disabled(contactsManager.favorites.isEmpty)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if isEditMode {
                            Button {
                                showingAddToFavorites = true
                            } label: {
                                Image(systemName: "plus")
                            }
                            .accessibilityLabel("Add to favorites")
                            .padding(.trailing, 8)
                        }
                        
                        Button(action: {
                            showingInfoMenu = true
                        }) {
                            Image(systemName: "info.circle")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddToFavorites) {
                AddToFavoritesView(contactsManager: contactsManager)
            }
            .sheet(isPresented: $showingInfoMenu) {
                InfoMenuView(
                    showingHelp: $showingHelp,
                    showingAbout: $showingAbout,
                    showingSuggestions: $showingSuggestions
                )
            }
            .sheet(isPresented: $showingHelp) {
                HelpView()
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            .sheet(isPresented: $showingSuggestions) {
                SuggestionView()
            }
        }
        .onAppear {
            // Load favorites first (fast) to show the page immediately
            contactsManager.loadFavorites()
            
            // Load contacts in background after page is displayed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                contactsManager.requestAccess()
            }
            
            // Request notification permission
            requestNotificationPermission()
        }
        .onChange(of: contactsManager.favorites) {
            // Load the last viewed contact index from UserDefaults when contacts are loaded
            let savedIndex = UserDefaults.standard.integer(forKey: lastViewedContactKey)
            print("🔍 Loading saved index: \(savedIndex), favorites count: \(contactsManager.favorites.count)")
            
            // Handle no contacts case
            if contactsManager.favorites.isEmpty {
                lastViewedContactIndex = -1
                print("🔍 No contacts available, set lastViewedContactIndex to -1")
            } else if savedIndex >= 0 && savedIndex < contactsManager.favorites.count {
                lastViewedContactIndex = savedIndex
                print("🔍 Set lastViewedContactIndex to: \(lastViewedContactIndex)")
                
                // Note: The contact detail view will be shown directly in the main view
                // if lastViewedContactIndex != -1, no need for separate navigation
            } else {
                // Invalid saved index - keep at -1 to show favorites page
                lastViewedContactIndex = -1
                print("🔍 Saved index \(savedIndex) is invalid, keeping lastViewedContactIndex at -1 to show favorites page")
            }
            
            // Mark that we've loaded the initial index
            hasLoadedInitialIndex = true
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .active:
                print("🟢 Screen is ACTIVE - App is in foreground")
                // Reset flags when becoming active
                didResignActive = false
                didSeeInactive = false
            case .inactive:
                print("🟡 Screen is INACTIVE - App is transitioning")
                // Mark that we saw the INACTIVE state
                didSeeInactive = true
            case .background:
                print("🔴 Screen is OFF/BACKGROUND - App went to background or screen locked")
                // Display switchedToAnotherApp state after background message
                print("📊 switchedToAnotherApp = \(switchedToAnotherApp)")
            @unknown default:
                print("⚪️ Unknown screen state")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            print("⚠️ App will resign active - Screen is resigning notification")
            // Save the last viewed contact index when app becomes inactive
            UserDefaults.standard.set(lastViewedContactIndex, forKey: lastViewedContactKey)
            // Mark that we've received the willResignActive notification
            didResignActive = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            print("🌙 App entered background - Screen is in background notification")
            
            // Check the sequence to determine if user switched to another app
            if didResignActive {
                if didSeeInactive {
                    // Sequence: willResignActive → INACTIVE → didEnterBackground
                    switchedToAnotherApp = true
                    print("✅ Sequence: willResignActive → INACTIVE → didEnterBackground → switchedToAnotherApp = true")
                } else {
                    // Sequence: willResignActive → didEnterBackground (no INACTIVE)
                    switchedToAnotherApp = false
                    print("✅ Sequence: willResignActive → didEnterBackground (no INACTIVE) → switchedToAnotherApp = false (screen lock)")
                }
            }
            
            // Only send notifications if user actually switched to another app
            if switchedToAnotherApp && alwaysBringToFocus {
                didEnterBackground = true
                
                // Check if user is on a call
                if callDetector.isOnCall {
                    print("📞 User is on a call - will send notifications after call ends")
                    waitingForCallToEnd = true
                } else {
                    print("📱 User switched to another app (not on call) - sending notifications")
                    scheduleReturnNotification()
                }
            } else if !switchedToAnotherApp {
                print("🔒 Screen locked (no app switch) - NOT sending notifications")
            }
            
            // Reset flags
            didResignActive = false
            didSeeInactive = false
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            print("☀️ App became active - Screen is ON and app is in foreground")
            print("🔄 didEnterBackground: \(didEnterBackground), alwaysBringToFocus: \(alwaysBringToFocus)")
            
            // Cancel any pending notifications when returning to app
            cancelReturnNotification()
            
            // Handle returning from background
            if didEnterBackground && alwaysBringToFocus {
                print("🔄 App returning to foreground with 'Always Bring to Focus' enabled")
                print("🔄 Current view should show contact at index: \(lastViewedContactIndex)")
                // Reset the flags
                didEnterBackground = false
                waitingForCallToEnd = false
                
                // The contact detail view should already be showing the correct contact
                // No need to toggle showingContactDetail - just let it stay as is
            } else if didEnterBackground {
                // Reset flags even if setting is disabled
                didEnterBackground = false
                waitingForCallToEnd = false
                print("🔄 App returning to foreground (Always Bring to Focus disabled)")
            }
            
            // Reset detection flags
            didResignActive = false
            didSeeInactive = false
            switchedToAnotherApp = false
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            print("🌅 App will enter foreground - Screen turning ON or returning to app")
            // Reset flags
            didResignActive = false
            didSeeInactive = false
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CallEnded"))) { _ in
            print("📞 Call ended notification received")
            
            // If we were waiting for call to end and still in background, send notifications now
            if waitingForCallToEnd && didEnterBackground && alwaysBringToFocus {
                print("📱 Call ended - now sending notifications")
                waitingForCallToEnd = false
                scheduleReturnNotification()
            }
        }
    }
    
    /// Request notification permissions
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("📱 Notification permission granted")
            } else if let error = error {
                print("❌ Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    /// Schedule a notification to return to My Dial
    private func scheduleReturnNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Return to My Dial"
        content.body = "Tap to continue using My Dial"
        content.sound = .default
        content.categoryIdentifier = "RETURN_TO_APP"
        
        // Schedule first notification after 2 seconds
        let firstTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let firstRequest = UNNotificationRequest(
            identifier: "returnToMyDial_first",
            content: content,
            trigger: firstTrigger
        )
        
        UNUserNotificationCenter.current().add(firstRequest) { error in
            if let error = error {
                print("❌ Failed to schedule first notification: \(error.localizedDescription)")
            } else {
                print("📱 First notification scheduled successfully (2 seconds)")
            }
        }
        
        // Schedule repeating notification every 60 seconds (Apple's minimum)
        // This will start after the first one
        let repeatingTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: true)
        let repeatingRequest = UNNotificationRequest(
            identifier: "returnToMyDial_repeating",
            content: content,
            trigger: repeatingTrigger
        )
        
        UNUserNotificationCenter.current().add(repeatingRequest) { error in
            if let error = error {
                print("❌ Failed to schedule repeating notification: \(error.localizedDescription)")
            } else {
                print("📱 Repeating notification scheduled successfully (every 60 seconds)")
            }
        }
    }
    
    /// Cancel the return notification
    private func cancelReturnNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["returnToMyDial_first", "returnToMyDial_repeating"])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["returnToMyDial_first", "returnToMyDial_repeating"])
        print("📱 All notifications cancelled")
    }
    
    /// View shown when no favorites are available
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "star.circle")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            Text("No Favorites")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Add contacts to your favorites for quick access")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Add to Favorites") {
                showingAddToFavorites = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// List view displaying all favorite contacts
    private var favoritesListView: some View {
        List {
            ForEach($contactsManager.favorites) { $favorite in
                FavoriteContactRow(favorite: $favorite, isEditMode: isEditMode, contactsManager: contactsManager)
                    .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
            }
            .onDelete(perform: isEditMode ? deleteFavorites : nil)
            .onMove(perform: isEditMode ? moveFavorites : nil)
            
            // Show subtle loading indicator if contacts are loading in background
            if contactsManager.isLoadingContactsInBackground {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading contacts...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, isEditMode ? .constant(.active) : .constant(.inactive))
    }
    
    /// Deletes favorites at the specified indices
    private func deleteFavorites(offsets: IndexSet) {
        contactsManager.removeFavorites(at: offsets)
    }
    
    /// Moves favorites from source indices to destination index
    private func moveFavorites(from source: IndexSet, to destination: Int) {
        contactsManager.moveFavorites(from: source, to: destination)
    }
}

/// Row view for displaying a favorite contact
struct FavoriteContactRow: View {
    @Binding var favorite: FavoriteContact
    let isEditMode: Bool
    @ObservedObject var contactsManager: ContactsManager
    @State private var showingConfig = false
    
    init(favorite: Binding<FavoriteContact>, isEditMode: Bool, contactsManager: ContactsManager) {
        self._favorite = favorite
        self.isEditMode = isEditMode
        self.contactsManager = contactsManager
//        print("🔍 FavoriteContactRow created for: //\(favorite.wrappedValue.displayName), isEditMode: \(isEditMode)")
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Contact photo (uses custom image if set)
            ContactPhotoView(contactIdentifier: favorite.contactIdentifier, contactGivenName: favorite.contactGivenName, contactFamilyName: favorite.contactFamilyName, customImageFileName: $favorite.customImageFileName, size: 50)
            
            // Contact info
            VStack(alignment: .leading, spacing: 4) {
                Text(favorite.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(favorite.phoneNumber)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Show email address if available
                if let email = favorite.emailAddress, !email.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "envelope.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                        Text(email)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Show communication method and app
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Image(systemName: favorite.communicationMethod.icon)
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text(favorite.communicationMethod.rawValue)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Image(systemName: favorite.communicationApp.icon)
                            .foregroundColor(.green.opacity(0.7))
                            .font(.caption)
                        Text(favorite.communicationApp.rawValue)
                            .font(.caption)
                            .foregroundColor(.green.opacity(0.7))
                    }
                }
                
            }
            
            Spacer()
            
            // Action button
            if isEditMode {
                Button {
                    showingConfig = true
                } label: {
                    Image(systemName: "gear")
                        .foregroundColor(.gray)
                        .frame(width: 44, height: 44)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Configure \(favorite.displayName)")
            } else {
                Button {
                    initiateCommunication()
                } label: {
                    Image(systemName: favorite.communicationMethod.icon)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.green.opacity(0.8))
                        .clipShape(Circle())
                }
                .accessibilityLabel("\(favorite.communicationMethod.rawValue) \(favorite.displayName)")
            }
        }
        .padding(.vertical, 4)
        .onTapGesture {
            if isEditMode {
                showingConfig = true
            } else {
                initiateCommunication()
            }
        }
        .sheet(isPresented: $showingConfig) {
            CommunicationConfigView(favorite: $favorite, contactsManager: contactsManager)
        }
        .onChange(of: favorite.customImageFileName) {
            // Save favorites when custom image file name changes
            contactsManager.saveFavorites()
        }
    }
    
    /// Initiates communication based on the selected method and app
    private func initiateCommunication() {
        // For FaceTime, use email address if available, otherwise clean the phone number
        let phoneNumber: String
        var isEmail = false
        
        if let email = favorite.emailAddress, !email.isEmpty, (favorite.communicationApp == .facetime || favorite.communicationApp == .phoneMessage) {
            // Use email address as-is for FaceTime
            phoneNumber = email
            isEmail = true
        } else {
            // Clean the phone number - keep only digits and +, then remove +
            let cleanPhoneNumber = favorite.phoneNumber.filter { $0.isNumber || $0 == "+" }
            phoneNumber = cleanPhoneNumber.replacingOccurrences(of: "+", with: "")
            isEmail = false
        }
        
        // Validate: Email addresses cannot be used with certain apps
        if isEmail && (favorite.communicationApp == .phoneMessage || favorite.communicationApp == .whatsapp || favorite.communicationApp == .telegram || favorite.communicationApp == .signal || favorite.communicationApp == .viber) {
            // Show alert to user
            DispatchQueue.main.async {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let viewController = windowScene.windows.first?.rootViewController {
                    let alert = UIAlertController(
                        title: "Cannot Make Call",
                        message: "Email addresses cannot be used with \(favorite.communicationApp.displayName). Please use FaceTime for email-based calls, or add a phone number for this contact.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    viewController.present(alert, animated: true)
                }
            }
            print("⚠️ Cannot use email address with \(favorite.communicationApp.displayName)")
            return // Exit without processing
        }
        
        var urlString: String
        
        
        switch (favorite.communicationMethod, favorite.communicationApp) {
        case (.voiceCall, .phoneMessage):
            urlString = "tel:\(favorite.phoneNumber)" // Use original format to avoid prompts
        case (.videoCall, .phoneMessage):
            urlString = "facetime:\(phoneNumber)"
        case (.textMessage, .phoneMessage):
            urlString = "sms:\(phoneNumber)"
        case (.voiceCall, .whatsapp):
            urlString = "whatsapp://calluser/?phone=\(phoneNumber)"
        case (.videoCall, .whatsapp):
            urlString = "whatsapp://calluser/?phone=\(phoneNumber)"
        case (.textMessage, .whatsapp):
            urlString = "whatsapp://send?phone=\(phoneNumber)"
        case (.voiceCall, .telegram):
            urlString = "tg://resolve?domain=\(phoneNumber)"
        case (.videoCall, .telegram):
            urlString = "tg://resolve?domain=\(phoneNumber)"
        case (.textMessage, .telegram):
            urlString = "tg://resolve?domain=\(phoneNumber)"
        case (.voiceCall, .facetime):
            urlString = "facetime-audio:\(phoneNumber)"
        case (.videoCall, .facetime):
            urlString = "facetime:\(phoneNumber)"
        case (.textMessage, .facetime):
            urlString = "sms:\(phoneNumber)"
        case (.voiceCall, .signal):
            urlString = "sgnl://send?phone=\(phoneNumber)"
        case (.videoCall, .signal):
            urlString = "sgnl://send?phone=\(phoneNumber)"
        case (.textMessage, .signal):
            urlString = "sgnl://send?phone=\(phoneNumber)"
        case (.voiceCall, .viber):
            urlString = "viber://chat?number=\(phoneNumber)"
        case (.videoCall, .viber):
            urlString = "viber://chat?number=\(phoneNumber)"
        case (.textMessage, .viber):
            urlString = "viber://chat?number=\(phoneNumber)"
        }
        
        if let url = URL(string: urlString) {
            print("🔍 Communication Debug: 🔍 Method: \(favorite.communicationMethod.rawValue) 🔍 App: \(favorite.communicationApp.rawValue) 🔍 Original Phone: \(favorite.phoneNumber) 🔍 Cleaned Phone: \(phoneNumber) 🔍 Final URL: \(urlString) 🔍 About to open URL: \(urlString)")
            DispatchQueue.main.async {
                let options: [UIApplication.OpenExternalURLOptionsKey: Any] = [
                    .universalLinksOnly: false  // Allow custom URL schemes
                ]
                UIApplication.shared.open(url, options: options) { success in
                    print("🔍 URL opened successfully: \(success)")
                    if !success {
                        print("🔍 Failed to open URL: \(urlString)")
                    }
                }
            }
        }
    }
    
    /// Legacy method for backward compatibility
    private func callContact(_ phoneNumber: String) {
        let phoneNumber = phoneNumber.filter { $0.isNumber }
        if let url = URL(string: "tel:\(phoneNumber)") {
            DispatchQueue.main.async {
                let options: [UIApplication.OpenExternalURLOptionsKey: Any] = [
                    .universalLinksOnly: false
                ]
                UIApplication.shared.open(url, options: options) { success in
                    print("🔍 Legacy call URL opened successfully: \(success)")
                }
            }
        }
    }
}

/// View for adding contacts to favorites
struct AddToFavoritesView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var contactsManager: ContactsManager
    @State private var searchText = ""
    @State private var selectedContacts: Set<String> = []
    
    var body: some View {
        NavigationStack {
            VStack {
                // Selection counter
                if !selectedContacts.isEmpty {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text("\(selectedContacts.count) contact\(selectedContacts.count == 1 ? "" : "s") selected")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                
                if searchText.isEmpty {
                    Text("Select a contact to add to favorites")
                        .font(.headline)
                        .padding()
                }
                
                List(filteredContacts) { contact in
                    ContactRow(contact: contact, contactsManager: contactsManager, selectedContacts: $selectedContacts)
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                }
                .searchable(text: $searchText, prompt: "Search contacts")
            }
            .navigationTitle("Add to Favorites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        // Add all selected contacts to favorites
                        for selectedId in selectedContacts {
                            // Check if it's a single contact or individual phone/email selection
                            if selectedId.contains("_phone_") {
                                // Individual phone number selection
                                let components = selectedId.split(separator: "_")
                                if components.count >= 3,
                                   let contact = filteredContacts.first(where: { $0.identifier == String(components[0]) }) {
                                    let phoneId = components[2...].joined(separator: "_")
                                    if let phoneNumber = contact.phoneNumbers.first(where: { $0.identifier == phoneId }) {
                                        contactsManager.addToFavorites(contact: contact, phoneNumber: phoneNumber.value.stringValue, emailAddress: nil)
                                    }
                                }
                            } else if selectedId.contains("_email_") {
                                // Individual email selection
                                let components = selectedId.split(separator: "_")
                                if components.count >= 3,
                                   let contact = filteredContacts.first(where: { $0.identifier == String(components[0]) }) {
                                    let emailId = components[2...].joined(separator: "_")
                                    if let email = contact.emailAddresses.first(where: { $0.identifier == emailId }) {
                                        // For email-only contacts, use email as the "phone number" placeholder
                                        let emailString = email.value as String
                                        contactsManager.addToFavorites(contact: contact, phoneNumber: emailString, emailAddress: emailString)
                                    }
                                }
                            } else {
                                // Single contact selection (no underscore)
                                if let contact = filteredContacts.first(where: { $0.identifier == selectedId }) {
                                    if contact.phoneNumbers.count == 1,
                                       let phoneNumber = contact.phoneNumbers.first?.value.stringValue {
                                        contactsManager.addToFavorites(contact: contact, phoneNumber: phoneNumber, emailAddress: nil)
                                    } else if contact.emailAddresses.count == 1 {
                                        let emailString = contact.emailAddresses.first?.value as String? ?? ""
                                        contactsManager.addToFavorites(contact: contact, phoneNumber: emailString, emailAddress: emailString)
                                    }
                                }
                            }
                        }
                        dismiss()
                    }
                }
            }
        }
    }
    
    /// Contacts filtered by search text
    private var filteredContacts: [CNContact] {
        // First filter to only show valid contacts with names and phone numbers
        let validContacts = contactsManager.allContacts.filter { contact in
            let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
            let hasValidName = !fullName.isEmpty && fullName.count > 1
            let hasPhoneNumber = !contact.phoneNumbers.isEmpty
            
            return hasValidName && hasPhoneNumber
        }
        
        if searchText.isEmpty {
            return validContacts
        } else {
            return validContacts.filter { contact in
                let fullName = "\(contact.givenName) \(contact.familyName)".lowercased()
                return fullName.contains(searchText.lowercased())
            }
        }
    }
}

// (No additional utilities)

/// Row view for displaying a contact in the add to favorites list
struct ContactRow: View {
    let contact: CNContact
    @ObservedObject var contactsManager: ContactsManager
    @Binding var selectedContacts: Set<String>
    @State private var isSelected: Bool = false
    
    private var totalContactMethods: Int {
        contact.phoneNumbers.count + contact.emailAddresses.count
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                // Contact photo
                ContactPhotoView(contactIdentifier: contact.identifier, contactGivenName: contact.givenName, contactFamilyName: contact.familyName, customImageFileName: .constant(nil), size: 40)
                
                // Contact info
                VStack(alignment: .leading, spacing: 2) {
                    let displayName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                    Text(displayName.isEmpty ? "Unknown Contact" : displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if totalContactMethods == 1 && contact.phoneNumbers.count == 1 {
                        Text(contact.phoneNumbers.first?.value.stringValue ?? "")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else if totalContactMethods == 1 && contact.emailAddresses.count == 1 {
                        Text(contact.emailAddresses.first?.value as String? ?? "")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(contact.phoneNumbers.count) phone\(contact.phoneNumbers.count == 1 ? "" : "s"), \(contact.emailAddresses.count) email\(contact.emailAddresses.count == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Select/Toggle button
                Button {
                    if totalContactMethods == 1 {
                        // Single contact method - toggle selection (visual only)
                        if contact.phoneNumbers.count == 1 && contact.phoneNumbers.first?.value.stringValue != nil {
                            if isSelected {
                                // Already selected - unselect
                                isSelected = false
                                selectedContacts.remove(contact.identifier)
                            } else {
                                // Not selected - select (will be added to favorites when session ends)
                                isSelected = true
                                selectedContacts.insert(contact.identifier)
                            }
                        } else if contact.emailAddresses.count == 1 {
                            if isSelected {
                                // Already selected - unselect
                                isSelected = false
                                selectedContacts.remove(contact.identifier)
                            } else {
                                // Not selected - select (will be added to favorites when session ends)
                                isSelected = true
                                selectedContacts.insert(contact.identifier)
                            }
                        }
                    }
                    // For multiple contact methods, users must select individual ones below
                } label: {
                    Image(systemName: totalContactMethods == 1 ? (isSelected ? "star.fill" : "star") : "star.circle")
                        .foregroundColor(totalContactMethods == 1 ? (isSelected ? .yellow : .gray) : .gray)
                        .font(.title2)
                }
                .accessibilityLabel(totalContactMethods == 1 ? "Add to favorites" : "Select individual contact methods below")
                .disabled(totalContactMethods > 1)
            }
            
            // Show all phone numbers and emails if multiple contact methods
            if totalContactMethods > 1 {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tap stars to add/remove:")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.leading, 56)
                        .padding(.bottom, 4)
                    
                    ForEach(contact.phoneNumbers, id: \.identifier) { phoneNumber in
                        PhoneNumberRow(
                            contact: contact,
                            phoneNumber: phoneNumber,
                            contactsManager: contactsManager,
                            selectedContacts: $selectedContacts
                        )
                        .id("\(contact.identifier)_phone_\(phoneNumber.identifier)")
                    }
                    
                    ForEach(contact.emailAddresses, id: \.identifier) { email in
                        EmailAddressRow(
                            contact: contact,
                            email: email,
                            contactsManager: contactsManager,
                            selectedContacts: $selectedContacts
                        )
                        .id("\(contact.identifier)_email_\(email.identifier)")
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Row view for individual phone number selection
struct PhoneNumberRow: View {
    let contact: CNContact
    let phoneNumber: CNLabeledValue<CNPhoneNumber>
    @ObservedObject var contactsManager: ContactsManager
    @Binding var selectedContacts: Set<String>
    @State private var isSelected: Bool = false
    
    private var phoneString: String {
        phoneNumber.value.stringValue
    }
    
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "phone.fill")
                    .font(.caption)
                    .foregroundColor(.blue)
                Text(phoneString)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.leading, 56)
            
            Spacer()
            
            Button(action: {
                if isSelected {
                    // Already selected - unselect
                    isSelected = false
                    let phoneId = "\(contact.identifier)_phone_\(phoneNumber.identifier)"
                    selectedContacts.remove(phoneId)
                } else {
                    // Not selected - select (will be added to favorites when session ends)
                    isSelected = true
                    let phoneId = "\(contact.identifier)_phone_\(phoneNumber.identifier)"
                    selectedContacts.insert(phoneId)
                }
            }) {
                Image(systemName: isSelected ? "star.fill" : "star")
                    .foregroundColor(isSelected ? .yellow : .gray)
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

/// Row view for individual email address selection (for FaceTime)
struct EmailAddressRow: View {
    let contact: CNContact
    let email: CNLabeledValue<NSString>
    @ObservedObject var contactsManager: ContactsManager
    @Binding var selectedContacts: Set<String>
    @State private var isSelected: Bool = false
    
    private var emailString: String {
        email.value as String
    }
    
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "envelope.fill")
                    .font(.caption)
                    .foregroundColor(.green)
                Text(emailString)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.leading, 56)
            
            Spacer()
            
            Button(action: {
                if isSelected {
                    // Already selected - unselect
                    isSelected = false
                    let emailId = "\(contact.identifier)_email_\(email.identifier)"
                    selectedContacts.remove(emailId)
                } else {
                    // Not selected - select (will be added to favorites when session ends)
                    isSelected = true
                    let emailId = "\(contact.identifier)_email_\(email.identifier)"
                    selectedContacts.insert(emailId)
                }
            }) {
                Image(systemName: isSelected ? "star.fill" : "star")
                    .foregroundColor(isSelected ? .yellow : .gray)
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

/// Reusable view for displaying contact photos with fallback to initials
struct ContactPhotoView: View {
    let contactIdentifier: String
    let contactGivenName: String
    let contactFamilyName: String
    @Binding var customImageFileName: String?
    let size: CGFloat
    
    init(contactIdentifier: String, contactGivenName: String, contactFamilyName: String, customImageFileName: Binding<String?>, size: CGFloat = 50) {
        self.contactIdentifier = contactIdentifier
        self.contactGivenName = contactGivenName
        self.contactFamilyName = contactFamilyName
        self._customImageFileName = customImageFileName
        self.size = size
    }
    
    var body: some View {
        Group {
            if let fileName = customImageFileName, let uiImage = ImageStorageManager.shared.loadImage(named: fileName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                // Try to load contact image on-demand if not available
                ContactImageOnDemandView(contactIdentifier: contactIdentifier, size: size)
            }
        }
        .id("\(contactIdentifier)_\(customImageFileName ?? "")")
    }
}

/// View that loads contact images on-demand to avoid large data in memory
struct ContactImageOnDemandView: View {
    let contactIdentifier: String
    let size: CGFloat
    @State private var contactImage: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if let image = contactImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                // Fallback to initials while loading
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: size, height: size)
                    .overlay {
                        Text("?")
                            .font(.system(size: size * 0.4, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    .onAppear {
                        loadContactImageOnDemand()
                    }
            }
        }
    }
    
    private func loadContactImageOnDemand() {
        guard !isLoading else { return }
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let store = CNContactStore()
            do {
                let contact = try store.unifiedContact(withIdentifier: contactIdentifier, keysToFetch: [
                    CNContactImageDataKey as CNKeyDescriptor,
                    CNContactThumbnailImageDataKey as CNKeyDescriptor
                ])
                
                if let imageData = contact.thumbnailImageData ?? contact.imageData,
                   let uiImage = UIImage(data: imageData) {
                    DispatchQueue.main.async {
                        self.contactImage = uiImage
                        self.isLoading = false
                    }
                } else {
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
    }
}

/// Rectangular version of ContactImageOnDemandView for larger displays
struct ContactImageOnDemandRectangularView: View {
    let contactIdentifier: String
    let width: CGFloat
    let height: CGFloat
    @State private var contactImage: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if let image = contactImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
            } else {
                // Fallback to initials while loading
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: width, height: height)
                    .overlay {
                        Text("?")
                            .font(.system(size: min(width, height) * 0.3, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    .onAppear {
                        loadContactImageOnDemand()
                    }
            }
        }
    }
    
    private func loadContactImageOnDemand() {
        guard !isLoading else { return }
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let store = CNContactStore()
            do {
                let contact = try store.unifiedContact(withIdentifier: contactIdentifier, keysToFetch: [
                    CNContactImageDataKey as CNKeyDescriptor,
                    CNContactThumbnailImageDataKey as CNKeyDescriptor
                ])
                
                if let imageData = contact.thumbnailImageData ?? contact.imageData,
                   let uiImage = UIImage(data: imageData) {
                    DispatchQueue.main.async {
                        self.contactImage = uiImage
                        self.isLoading = false
                    }
                } else {
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
    }
}

/// Rectangular version of ContactPhotoView for larger displays
struct ContactPhotoViewRectangular: View {
    let contactIdentifier: String
    let contactGivenName: String
    let contactFamilyName: String
    @Binding var customImageFileName: String?
    let width: CGFloat
    let height: CGFloat
    
    init(contactIdentifier: String, contactGivenName: String, contactFamilyName: String, customImageFileName: Binding<String?>, width: CGFloat, height: CGFloat) {
        self.contactIdentifier = contactIdentifier
        self.contactGivenName = contactGivenName
        self.contactFamilyName = contactFamilyName
        self._customImageFileName = customImageFileName
        self.width = width
        self.height = height
    }
    
    var body: some View {
        Group {
            if let fileName = customImageFileName, let uiImage = ImageStorageManager.shared.loadImage(named: fileName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
            } else {
                // Try to load contact image on-demand if not available
                ContactImageOnDemandRectangularView(contactIdentifier: contactIdentifier, width: width, height: height)
            }
        }
        .id("\(contactIdentifier)_\(customImageFileName ?? "")")
    }
}

/// Manager class for handling contacts and favorites
class ContactsManager: ObservableObject {
    @Published var favorites: [FavoriteContact] = []
    @Published var allContacts: [CNContact] = []
    @Published var isLoading = false
    @Published var isLoadingContactsInBackground = false
    
    private let store = CNContactStore()
    
    /// Requests access to contacts and loads them
    func requestAccess() {
        store.requestAccess(for: .contacts) { [weak self] granted, error in
            DispatchQueue.main.async {
                if granted {
                    self?.loadContacts()
                    
                    // Check if we need to migrate old favorites format
                    if let data = UserDefaults.standard.data(forKey: "favorites") {
                        if data.count > 4 * 1024 * 1024 {
                            print("🚨 Migrating large favorites data now that contact access is granted...")
                            self?.migrateOldFavorites(from: data)
                        } else if (try? JSONDecoder().decode([FavoriteContact].self, from: data)) == nil {
                            print("🔄 Migrating old favorites format now that contact access is granted...")
                            self?.migrateOldFavorites(from: data)
                        }
                    }
                } else {
                    print("Contacts access denied: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }
    
    /// Loads all contacts from the device
    private func loadContacts() {
        isLoadingContactsInBackground = true
        
        let request = CNContactFetchRequest(keysToFetch: [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactImageDataKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor
        ])
        
        // Move contact enumeration to background thread to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async {
            var contacts: [CNContact] = []
            
            do {
                try self.store.enumerateContacts(with: request) { contact, _ in
                    contacts.append(contact)
                }
                
                // Sort contacts on background thread
                let sortedContacts = contacts.sorted { contact1, contact2 in
                    let name1 = "\(contact1.givenName) \(contact1.familyName)"
                    let name2 = "\(contact2.givenName) \(contact2.familyName)"
                    return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
                }
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    self.allContacts = sortedContacts
                    self.isLoadingContactsInBackground = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoadingContactsInBackground = false
                    print("Error loading contacts: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Loads favorites from UserDefaults (can be called without contact access)
    func loadFavorites() {
        if let data = UserDefaults.standard.data(forKey: "favorites") {
            print("🔍 Loading favorites data: \(data.count) bytes")
            if data.count > 4 * 1024 * 1024 {
                print("🚨 CRITICAL: Existing favorites data exceeds 4MB limit! Forcing migration...")
                // Force migration by calling migrateOldFavorites (requires contact access)
                // This will be called later when contact access is granted
                return
            }
            // Try to decode with new format first
            if let favorites = try? JSONDecoder().decode([FavoriteContact].self, from: data) {
                // Load favorites immediately without requiring contact access
                self.favorites = favorites
                print("✅ Loaded \(favorites.count) favorites from storage")
            } else {
                // Try to migrate from old format (requires contact access)
                // This will be called later when contact access is granted
                print("⚠️ Old format detected, will migrate when contact access is granted")
            }
        }
    }
    
    /// Migrates favorites from old format (with customImageData) to new format (with customImageFileName)
    private func migrateOldFavorites(from data: Data) {
        print("🔄 Starting migration from old format...")
        
        // Try to decode as raw JSON to access old customImageData
        if let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            var migratedFavorites: [FavoriteContact] = []
            
            for item in json {
                guard let contactIdentifier = item["contactIdentifier"] as? String,
                      let phoneNumber = item["phoneNumber"] as? String,
                      let displayName = item["displayName"] as? String else {
                    continue
                }
                
                    // Fetch the contact WITHOUT large image data to avoid memory issues
                    do {
                        let fetchedContact = try store.unifiedContact(withIdentifier: contactIdentifier, keysToFetch: [
                            CNContactGivenNameKey as CNKeyDescriptor,
                            CNContactFamilyNameKey as CNKeyDescriptor,
                            CNContactPhoneNumbersKey as CNKeyDescriptor
                            // Note: NOT fetching image data to avoid large data in memory during migration
                            // Images will be loaded on-demand when needed
                        ])
                        
                        // Create favorite with basic contact info (no CNContact stored)
                        // This ensures no large image data is in memory that gets encoded
                    
                    // Handle old customImageData if it exists
                    var customImageData: Data? = nil
                    if let imageData = item["customImageData"] as? Data {
                        print("🔄 Found old image data for \(displayName), size: \(imageData.count) bytes")
                        customImageData = imageData
                    }
                    
                    // Create new favorite with migration
                    let favorite = FavoriteContact(
                        contact: fetchedContact,
                        phoneNumber: phoneNumber,
                        displayName: displayName,
                        communicationMethod: CommunicationMethod(rawValue: item["communicationMethod"] as? String ?? "Voice Call") ?? .voiceCall,
                        communicationApp: CommunicationApp(rawValue: item["communicationApp"] as? String ?? "Phone") ?? .phoneMessage,
                        customImageData: customImageData
                    )
                    
                    migratedFavorites.append(favorite)
                    print("✅ Migrated favorite: \(displayName)")
                } catch {
                    print("❌ Failed to fetch contact during migration: \(error)")
                }
            }
            
            print("🔄 Migration completed. Migrated \(migratedFavorites.count) favorites")
            self.favorites = migratedFavorites
            
            // Save the migrated data - this will use the new file-based system
            print("💾 Saving migrated data...")
            saveFavorites()
            print("✅ Migration and save completed successfully")
        } else {
            print("❌ Failed to parse old favorites data as JSON")
        }
    }
    
    /// Saves favorites to UserDefaults
    func saveFavorites() {
        print("💾 saveFavorites called with \(favorites.count) favorites")
        
        // Note: No longer debugging CNContact image data since we don't store CNContact objects
        
        // Check data size before encoding
        print("💾 About to encode \(favorites.count) favorites")
        
        if let data = try? JSONEncoder().encode(favorites) {
            print("💾 Encoded data size: \(data.count) bytes")
            if data.count > 4 * 1024 * 1024 {
                print("⚠️ WARNING: Data size (\(data.count) bytes) exceeds 4MB limit!")
            }
            
            UserDefaults.standard.set(data, forKey: "favorites")
            print("✅ Successfully saved to UserDefaults")
            
            // Clean up orphaned images
            let validFileNames = Set(favorites.compactMap { $0.customImageFileName })
            ImageStorageManager.shared.cleanupOrphanedImages(validFileNames: validFileNames)
            print("🧹 Cleaned up orphaned images")
        } else {
            print("❌ Failed to encode favorites data")
        }
    }
    
    /// Adds a contact to favorites with a specific phone number
    func addToFavorites(contact: CNContact, phoneNumber: String, emailAddress: String? = nil) {
        let favorite = FavoriteContact(
            contact: contact,
            phoneNumber: phoneNumber,
            displayName: "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces),
            emailAddress: emailAddress
        )
        
        // Always add the favorite (allow duplicates)
        favorites.append(favorite)
        saveFavorites()
    }
    
    /// Legacy method for backward compatibility
    func addToFavorites(contact: CNContact) {
        guard let phoneNumber = contact.phoneNumbers.first?.value.stringValue else { return }
        addToFavorites(contact: contact, phoneNumber: phoneNumber, emailAddress: nil)
    }
    
    /// Removes a contact from favorites
    func removeFavorite(contact: CNContact) {
        favorites.removeAll { $0.contactIdentifier == contact.identifier }
        saveFavorites()
    }
    
    /// Removes a specific contact with specific phone number from favorites
    func removeFavorite(contact: CNContact, phoneNumber: String) {
        favorites.removeAll { favorite in
            favorite.contactIdentifier == contact.identifier && favorite.phoneNumber == phoneNumber
        }
        saveFavorites()
    }
    
    /// Removes favorites at specified indices
    func removeFavorites(at offsets: IndexSet) {
        // Clean up image files before removing favorites
        for index in offsets {
            if let fileName = favorites[index].customImageFileName {
                ImageStorageManager.shared.deleteImage(named: fileName)
            }
        }
        favorites.remove(atOffsets: offsets)
        saveFavorites()
    }
    
    /// Moves favorites from source indices to destination index
    func moveFavorites(from source: IndexSet, to destination: Int) {
        favorites.move(fromOffsets: source, toOffset: destination)
        saveFavorites()
    }
}

/// Model for favorite contacts
struct FavoriteContact: Identifiable, Codable, Equatable {
    let id = UUID()
    let contactIdentifier: String
    let phoneNumber: String
    let displayName: String
    var communicationMethod: CommunicationMethod
    var communicationApp: CommunicationApp
    // Optional custom avatar image file name (stored in file system)
    var customImageFileName: String?
    // Optional email address for FaceTime calls
    var emailAddress: String?
    
    // Store basic contact info separately to avoid large CNContact in UserDefaults
    let contactGivenName: String
    let contactFamilyName: String
    
    enum CodingKeys: String, CodingKey {
        case contactIdentifier, phoneNumber, displayName, communicationMethod, communicationApp, customImageFileName, contactGivenName, contactFamilyName, emailAddress
        // Note: CNContact is NOT included in CodingKeys to avoid large data in UserDefaults
    }
    
    // Method to fetch contact on demand without loading image data
    func fetchContact() -> CNContact? {
        let store = CNContactStore()
        do {
            let contact = try store.unifiedContact(withIdentifier: contactIdentifier, keysToFetch: [
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor,
                CNContactEmailAddressesKey as CNKeyDescriptor,
                CNContactImageDataKey as CNKeyDescriptor,
                CNContactThumbnailImageDataKey as CNKeyDescriptor
                // Note: We fetch image data here since it's only for display, not storage
            ])
            return contact
        } catch {
            print("Failed to fetch contact: \(error)")
            return nil
        }
    }
    
    init(contact: CNContact, phoneNumber: String, displayName: String, communicationMethod: CommunicationMethod = .voiceCall, communicationApp: CommunicationApp? = nil, customImageData: Data? = nil, emailAddress: String? = nil) {
        self.contactIdentifier = contact.identifier
        self.phoneNumber = phoneNumber
        self.displayName = displayName
        self.communicationMethod = communicationMethod
        self.contactGivenName = contact.givenName
        self.contactFamilyName = contact.familyName
        self.emailAddress = emailAddress
        
        // Save custom image to file system if provided
        if let imageData = customImageData {
            self.customImageFileName = ImageStorageManager.shared.saveImage(imageData, for: contact.identifier)
        } else {
            self.customImageFileName = nil
        }
        
        // Set appropriate default app based on communication method
        if let app = communicationApp {
            self.communicationApp = app
        } else {
            // Default to Phone iOS for all communication methods
            self.communicationApp = .phoneMessage
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        contactIdentifier = try container.decode(String.self, forKey: .contactIdentifier)
        phoneNumber = try container.decode(String.self, forKey: .phoneNumber)
        displayName = try container.decode(String.self, forKey: .displayName)
        communicationMethod = try container.decodeIfPresent(CommunicationMethod.self, forKey: .communicationMethod) ?? .voiceCall
        communicationApp = try container.decodeIfPresent(CommunicationApp.self, forKey: .communicationApp) ?? .phoneMessage
        customImageFileName = try container.decodeIfPresent(String.self, forKey: .customImageFileName)
        contactGivenName = try container.decodeIfPresent(String.self, forKey: .contactGivenName) ?? ""
        contactFamilyName = try container.decodeIfPresent(String.self, forKey: .contactFamilyName) ?? ""
        emailAddress = try container.decodeIfPresent(String.self, forKey: .emailAddress)
        
        // Handle migration from old customImageData format
        // Note: We can't access the old key since it's not in CodingKeys anymore
        // This migration will happen automatically when old data is loaded
        
        // These will be set by the decoder from the stored data
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(contactIdentifier, forKey: .contactIdentifier)
        try container.encode(phoneNumber, forKey: .phoneNumber)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(communicationMethod, forKey: .communicationMethod)
        try container.encode(communicationApp, forKey: .communicationApp)
        try container.encodeIfPresent(customImageFileName, forKey: .customImageFileName)
        try container.encode(contactGivenName, forKey: .contactGivenName)
        try container.encode(contactFamilyName, forKey: .contactFamilyName)
        try container.encodeIfPresent(emailAddress, forKey: .emailAddress)
    }
    
    // MARK: - Equatable
    static func == (lhs: FavoriteContact, rhs: FavoriteContact) -> Bool {
        return lhs.contactIdentifier == rhs.contactIdentifier &&
               lhs.phoneNumber == rhs.phoneNumber &&
               lhs.displayName == rhs.displayName &&
               lhs.communicationMethod == rhs.communicationMethod &&
               lhs.communicationApp == rhs.communicationApp
    }
}

// MARK: - App Detection Utility

class AppDetectionUtility {
    // Note: For app detection to work properly, you need to add LSApplicationQueriesSchemes to Info.plist
    // The schemes that need to be added are: whatsapp, tg, telegram, facetime, facetime-audio, sgnl, viber, tel, sms
    static func isAppInstalled(urlScheme: String) -> Bool {
        guard let url = URL(string: "\(urlScheme)://") else { 
            print("❌ Invalid URL scheme: \(urlScheme)")
            return false 
        }
        
        // Check if we're already on the main thread
        if Thread.isMainThread {
            let canOpen = UIApplication.shared.canOpenURL(url)
            print("🔍 Checking \(urlScheme):// - Result: \(canOpen)")
            return canOpen
        } else {
            // If not on main thread, dispatch to main thread synchronously
            var canOpen = false
            DispatchQueue.main.sync {
                canOpen = UIApplication.shared.canOpenURL(url)
                print("🔍 Checking \(urlScheme):// - Result: \(canOpen)")
            }
            return canOpen
        }
    }
    
    static func getInstalledCommunicationApps() -> [CommunicationApp] {
        print("🚀 Starting app detection...")
        var installedApps: [CommunicationApp] = []
        
        // Always include Phone iOS as it's built into iOS
        installedApps.append(.phoneMessage)
        print("✅ Added built-in app: Phone iOS")
        
        // Check for other installed apps
        let otherApps: [CommunicationApp] = [.whatsapp, .telegram, .facetime, .signal, .viber]
        
        for app in otherApps {
            print("🔍 Checking \(app.rawValue)...")
            
            // Try the main URL scheme
            let isInstalled = isAppInstalled(urlScheme: app.urlScheme)
            
            if isInstalled {
                installedApps.append(app)
                print("✅ \(app.rawValue) is installed!")
            } else {
                print("❌ \(app.rawValue) is not installed")
            }
        }
        
        let result = installedApps.sorted { $0.rawValue < $1.rawValue }
        print("🎯 Final result: \(result.map { $0.rawValue })")
        return result
    }
    
    static func debugAllSchemes() -> [String: Bool] {
        var results: [String: Bool] = [:]
        
        let allSchemes = [
            "whatsapp", "tg", "telegram", "facetime", "facetime-audio", 
            "sgnl", "viber", "tel", "sms"
        ]
        
        for scheme in allSchemes {
            results[scheme] = isAppInstalled(urlScheme: scheme)
        }
        
        return results
    }
}

// MARK: - Communication Configuration View

struct CommunicationConfigView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var favorite: FavoriteContact
    @ObservedObject var contactsManager: ContactsManager
    @State private var selectedMethod: CommunicationMethod
    @State private var selectedApp: CommunicationApp
    @State private var availableApps: [CommunicationApp] = []
    
    init(favorite: Binding<FavoriteContact>, contactsManager: ContactsManager) {
        self._favorite = favorite
        self.contactsManager = contactsManager
        self._selectedMethod = State(initialValue: favorite.wrappedValue.communicationMethod)
        self._selectedApp = State(initialValue: favorite.wrappedValue.communicationApp)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Call Type") {
                    Picker("Call Type", selection: $selectedMethod) {
                        ForEach(CommunicationMethod.allCases, id: \.self) { method in
                            HStack {
                                Image(systemName: method.icon)
                                    .foregroundColor(.blue)
                                Text(method.rawValue)
                            }
                            .tag(method)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Using App") {
                    if availableApps.isEmpty {
                        Text("No compatible apps found")
                            .foregroundColor(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Choose your preferred app:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Picker("Using App", selection: $selectedApp) {
                                ForEach(availableApps, id: \.self) { app in
                                    HStack {
                                        Image(systemName: app.icon)
                                            .foregroundColor(.green.opacity(0.7))
                                            .frame(width: 20)
                                        Text(app.rawValue)
                                        Spacer()
                                    }
                                    .tag(app)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        // Show available apps count
                        Text("\(availableApps.count) app\(availableApps.count == 1 ? "" : "s") available")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
                
                
                Section {
                VStack(alignment: .leading, spacing: 8) {
                        Text("Preview:")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            // Phone number display
                            HStack {
                                Image(systemName: "phone.fill")
                                    .foregroundColor(.secondary)
                                    .font(.subheadline)
                                Text("Phone Number:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(favorite.phoneNumber)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Communication method and app
                            HStack {
                                Image(systemName: selectedMethod.icon)
                                    .foregroundColor(.blue)
                                Text(selectedMethod.rawValue)
                                Spacer()
                                Image(systemName: selectedApp.icon)
                                    .foregroundColor(.green.opacity(0.7))
                                Text(selectedApp.rawValue)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                Section("Photo") {
                    if #available(iOS 16.0, *) {
                        PhotoPickerSection(favorite: $favorite)
                    } else {
                        Text("Photo editing requires iOS 16+")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                }
            }
            .navigationTitle("Configure Communication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        favorite.communicationMethod = selectedMethod
                        favorite.communicationApp = selectedApp
                        contactsManager.saveFavorites()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            loadAvailableApps()
        }
    }
    
    private func loadAvailableApps() {
        availableApps = AppDetectionUtility.getInstalledCommunicationApps()
        
        // Ensure selected app is available, otherwise select first available
        if !availableApps.contains(selectedApp) {
            selectedApp = availableApps.first ?? .phoneMessage
        }
    }
}

// MARK: - Photo Picker Section
@available(iOS 16.0, *)
struct PhotoPickerSection: View {
    @Binding var favorite: FavoriteContact
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var showingCamera = false
    
    init(favorite: Binding<FavoriteContact>) {
        self._favorite = favorite
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                ContactPhotoView(contactIdentifier: favorite.contactIdentifier, contactGivenName: favorite.contactGivenName, contactFamilyName: favorite.contactFamilyName, customImageFileName: $favorite.customImageFileName, size: 60)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        // Gallery picker button
                        PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                            HStack {
                                Image(systemName: "photo")
                                    .foregroundColor(.blue)
                                Text("Gallery")
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Camera button
                        Button {
                            showingCamera = true
                        } label: {
                            HStack {
                                Image(systemName: "camera")
                                    .foregroundColor(.green.opacity(0.7))
                                Text("Camera")
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.green.opacity(0.05))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    if favorite.customImageFileName != nil {
                        Button(role: .destructive) {
                            if let fileName = favorite.customImageFileName {
                                ImageStorageManager.shared.deleteImage(named: fileName)
                            }
                            favorite.customImageFileName = nil
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Remove Custom Photo")
                            }
                        }
                        .font(.caption)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraPicker(favorite: $favorite)
        }
        .onChange(of: selectedItem) { _, newItem in
            guard let item = newItem else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    let resized = resizeImage(uiImage, maxDimension: 512)
                    if let jpeg = resized.jpegData(compressionQuality: 0.85) {
                        DispatchQueue.main.async {
                            // Delete old image if exists
                            if let oldFileName = favorite.customImageFileName {
                                ImageStorageManager.shared.deleteImage(named: oldFileName)
                            }
                            // Save new image and get file name
                            favorite.customImageFileName = ImageStorageManager.shared.saveImage(jpeg, for: favorite.contactIdentifier)
                            selectedItem = nil
                        }
                    }
                }
            }
        }
    }
    
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let width = image.size.width
        let height = image.size.height
        let scale = min(1, maxDimension / max(width, height))
        let newSize = CGSize(width: width * scale, height: height * scale)
        if scale >= 1 { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - Camera Picker
struct CameraPicker: UIViewControllerRepresentable {
    @Binding var favorite: FavoriteContact
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        
        init(_ parent: CameraPicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                let resized = resizeImage(editedImage, maxDimension: 512)
                if let jpeg = resized.jpegData(compressionQuality: 0.85) {
                    // Delete old image if exists
                    if let oldFileName = parent.favorite.customImageFileName {
                        ImageStorageManager.shared.deleteImage(named: oldFileName)
                    }
                    // Save new image and get file name
                    parent.favorite.customImageFileName = ImageStorageManager.shared.saveImage(jpeg, for: parent.favorite.contactIdentifier)
                }
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
        
        private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
            let width = image.size.width
            let height = image.size.height
            let scale = min(1, maxDimension / max(width, height))
            let newSize = CGSize(width: width * scale, height: height * scale)
            if scale >= 1 { return image }
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 1
            let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
            return renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        }
    }
}

/// Detailed view for a single contact with swipe navigation
struct ContactDetailView: View {
    @Binding var favorite: FavoriteContact
    @ObservedObject var contactsManager: ContactsManager
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int = 0
    @State private var showingInfoMenu = false
    @State private var showingHelp = false
    @State private var showingAbout = false
    @State private var showingSuggestions = false
    let onIndexChanged: (Int) -> Void
    
    init(favorite: Binding<FavoriteContact>, contactsManager: ContactsManager, initialIndex: Int = 0, onIndexChanged: @escaping (Int) -> Void = { _ in }) {
        self._favorite = favorite
        self.contactsManager = contactsManager
        self.onIndexChanged = onIndexChanged
        // Use the provided initial index instead of finding it
        self._currentIndex = State(initialValue: initialIndex)
        print("🔍 ContactDetailView init: Starting at provided index \(initialIndex) of \(contactsManager.favorites.count)")
    }
    
    var body: some View {
        NavigationStack {
            TabView(selection: $currentIndex) {
                ForEach(Array(contactsManager.favorites.enumerated()), id: \.element.id) { index, fav in
                    ContactDetailPage(
                        favorite: Binding(
                            get: { fav },
                            set: { _ in }
                        ),
                        contactsManager: contactsManager,
                        onHomeTapped: {
                            dismiss()
                        }
                    )
                    .tag(index)
                    .onAppear {
                        print("🔍 ContactDetailPage \(index) appeared for \(fav.displayName)")
                    }
                }
            }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .onChange(of: currentIndex) { _, newIndex in
            onIndexChanged(newIndex)
        }
        // DEBUG: Large obvious navigation buttons
        .overlay(alignment: .bottom) {
            VStack {
                Spacer()
                
                HStack {
                    // Left navigation button (previous) - DEBUG VERSION
                                    Button(action: {
                                        print("🔍 LEFT BUTTON TAPPED!")
                                        if currentIndex > 0 {
                                            currentIndex -= 1
                                        } else {
                                            currentIndex = contactsManager.favorites.count - 1
                                        }
                                    }) {
                                        Image(systemName: "chevron.left")
                                            .font(.title2)
                                            .foregroundColor(.gray)
                                            .frame(width: 80, height: 160)
                                            .background(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                            )
                                    }
                    .accessibilityLabel("Previous contact")
                    
                    Spacer()
                    
                    // Right navigation button (next) - DEBUG VERSION
                                    Button(action: {
                                        print("🔍 RIGHT BUTTON TAPPED!")
                                        if currentIndex < contactsManager.favorites.count - 1 {
                                            currentIndex += 1
                                        } else {
                                            currentIndex = 0
                                        }
                                    }) {
                                        Image(systemName: "chevron.right")
                                            .font(.title2)
                                            .foregroundColor(.gray)
                                            .frame(width: 80, height: 160)
                                            .background(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                            )
                                    }
                    .accessibilityLabel("Next contact")
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 50)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Text("Home")
                        .font(.headline)
                        .foregroundColor(.blue)
                }
            }
            
            ToolbarItem(placement: .principal) {
                Text("\(currentIndex + 1) of \(contactsManager.favorites.count)")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingInfoMenu = true
                }) {
                    Image(systemName: "info.circle")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
        }
        .sheet(isPresented: $showingInfoMenu) {
            InfoMenuView(
                showingHelp: $showingHelp,
                showingAbout: $showingAbout,
                showingSuggestions: $showingSuggestions
            )
        }
        .sheet(isPresented: $showingHelp) {
            HelpView()
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
        .sheet(isPresented: $showingSuggestions) {
            SuggestionView()
        }
        }
    }
}

/// Individual contact detail page
struct ContactDetailPage: View {
    @Binding var favorite: FavoriteContact
    @ObservedObject var contactsManager: ContactsManager
    let onHomeTapped: () -> Void
    
    init(favorite: Binding<FavoriteContact>, contactsManager: ContactsManager, onHomeTapped: @escaping () -> Void) {
        self._favorite = favorite
        self.contactsManager = contactsManager
        self.onHomeTapped = onHomeTapped
   //     print("🔍 ContactDetailPage init for: \(favorite.wrappedValue.displayName)")
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 20) {
                // Contact Photo - Much larger, almost full screen, tappable for dialing
                            Button(action: {
                                print("🔍 PICTURE TAPPED - Initiating dial!")
                                initiateCommunication()
                            }) {
                                ContactPhotoViewRectangular(contactIdentifier: favorite.contactIdentifier, contactGivenName: favorite.contactGivenName, contactFamilyName: favorite.contactFamilyName, customImageFileName: $favorite.customImageFileName, width: geometry.size.width, height: geometry.size.height * 0.6)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(PlainButtonStyle()) // Remove default button styling
                            .padding(.top, 10)
                
                // Contact Name - Moved down more
                Text(favorite.displayName)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.top, 20)
                
                // Phone Number - Simple display without navigation buttons
                Text(favorite.phoneNumber)
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.top, 10)
                
                // Email Address - Show if available
                if let email = favorite.emailAddress, !email.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "envelope.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text(email)
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                }
                
                // Settings Button - Below phone number showing dial method
                Button(action: {
                    print("🔍 CALL METHOD TAPPED - Initiating dial!")
                    initiateCommunication()
                }) {
                    HStack(spacing: 8) {
                        VStack(spacing: 2) {
                            Image(systemName: favorite.communicationMethod.iconName)
                                .font(.title3)
                                .foregroundColor(.blue)
                            Text(favorite.communicationMethod.displayName)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 2) {
                            Image(systemName: favorite.communicationApp.iconName)
                                .font(.title3)
                                .foregroundColor(.green.opacity(0.7))
                            Text(favorite.communicationApp.displayName)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .padding(.horizontal)
                
                
                Spacer()
                
            }
        }
    }
    
    /// Initiates communication with the current favorite's settings
    private func initiateCommunication() {
        // For FaceTime, use email address if available, otherwise clean the phone number
        let phoneNumber: String
        var isEmail = false
        
        if let email = favorite.emailAddress, !email.isEmpty, (favorite.communicationApp == .facetime || favorite.communicationApp == .phoneMessage) {
            // Use email address as-is for FaceTime
            phoneNumber = email
            isEmail = true
        } else {
            // Clean the phone number - keep only digits and +, then remove +
            let cleanPhoneNumber = favorite.phoneNumber.filter { $0.isNumber || $0 == "+" }
            phoneNumber = cleanPhoneNumber.replacingOccurrences(of: "+", with: "")
            isEmail = false
        }
        
        // Validate: Email addresses cannot be used with certain apps
        if isEmail && (favorite.communicationApp == .phoneMessage || favorite.communicationApp == .whatsapp || favorite.communicationApp == .telegram || favorite.communicationApp == .signal || favorite.communicationApp == .viber) {
            // Show alert to user
            DispatchQueue.main.async {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let viewController = windowScene.windows.first?.rootViewController {
                    let alert = UIAlertController(
                        title: "Cannot Make Call",
                        message: "Email addresses cannot be used with \(favorite.communicationApp.displayName). Please use FaceTime for email-based calls, or add a phone number for this contact.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    viewController.present(alert, animated: true)
                }
            }
            print("⚠️ Cannot use email address with \(favorite.communicationApp.displayName)")
            return // Exit without processing
        }
        
        var urlString: String
        
        switch (favorite.communicationMethod, favorite.communicationApp) {
        case (.voiceCall, .phoneMessage):
            urlString = "tel:\(favorite.phoneNumber)"
        case (.videoCall, .phoneMessage):
            urlString = "facetime:\(phoneNumber)"
        case (.textMessage, .phoneMessage):
            urlString = "sms:\(phoneNumber)"
        case (.voiceCall, .whatsapp):
            urlString = "whatsapp://calluser/?phone=\(phoneNumber)"
        case (.videoCall, .whatsapp):
            urlString = "whatsapp://calluser/?phone=\(phoneNumber)"
        case (.textMessage, .whatsapp):
            urlString = "whatsapp://send?phone=\(phoneNumber)"
        case (.voiceCall, .telegram):
            urlString = "tg://resolve?domain=\(phoneNumber)"
        case (.videoCall, .telegram):
            urlString = "tg://resolve?domain=\(phoneNumber)"
        case (.textMessage, .telegram):
            urlString = "tg://resolve?domain=\(phoneNumber)"
        case (.voiceCall, .facetime):
            urlString = "facetime-audio:\(phoneNumber)"
        case (.videoCall, .facetime):
            urlString = "facetime:\(phoneNumber)"
        case (.textMessage, .facetime):
            urlString = "sms:\(phoneNumber)"
        case (.voiceCall, .signal):
            urlString = "sgnl://send?phone=\(phoneNumber)"
        case (.videoCall, .signal):
            urlString = "sgnl://send?phone=\(phoneNumber)"
        case (.textMessage, .signal):
            urlString = "sgnl://send?phone=\(phoneNumber)"
        case (.voiceCall, .viber):
            urlString = "viber://chat?number=\(phoneNumber)"
        case (.videoCall, .viber):
            urlString = "viber://chat?number=\(phoneNumber)"
        case (.textMessage, .viber):
            urlString = "viber://chat?number=\(phoneNumber)"
        }
        
        if let url = URL(string: urlString) {
            print("🔍 ContactDetailPage Communication Debug: 🔍 Method: \(favorite.communicationMethod.rawValue) 🔍 App: \(favorite.communicationApp.rawValue) 🔍 Original Phone: \(favorite.phoneNumber) 🔍 Cleaned Phone: \(phoneNumber) 🔍 Final URL: \(urlString) 🔍 About to open URL: \(urlString)")
            DispatchQueue.main.async {
                let options: [UIApplication.OpenExternalURLOptionsKey: Any] = [
                    .universalLinksOnly: false  // Allow custom URL schemes
                ]
                UIApplication.shared.open(url, options: options) { success in
                    print("🔍 ContactDetailPage URL opened successfully: \(success)")
                    if !success {
                        print("🔍 ContactDetailPage Failed to open URL: \(urlString)")
                    }
                }
            }
        }
    }
    
    /// Initiates communication with a specific method
    private func initiateCommunicationWithMethod(_ method: CommunicationMethod) {
        let cleanPhoneNumber = favorite.phoneNumber.filter { $0.isNumber || $0 == "+" }
        let phoneNumber = cleanPhoneNumber.replacingOccurrences(of: "+", with: "")
        
        var urlString: String
        
        switch method {
        case .voiceCall:
            urlString = "tel:\(favorite.phoneNumber)"
        case .videoCall:
            urlString = "facetime:\(phoneNumber)"
        case .textMessage:
            urlString = "sms:\(phoneNumber)"
        }
        
        if let url = URL(string: urlString) {
            DispatchQueue.main.async {
                let options: [UIApplication.OpenExternalURLOptionsKey: Any] = [
                    .universalLinksOnly: false
                ]
                UIApplication.shared.open(url, options: options) { success in
                    print("🔍 Method communication URL opened successfully: \(success)")
                }
            }
        }
    }
}

/// Help view with useful tips for the app
struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("My Dial Help")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        HelpSection(
                            title: "Getting Started",
                            content: "• Add contacts to favorites from your phone's contact list\n• Tap 'Add & Edit' to manage your favorites\n• Use the 'My Dial' button to enter the quick dial mode"
                        )
                        
                        HelpSection(
                            title: "My Dial Mode",
                            content: "• Swipe left/right to navigate between contacts\n• Tap the contact photo to make a call\n• Tap the call button for voice calls\n• Use the Home button to return to favorites"
                        )
                        
                        HelpSection(
                            title: "Customizing Contacts",
                            content: "• Tap the gear icon in edit mode to configure each contact\n• Choose your preferred communication method (Voice/Video/Text)\n• Select which app to use (Phone, WhatsApp, FaceTime, etc.)\n• Add custom photos for contacts\n• The same contact can be added multiple times to My Dial\n• To add the same contact with the same number multiple times, add it once, save, then add it again\n• Multiple phone numbers and email addresses for the same contact can be added at once\n• Each entry on My Dial can have a different picture, even for the same contact\n• Different pictures can represent different ways you plan to communicate with the same person"
                        )
                        
                        HelpSection(
                            title: "Navigation Tips",
                            content: "• Swipe gestures work on the entire screen\n• Large invisible tap areas on left/right for easy navigation\n• Double-tap gestures are not required\n• The app remembers your last viewed contact"
                        )
                        
                        HelpSection(
                            title: "Calling with Phone iOS (Built-in iPhone Apps)",
                            content: "• Message, voice, and video calls are supported\n• Video calls are made via FaceTime if available on the contact's device"
                        )
                        
                        HelpSection(
                            title: "Calling with FaceTime",
                            content: "• Message, voice, and video calls are supported\n• Messages use the native 'Messages' app\n• FaceTime voice and video calls can be made using either a phone number or email address\n• When adding a contact, you can select an email address for FaceTime calls if the contact has FaceTime enabled on their email"
                        )
                        
                        HelpSection(
                            title: "Calling with WhatsApp",
                            content: "• When making a WhatsApp video call, a WhatsApp voice call will be initiated\n• Once connected, tap the camera icon within WhatsApp to switch to video mode"
                        )
                        
                        HelpSection(
                            title: "Other Supported Apps",
                            content: "• Telegram, Signal, and Viber are supported\n• All call methods to these apps open the app in message mode"
                        )
                        
                        HelpSection(
                            title: "Always in Focus",
                            content: "• When using this app for elders or differently-abled people, there are two ways to ensure the app is always available and in focus"
                        )
                        
                        HelpSection(
                            title: "Option 1: Enable Notification Reminders",
                            content: "• Enable the 'Always Bring to Focus' setting in the info menu (tap the 'i' icon)\n• When the app is out of focus or closed, you will receive a notification reminder saying 'Return to My Dial'\n• Tap the notification to return to the app"
                        )
                        
                        HelpSection(
                            title: "Option 2: Use NFC Tag (requires NFC tag purchase)",
                            content: "• Step 1: Create a shortcut in the 'Shortcuts' app\n• Tap '+ New Shortcut'\n• Choose 'Open App'\n• Select 'My Dial' app\n\n• Step 2: Create an NFC automation\n• In the 'Shortcuts' app, choose 'Automation'\n• Tap 'New Automation' → 'NFC'\n• Enable 'Run Immediately'\n• Tap 'Scan', then place the NFC tag near the top of your phone\n• When you get a success message, name the tag (e.g., 'Easy Dial')\n• Tap 'Next'\n• Select the 'Open App' shortcut created in Step 1\n\n• Once set up, whenever the user touches the NFC tag with the top of their phone, the My Dial app will open to the last page/contact they were viewing"
                        )
                    }
                    .padding()
                }
            }
            .navigationTitle("Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// Help section component
struct HelpSection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.blue)
            
            Text(content)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

/// About view with app information
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()
                
                Image(systemName: "phone.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                VStack(spacing: 10) {
                    Text("My Dial")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Quick Access to Your Favorite Contacts")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 15) {
                    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                    let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
                    Text("Version \(appVersion) (Build \(buildNumber))")
                        .font(.title3)
                        .fontWeight(.medium)
                    
                    Text("Made with ❤️ for easy communication")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(spacing: 10) {
                    Text("Features:")
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("• Quick dial interface")
                        Text("• Swipe navigation")
                        Text("• Multiple communication apps")
                        Text("• Custom contact photos")
                        Text("• Favorite management")
                    }
                    .font(.body)
                    .foregroundColor(.primary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
                Spacer()
            }
            .padding()
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}


/// Suggestion view for user feedback
struct SuggestionView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                VStack(spacing: 16) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("We'd love to hear your comments!")
                        .font(.title2)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                    
                    Text("Message us with a personal review and any other suggestions you have.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                
                VStack(spacing: 16) {
                    Text("Send us an email with your comments:")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    
                    Button(action: openEmailApp) {
                        HStack {
                            Image(systemName: "envelope.circle.fill")
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("apps@tvrgod.com")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Tap to open email app")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundColor(.blue)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal)
                }
                
                Spacer()
                
                Text("Device information will be automatically included in your email.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top)
            .navigationTitle("Comment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func openEmailApp() {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let deviceModel = UIDevice.current.model
        let systemVersion = UIDevice.current.systemVersion
        let deviceName = UIDevice.current.name
        
        let subject = "My Dial App Comment & Review"
        let body = """
        Please share your personal review and any comments here:
        
        
        
        ---
        Device Information:
        • App Version: \(appVersion) (Build \(buildNumber))
        • Device: \(deviceName) (\(deviceModel))
        • iOS Version: \(systemVersion)
        
        Sent from My Dial iOS App
        """
        
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        if let url = URL(string: "mailto:apps@tvrgod.com?subject=\(encodedSubject)&body=\(encodedBody)") {
            UIApplication.shared.open(url)
        }
    }
}

/// Reusable menu row component that makes the entire row tappable
struct MenuRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .frame(width: 24, height: 24)
                
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle()) // Makes entire area tappable
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Info menu view that replaces ActionSheet
struct InfoMenuView: View {
    @Binding var showingHelp: Bool
    @Binding var showingAbout: Bool
    @Binding var showingSuggestions: Bool
    @State private var showingDonationPopup = false
    @AppStorage("alwaysBringToFocus") private var alwaysBringToFocus = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                MenuRow(
                    icon: "questionmark.circle",
                    iconColor: .blue,
                    title: "Help"
                ) {
                    dismiss()
                    showingHelp = true
                }
                
                MenuRow(
                    icon: "heart.fill",
                    iconColor: .red,
                    title: "Donate"
                ) {
                    showingDonationPopup = true
                }
                
                MenuRow(
                    icon: "person.circle",
                    iconColor: .blue,
                    title: "About"
                ) {
                    dismiss()
                    showingAbout = true
                }
                
                MenuRow(
                    icon: "lightbulb",
                    iconColor: .yellow,
                    title: "Comment"
                ) {
                    dismiss()
                    showingSuggestions = true
                }
                
                // Settings Section
                Section(header: Text("Settings")) {
                    Toggle(isOn: $alwaysBringToFocus) {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.up.forward.app")
                                .foregroundColor(.green)
                                .font(.system(size: 20))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Always Bring to Focus")
                                    .font(.body)
                                Text("Return to My Dial after calls")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                }
            }
            .navigationTitle("My Dial")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingDonationPopup) {
            DonationPopupView()
        }
    }
}

/// Donation popup view with amount selection
struct DonationPopupView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var purchaseManager = InAppPurchaseManager.shared
    @State private var selectedAmount: Double = 4.99
    @State private var showingPurchaseAlert = false
    @State private var purchaseSuccessMessage = ""
    @State private var hasInitiatedPurchase = false
    
    // Available donation amounts in USD
    private let donationAmounts: [Double] = [4.99]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 10) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                    
                    Text("Support My Dial")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Thank You for your donation")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Amount display (fixed at $4.99)
                VStack(alignment: .leading, spacing: 15) {
                    Text("Donation Amount")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text(formatAmount(selectedAmount))
                            .foregroundColor(.primary)
                            .font(.title2)
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .font(.title3)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 15) {
                    // Donate button
                    Button(action: {
                        hasInitiatedPurchase = true
                        Task {
                            await purchaseManager.purchaseDonation(amount: selectedAmount)
                        }
                    }) {
                        HStack {
                            if purchaseManager.isPurchasing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "heart.fill")
                            }
                            Text(purchaseManager.isPurchasing ? "Processing..." : "Donate \(formatAmount(selectedAmount))")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(purchaseManager.isPurchasing ? Color.red.opacity(0.7) : Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .font(.headline)
                    }
                    .disabled(purchaseManager.isPurchasing)
                    
                    // Cancel button
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(10)
                            .font(.headline)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Donation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Purchase Error", isPresented: .constant(purchaseManager.purchaseError != nil)) {
            Button("OK") {
                purchaseManager.purchaseError = nil
                hasInitiatedPurchase = false // Reset the flag on error
            }
        } message: {
            Text(purchaseManager.purchaseError ?? "")
        }
        .alert("Thank You!", isPresented: $showingPurchaseAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text(purchaseSuccessMessage)
        }
        .onReceive(purchaseManager.$purchaseSucceeded) { succeeded in
            // Only show success if the purchase actually succeeded
            if succeeded && hasInitiatedPurchase {
                // Purchase completed successfully
                purchaseSuccessMessage = "Thank you for your generous donation of \(formatAmount(selectedAmount))! Your support helps us improve My Dial."
                showingPurchaseAlert = true
                hasInitiatedPurchase = false // Reset the flag
                // Reset the success flag for next time
                purchaseManager.purchaseSucceeded = false
            }
        }
        .onReceive(purchaseManager.$isPurchasing) { isPurchasing in
            // Reset the initiated flag if user cancels (isPurchasing becomes false without success)
            if !isPurchasing && !purchaseManager.purchaseSucceeded && purchaseManager.purchaseError == nil && hasInitiatedPurchase {
                // User likely cancelled
                hasInitiatedPurchase = false
            }
        }
    }
    
    private func formatAmount(_ amount: Double) -> String {
        if amount == 20.00 {
            return "$20.00"
        } else {
            return String(format: "$%.2f", amount)
        }
    }
}

/// Direct contact detail view that works with favorites array instead of single favorite binding
struct ContactDetailViewDirect: View {
    let favorites: [FavoriteContact]
    @ObservedObject var contactsManager: ContactsManager
    @State private var currentIndex: Int = 0
    @State private var showingInfoMenu = false
    @State private var showingHelp = false
    @State private var showingAbout = false
    @State private var showingSuggestions = false
    let onIndexChanged: (Int) -> Void
    let onReturnToFavorites: () -> Void
    
    init(favorites: [FavoriteContact], contactsManager: ContactsManager, initialIndex: Int = 0, onIndexChanged: @escaping (Int) -> Void = { _ in }, onReturnToFavorites: @escaping () -> Void) {
        self.favorites = favorites
        self.contactsManager = contactsManager
        self.onIndexChanged = onIndexChanged
        self.onReturnToFavorites = onReturnToFavorites
        self._currentIndex = State(initialValue: initialIndex)
        print("🔍 ContactDetailViewDirect init: Starting at provided index \(initialIndex) of \(favorites.count)")
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Navigation bar with Home button
                HStack {
                    Button(action: onReturnToFavorites) {
                        HStack {
                            Image(systemName: "house.fill")
                            Text("Home")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    Button(action: { 
                        print("🔍 INFO BUTTON TAPPED!")
                        print("🔍 Before: showingInfoMenu = \(showingInfoMenu)")
                        showingInfoMenu = true 
                        print("🔍 After: showingInfoMenu = \(showingInfoMenu)")
                    }) {
                        Image(systemName: "info.circle")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .zIndex(1) // Ensure navigation bar is on top
                
                // TabView for swiping between contacts (same as original ContactDetailView)
                TabView(selection: $currentIndex) {
                    ForEach(Array(favorites.enumerated()), id: \.element.id) { index, fav in
                        ContactDetailPage(
                            favorite: Binding(
                                get: { fav },
                                set: { _ in }
                            ),
                            contactsManager: contactsManager,
                            onHomeTapped: onReturnToFavorites
                        )
                        .tag(index)
                        .onAppear {
                            print("🔍 ContactDetailPage \(index) appeared for \(fav.displayName)")
                        }
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .onChange(of: currentIndex) { _, newIndex in
                    onIndexChanged(newIndex)
                }
            }
            
            // DEBUG: Large obvious navigation buttons - positioned at bottom only
            VStack {
                Spacer()
                
                HStack {
                    // Left navigation button (previous) - DEBUG VERSION
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            if currentIndex > 0 {
                                currentIndex -= 1
                            } else {
                                currentIndex = favorites.count - 1
                            }
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(.gray)
                            .frame(width: 80, height: 160)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .accessibilityLabel("Previous contact")
                    
                    Spacer()
                    
                    // Right navigation button (next) - DEBUG VERSION
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            if currentIndex < favorites.count - 1 {
                                currentIndex += 1
                            } else {
                                currentIndex = 0
                            }
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.title2)
                            .foregroundColor(.gray)
                            .frame(width: 80, height: 160)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .accessibilityLabel("Next contact")
                }
                .frame(height: 200)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingInfoMenu) {
            InfoMenuView(
                showingHelp: $showingHelp,
                showingAbout: $showingAbout,
                showingSuggestions: $showingSuggestions
            )
        }
        .sheet(isPresented: $showingHelp) {
            HelpView()
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
        .sheet(isPresented: $showingSuggestions) {
            SuggestionView()
        }
    }
}

#Preview {
    ContentView()
}
