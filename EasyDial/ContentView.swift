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
    case phone = "Phone"
    case whatsapp = "WhatsApp"
    case telegram = "Telegram"
    case facetime = "FaceTime"
    case messages = "Messages"
    case signal = "Signal"
    case viber = "Viber"
    
    var icon: String {
        switch self {
        case .phone: return "phone.fill"
        case .whatsapp: return "message.fill"
        case .telegram: return "paperplane.fill"
        case .facetime: return "video.fill"
        case .messages: return "message.fill"
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
        case .phone: return "tel"
        case .whatsapp: return "whatsapp"
        case .telegram: return "tg"
        case .facetime: return "facetime"
        case .messages: return "sms"
        case .signal: return "sgnl"
        case .viber: return "viber"
        }
    }
    
    var bundleIdentifier: String {
        switch self {
        case .phone: return "com.apple.mobilephone"
        case .whatsapp: return "net.whatsapp.WhatsApp"
        case .telegram: return "ph.telegra.Telegraph"
        case .facetime: return "com.apple.facetime"
        case .messages: return "com.apple.MobileSMS"
        case .signal: return "org.whispersystems.signal"
        case .viber: return "com.viber"
        }
    }
}

/// Main view that displays favorites from the Contacts app
struct ContentView: View {
    @StateObject private var contactsManager = ContactsManager()
    @State private var showingAddToFavorites = false
    @State private var isEditMode = false
    @State private var currentContactIndex = 0
    @State private var showingContactDetail = false
    @State private var lastViewedContactIndex = 0
    private let lastViewedContactKey = "lastViewedContactIndex"
    
    var body: some View {
        NavigationStack {
            Group {
                if contactsManager.isLoading {
                    ProgressView("Loading contacts...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if contactsManager.favorites.isEmpty {
                    emptyStateView
                } else {
                    favoritesListView
                }
            }
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !contactsManager.favorites.isEmpty {
                        Button(isEditMode ? "Done" : "Edit") {
                            withAnimation {
                                isEditMode.toggle()
                            }
                        }
                        .accessibilityLabel(isEditMode ? "Exit edit mode" : "Enter edit mode")
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    if !contactsManager.favorites.isEmpty && !isEditMode {
                        Button("Easy Dial") {
                            // Use the current session's lastViewedContactIndex, not the saved one
                            print("🔍 Easy Dial button pressed, using lastViewedContactIndex: \(lastViewedContactIndex)")
                            showingContactDetail = true
                        }
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                        .disabled(contactsManager.favorites.isEmpty)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isEditMode {
                        Button {
                            showingAddToFavorites = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Add to favorites")
                    }
                }
            }
            .sheet(isPresented: $showingAddToFavorites) {
                AddToFavoritesView(contactsManager: contactsManager)
            }
            .fullScreenCover(isPresented: $showingContactDetail) {
                if lastViewedContactIndex < contactsManager.favorites.count {
                    let _ = print("🔍 Creating ContactDetailView with lastViewedContactIndex: \(lastViewedContactIndex)")
                    ContactDetailView(
                        favorite: Binding(
                            get: { contactsManager.favorites[lastViewedContactIndex] },
                            set: { _ in }
                        ),
                        contactsManager: contactsManager,
                        initialIndex: lastViewedContactIndex,
                        onIndexChanged: { newIndex in
                            lastViewedContactIndex = newIndex
                            // Save to UserDefaults whenever the index changes
                            UserDefaults.standard.set(newIndex, forKey: lastViewedContactKey)
                        }
                    )
                }
            }
        }
        .onAppear {
            contactsManager.requestAccess()
        }
        .onChange(of: contactsManager.favorites) { _ in
            // Load the last viewed contact index from UserDefaults when contacts are loaded
            let savedIndex = UserDefaults.standard.integer(forKey: lastViewedContactKey)
            print("🔍 Loading saved index: \(savedIndex), favorites count: \(contactsManager.favorites.count)")
            if savedIndex >= 0 && savedIndex < contactsManager.favorites.count {
                lastViewedContactIndex = savedIndex
                print("🔍 Set lastViewedContactIndex to: \(lastViewedContactIndex)")
            } else {
                print("🔍 Saved index \(savedIndex) is invalid, keeping default: \(lastViewedContactIndex)")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            // Save the last viewed contact index when app goes to background
            UserDefaults.standard.set(lastViewedContactIndex, forKey: lastViewedContactKey)
        }
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
    @State private var showingDetail = false
    
    init(favorite: Binding<FavoriteContact>, isEditMode: Bool, contactsManager: ContactsManager) {
        self._favorite = favorite
        self.isEditMode = isEditMode
        self.contactsManager = contactsManager
        print("🔍 FavoriteContactRow created for: \(favorite.wrappedValue.displayName), isEditMode: \(isEditMode)")
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Contact photo (uses custom image if set)
            ContactPhotoView(contact: favorite.contact, customImageData: $favorite.customImageData, size: 50)
            
            // Contact info
            VStack(alignment: .leading, spacing: 4) {
                Text(favorite.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(favorite.phoneNumber)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Show communication method and app
                HStack {
                    Image(systemName: favorite.communicationMethod.icon)
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text(favorite.communicationMethod.rawValue)
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Image(systemName: favorite.communicationApp.icon)
                        .foregroundColor(.green)
                        .font(.caption)
                    Text(favorite.communicationApp.rawValue)
                        .font(.caption)
                        .foregroundColor(.green)
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
                        .background(Color.green)
                        .clipShape(Circle())
                }
                .accessibilityLabel("\(favorite.communicationMethod.rawValue) \(favorite.displayName)")
            }
        }
        .padding(.vertical, 4)
        .onTapGesture {
            print("🔍 FavoriteContactRow tapped - isEditMode: \(isEditMode)")
            if isEditMode {
                print("🔍 Opening config sheet")
                showingConfig = true
            } else {
                print("🔍 Opening detail view")
                showingDetail = true
            }
        }
        .sheet(isPresented: $showingConfig) {
            CommunicationConfigView(favorite: $favorite)
        }
        .sheet(isPresented: $showingDetail) {
            ContactDetailView(favorite: $favorite, contactsManager: contactsManager)
        }
        .onChange(of: favorite.customImageData) { _, _ in
            // Save favorites when custom image data changes
            contactsManager.saveFavorites()
        }
    }
    
    /// Initiates communication based on the selected method and app
    private func initiateCommunication() {
        // Clean the phone number for tel: and facetime: schemes - keep only digits, +, and -
        let cleanPhoneNumber = favorite.phoneNumber.replacingOccurrences(of: " ", with: "")
                                                   .replacingOccurrences(of: "(", with: "")
                                                   .replacingOccurrences(of: ")", with: "")
                                                   .replacingOccurrences(of: "-", with: "")
                                                   .replacingOccurrences(of: ".", with: "")
        
        // Remove the '+' sign from the phone number for URL schemes
        let phoneNumber = cleanPhoneNumber.replacingOccurrences(of: "+", with: "")
        
        var urlString: String
        
        
        switch (favorite.communicationMethod, favorite.communicationApp) {
        case (.voiceCall, .phone):
            urlString = "tel:\(favorite.phoneNumber)" // Use original format to avoid prompts
        case (.videoCall, .phone):
            urlString = "facetime:\(phoneNumber)"
        case (.textMessage, .messages):
            urlString = "sms:\(phoneNumber)"
        case (.voiceCall, .whatsapp):
            urlString = "whatsapp://calluser/?phone=\(phoneNumber)"
        case (.videoCall, .whatsapp):
            urlString = "whatsapp://send?phone=\(phoneNumber)"
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
        case (.textMessage, .phone):
            // Handle legacy contacts that have Text Message + Phone (invalid combination)
            urlString = "sms:\(phoneNumber)"
        default:
            // Fallback to phone call
            urlString = "tel:\(phoneNumber)"
        }
        
        if let url = URL(string: urlString) {
            DispatchQueue.main.async {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }
    
    /// Legacy method for backward compatibility
    private func callContact(_ phoneNumber: String) {
        let phoneNumber = phoneNumber.filter { $0.isNumber }
        if let url = URL(string: "tel:\(phoneNumber)") {
            DispatchQueue.main.async {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }
}

/// View for adding contacts to favorites
struct AddToFavoritesView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var contactsManager: ContactsManager
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            VStack {
                if searchText.isEmpty {
                    Text("Select a contact to add to favorites")
                        .font(.headline)
                        .padding()
                }
                
                List(filteredContacts) { contact in
                    ContactRow(contact: contact, contactsManager: contactsManager)
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                }
                .searchable(text: $searchText, prompt: "Search contacts")
            }
            .navigationTitle("Add to Favorites")
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
    @State private var isSelected: Bool = false
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                // Contact photo
                ContactPhotoView(contact: contact, customImageData: .constant(nil), size: 40)
                
                // Contact info
                VStack(alignment: .leading, spacing: 2) {
                    let displayName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                    Text(displayName.isEmpty ? "Unknown Contact" : displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if contact.phoneNumbers.count == 1 {
                        Text(contact.phoneNumbers.first?.value.stringValue ?? "")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(contact.phoneNumbers.count) phone numbers")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Add button
                Button {
                    if contact.phoneNumbers.count == 1 {
                        // Single number - add directly
                        if let phoneNumber = contact.phoneNumbers.first?.value.stringValue {
                            contactsManager.addToFavorites(contact: contact, phoneNumber: phoneNumber)
                            isSelected = true
                        }
                    }
                    // For multiple numbers, users must select individual numbers below
                } label: {
                    Image(systemName: contact.phoneNumbers.count == 1 ? (isSelected ? "star.fill" : "star") : "star.circle")
                        .foregroundColor(contact.phoneNumbers.count == 1 ? (isSelected ? .yellow : .gray) : .gray)
                        .font(.title2)
                }
                .accessibilityLabel(contact.phoneNumbers.count == 1 ? "Add to favorites" : "Select individual numbers below")
                .disabled(contact.phoneNumbers.count > 1)
            }
            
            // Show all phone numbers if multiple
            if contact.phoneNumbers.count > 1 {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tap stars to add/remove numbers:")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.leading, 56)
                        .padding(.bottom, 4)
                    
                    ForEach(contact.phoneNumbers, id: \.identifier) { phoneNumber in
                        PhoneNumberRow(
                            contact: contact,
                            phoneNumber: phoneNumber,
                            contactsManager: contactsManager
                        )
                        .id("\(contact.identifier)_\(phoneNumber.identifier)")
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
    @State private var isSelected: Bool = false
    
    private var phoneString: String {
        phoneNumber.value.stringValue
    }
    
    var body: some View {
        HStack {
            Text(phoneString)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.leading, 56)
            
            Spacer()
            
            Button(action: {
                contactsManager.addToFavorites(contact: contact, phoneNumber: phoneString)
                isSelected = true
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
    let contact: CNContact
    @Binding var customImageData: Data?
    let size: CGFloat
    
    init(contact: CNContact, customImageData: Binding<Data?>, size: CGFloat = 50) {
        self.contact = contact
        self._customImageData = customImageData
        self.size = size
    }
    
    var body: some View {
        Group {
            if let data = customImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if let imageData = contact.thumbnailImageData ?? contact.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                // Fallback to initials
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: size, height: size)
                    .overlay {
                        Text(contact.givenName.prefix(1).uppercased())
                            .font(.system(size: size * 0.4, weight: .medium))
                            .foregroundColor(.blue)
                    }
            }
        }
        .id("\(contact.identifier)_\(customImageData?.count ?? 0)")
    }
}

/// Rectangular version of ContactPhotoView for larger displays
struct ContactPhotoViewRectangular: View {
    let contact: CNContact
    @Binding var customImageData: Data?
    let width: CGFloat
    let height: CGFloat
    
    init(contact: CNContact, customImageData: Binding<Data?>, width: CGFloat, height: CGFloat) {
        self.contact = contact
        self._customImageData = customImageData
        self.width = width
        self.height = height
    }
    
    var body: some View {
        Group {
            if let data = customImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
            } else if let imageData = contact.thumbnailImageData ?? contact.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
            } else {
                // Fallback to initials
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: width, height: height)
                    .overlay {
                        Text(contact.givenName.prefix(1).uppercased())
                            .font(.system(size: min(width, height) * 0.3, weight: .medium))
                            .foregroundColor(.blue)
                    }
            }
        }
        .id("\(contact.identifier)_\(customImageData?.count ?? 0)")
    }
}

/// Manager class for handling contacts and favorites
class ContactsManager: ObservableObject {
    @Published var favorites: [FavoriteContact] = []
    @Published var allContacts: [CNContact] = []
    @Published var isLoading = false
    
    private let store = CNContactStore()
    
    /// Requests access to contacts and loads them
    func requestAccess() {
        store.requestAccess(for: .contacts) { [weak self] granted, error in
            DispatchQueue.main.async {
                if granted {
                    self?.loadContacts()
                    self?.loadFavorites()
                } else {
                    print("Contacts access denied: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }
    
    /// Loads all contacts from the device
    private func loadContacts() {
        isLoading = true
        
        let request = CNContactFetchRequest(keysToFetch: [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactImageDataKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor
        ])
        
        var contacts: [CNContact] = []
        
        do {
            try store.enumerateContacts(with: request) { contact, _ in
                contacts.append(contact)
            }
            
            DispatchQueue.main.async {
                self.allContacts = contacts.sorted { contact1, contact2 in
                    let name1 = "\(contact1.givenName) \(contact1.familyName)"
                    let name2 = "\(contact2.givenName) \(contact2.familyName)"
                    return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
                }
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                print("Error loading contacts: \(error.localizedDescription)")
            }
        }
    }
    
    /// Loads favorites from UserDefaults
    private func loadFavorites() {
        if let data = UserDefaults.standard.data(forKey: "favorites"),
           let favorites = try? JSONDecoder().decode([FavoriteContact].self, from: data) {
            // Refetch CNContact for each favorite using stored identifier so image data is present
            var rebuilt: [FavoriteContact] = []
            for var fav in favorites {
                do {
                    let fetched = try store.unifiedContact(withIdentifier: fav.contactIdentifier, keysToFetch: [
                        CNContactGivenNameKey as CNKeyDescriptor,
                        CNContactFamilyNameKey as CNKeyDescriptor,
                        CNContactPhoneNumbersKey as CNKeyDescriptor,
                        CNContactImageDataKey as CNKeyDescriptor,
                        CNContactThumbnailImageDataKey as CNKeyDescriptor
                    ])
                    fav.contact = fetched
                    rebuilt.append(fav)
                } catch {
                    // Keep placeholder contact if fetch fails
                    rebuilt.append(fav)
                }
            }
            self.favorites = rebuilt
        }
    }
    
    /// Saves favorites to UserDefaults
    func saveFavorites() {
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: "favorites")
        }
    }
    
    /// Adds a contact to favorites with a specific phone number
    func addToFavorites(contact: CNContact, phoneNumber: String) {
        let favorite = FavoriteContact(
            contact: contact,
            phoneNumber: phoneNumber,
            displayName: "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
        )
        
        // Always add the favorite (allow duplicates)
        favorites.append(favorite)
        saveFavorites()
    }
    
    /// Legacy method for backward compatibility
    func addToFavorites(contact: CNContact) {
        guard let phoneNumber = contact.phoneNumbers.first?.value.stringValue else { return }
        addToFavorites(contact: contact, phoneNumber: phoneNumber)
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
    var contact: CNContact
    let contactIdentifier: String
    let phoneNumber: String
    let displayName: String
    var communicationMethod: CommunicationMethod
    var communicationApp: CommunicationApp
    // Optional custom avatar image data selected by user
    var customImageData: Data?
    
    enum CodingKeys: String, CodingKey {
        case contactIdentifier, phoneNumber, displayName, communicationMethod, communicationApp, customImageData
    }
    
    init(contact: CNContact, phoneNumber: String, displayName: String, communicationMethod: CommunicationMethod = .voiceCall, communicationApp: CommunicationApp? = nil, customImageData: Data? = nil) {
        self.contact = contact
        self.contactIdentifier = contact.identifier
        self.phoneNumber = phoneNumber
        self.displayName = displayName
        self.communicationMethod = communicationMethod
        self.customImageData = customImageData
        
        // Set appropriate default app based on communication method
        if let app = communicationApp {
            self.communicationApp = app
        } else {
            switch communicationMethod {
            case .voiceCall:
                self.communicationApp = .phone
            case .videoCall:
                self.communicationApp = .phone
            case .textMessage:
                self.communicationApp = .messages
            }
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        contactIdentifier = try container.decode(String.self, forKey: .contactIdentifier)
        phoneNumber = try container.decode(String.self, forKey: .phoneNumber)
        displayName = try container.decode(String.self, forKey: .displayName)
        communicationMethod = try container.decodeIfPresent(CommunicationMethod.self, forKey: .communicationMethod) ?? .voiceCall
        communicationApp = try container.decodeIfPresent(CommunicationApp.self, forKey: .communicationApp) ?? .phone
        customImageData = try container.decodeIfPresent(Data.self, forKey: .customImageData)
        
        // Placeholder; will be replaced after load using contactIdentifier
        contact = CNContact()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(contactIdentifier, forKey: .contactIdentifier)
        try container.encode(phoneNumber, forKey: .phoneNumber)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(communicationMethod, forKey: .communicationMethod)
        try container.encode(communicationApp, forKey: .communicationApp)
        try container.encodeIfPresent(customImageData, forKey: .customImageData)
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
        
        // Always include Phone and Messages as they're built into iOS
        installedApps.append(.phone)
        installedApps.append(.messages)
        print("✅ Added built-in apps: Phone, Messages")
        
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
    @State private var selectedMethod: CommunicationMethod
    @State private var selectedApp: CommunicationApp
    @State private var availableApps: [CommunicationApp] = []
    
    init(favorite: Binding<FavoriteContact>) {
        self._favorite = favorite
        self._selectedMethod = State(initialValue: favorite.wrappedValue.communicationMethod)
        self._selectedApp = State(initialValue: favorite.wrappedValue.communicationApp)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Communication Method") {
                    Picker("Method", selection: $selectedMethod) {
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
                
                Section("Communication App") {
                    if availableApps.isEmpty {
                        Text("No compatible apps found")
                            .foregroundColor(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Choose your preferred app:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Picker("App", selection: $selectedApp) {
                                ForEach(availableApps, id: \.self) { app in
                                    HStack {
                                        Image(systemName: app.icon)
                                            .foregroundColor(.green)
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
                        
                        HStack {
                            Image(systemName: selectedMethod.icon)
                                .foregroundColor(.blue)
                            Text(selectedMethod.rawValue)
                            Spacer()
                            Image(systemName: selectedApp.icon)
                                .foregroundColor(.green)
                            Text(selectedApp.rawValue)
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
            selectedApp = availableApps.first ?? .phone
        }
    }
}

// MARK: - Photo Picker Section
@available(iOS 16.0, *)
struct PhotoPickerSection: View {
    @Binding var favorite: FavoriteContact
    @State private var selectedItem: PhotosPickerItem? = nil
    
    init(favorite: Binding<FavoriteContact>) {
        self._favorite = favorite
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                ContactPhotoView(contact: favorite.contact, customImageData: $favorite.customImageData, size: 60)
                
                VStack(alignment: .leading, spacing: 12) {
                    // Photo picker button
                    PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                        HStack {
                            Image(systemName: "photo")
                                .foregroundColor(.blue)
                            Text("Choose Photo")
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    if favorite.customImageData != nil {
                        Button(role: .destructive) {
                            favorite.customImageData = nil
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
        .onChange(of: selectedItem) { _, newItem in
            guard let item = newItem else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    let resized = resizeImage(uiImage, maxDimension: 256)
                    if let jpeg = resized.jpegData(compressionQuality: 0.85) {
                        DispatchQueue.main.async {
                            favorite.customImageData = jpeg
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

/// Detailed view for a single contact with swipe navigation
struct ContactDetailView: View {
    @Binding var favorite: FavoriteContact
    @ObservedObject var contactsManager: ContactsManager
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int = 0
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
        .onChange(of: currentIndex) { newIndex in
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
                                        Text("")
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
                                        Text("")
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
                                ContactPhotoViewRectangular(contact: favorite.contact, customImageData: $favorite.customImageData, width: geometry.size.width, height: geometry.size.height * 0.6)
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
                
                // Settings Button - Below phone number showing dial method
                Button(action: {
                    // This would open settings - for now just a placeholder
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
                                .foregroundColor(.green)
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
        let cleanPhoneNumber = favorite.phoneNumber.filter { $0.isNumber || $0 == "+" }
        let phoneNumber = cleanPhoneNumber.replacingOccurrences(of: "+", with: "")
        
        var urlString: String
        
        switch (favorite.communicationMethod, favorite.communicationApp) {
        case (.voiceCall, .phone):
            urlString = "tel:\(favorite.phoneNumber)"
        case (.videoCall, .phone):
            urlString = "facetime:\(phoneNumber)"
        case (.textMessage, .messages):
            urlString = "sms:\(phoneNumber)"
        case (.voiceCall, .whatsapp):
            urlString = "whatsapp://calluser/?phone=\(phoneNumber)"
        case (.videoCall, .whatsapp):
            urlString = "whatsapp://send?phone=\(phoneNumber)"
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
        case (.textMessage, .phone):
            urlString = "sms:\(phoneNumber)"
        default:
            urlString = "tel:\(phoneNumber)"
        }
        
        if let url = URL(string: urlString) {
            DispatchQueue.main.async {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
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
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }
}

#Preview {
    ContentView()
}
