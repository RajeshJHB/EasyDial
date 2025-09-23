//
//  ContentView.swift
//  EasyDial
//
//  Created by Rajesh Solanki on 9/13/25.
//

import SwiftUI
import Contacts
import UIKit

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
        }
        .onAppear {
            contactsManager.requestAccess()
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
            ForEach(contactsManager.favorites) { favorite in
                FavoriteContactRow(favorite: favorite, isEditMode: isEditMode, contactsManager: contactsManager)
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
    @State private var favorite: FavoriteContact
    let isEditMode: Bool
    @ObservedObject var contactsManager: ContactsManager
    @State private var showingConfig = false
    
    init(favorite: FavoriteContact, isEditMode: Bool, contactsManager: ContactsManager) {
        self._favorite = State(initialValue: favorite)
        self.isEditMode = isEditMode
        self.contactsManager = contactsManager
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Contact photo
            ContactPhotoView(contact: favorite.contact, size: 50)
            
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
                
                // Show if this contact has multiple numbers in favorites
                if contactsManager.favorites.filter({ $0.contact.identifier == favorite.contact.identifier }).count > 1 {
                    Text("Multiple numbers available")
                        .font(.caption)
                        .foregroundColor(.orange)
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
            if isEditMode {
                showingConfig = true
            }
        }
        .sheet(isPresented: $showingConfig) {
            CommunicationConfigView(favorite: $favorite)
                .onDisappear {
                    // Update the favorite in the contacts manager
                    if let index = contactsManager.favorites.firstIndex(where: { $0.id == favorite.id }) {
                        contactsManager.favorites[index] = favorite
                        contactsManager.saveFavorites()
                    }
                }
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
        
        // Debug logging
        print("🔍 Communication Debug:")
        print("🔍 Method: \(favorite.communicationMethod.rawValue)")
        print("🔍 App: \(favorite.communicationApp.rawValue)")
        print("🔍 Original Phone: \(favorite.phoneNumber)")
        print("🔍 Cleaned Phone: \(phoneNumber)")
        
        switch (favorite.communicationMethod, favorite.communicationApp) {
        case (.voiceCall, .phone):
            urlString = "tel:\(favorite.phoneNumber)" // Use original format to avoid prompts
            print("🔍 Matched: Voice Call + Phone = TEL (original format)")
        case (.videoCall, .phone):
            urlString = "facetime:\(phoneNumber)"
        case (.textMessage, .messages):
            urlString = "sms:\(phoneNumber)"
            print("🔍 Matched: Text Message + Messages = SMS")
            case (.voiceCall, .whatsapp):
                urlString = "whatsapp://calluser/?phone=\(phoneNumber)"
             // urlString = "x-safari-https://whatsapp://send?phone=\(phoneNumber)"

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
            print("🔍 Matched: Text Message + Phone (legacy) = SMS")
        default:
            // Fallback to phone call
            urlString = "tel:\(phoneNumber)"
            print("🔍 Matched: DEFAULT case - Phone call fallback")
        }
        
        print("🔍 Final URL: \(urlString)")
        
        if let url = URL(string: urlString) {
            print("🔍 About to open URL: \(urlString)")
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

/// Row view for displaying a contact in the add to favorites list
struct ContactRow: View {
    let contact: CNContact
    @ObservedObject var contactsManager: ContactsManager
    
    private var isFavorite: Bool {
        contactsManager.favorites.contains { $0.contact.identifier == contact.identifier }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                // Contact photo
                ContactPhotoView(contact: contact, size: 40)
                
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
                
                // Add/Remove button
                Button {
                    if contact.phoneNumbers.count == 1 {
                        // Single number - add/remove directly
                        if let phoneNumber = contact.phoneNumbers.first?.value.stringValue {
                            if isFavorite {
                                contactsManager.removeFavorite(contact: contact, phoneNumber: phoneNumber)
                            } else {
                                contactsManager.addToFavorites(contact: contact, phoneNumber: phoneNumber)
                            }
                        }
                    }
                    // For multiple numbers, users must select individual numbers below
                } label: {
                    Image(systemName: contact.phoneNumbers.count == 1 ? (isFavorite ? "star.fill" : "star") : "star.circle")
                        .foregroundColor(contact.phoneNumbers.count == 1 ? (isFavorite ? .yellow : .gray) : .gray)
                        .font(.title2)
                }
                .accessibilityLabel(contact.phoneNumbers.count == 1 ? (isFavorite ? "Remove from favorites" : "Add to favorites") : "Select individual numbers below")
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
    
    private var uniqueKey: String {
        "\(contact.identifier)_\(phoneString)"
    }
    
    var body: some View {
        HStack {
            Text(phoneString)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.leading, 56)
            
            Spacer()
            
            Button(action: {
                print("🔍 TAPPING STAR for phone: \(phoneString)")
                print("🔍 Contact ID: \(contact.identifier)")
                print("🔍 Current isSelected: \(isSelected)")
                print("🔍 All phone numbers for this contact:")
                for (index, phone) in contact.phoneNumbers.enumerated() {
                    print("🔍   \(index): \(phone.value.stringValue)")
                }
                
                if isSelected {
                    print("🗑️ REMOVING from favorites")
                    contactsManager.removeFavorite(contact: contact, phoneNumber: phoneString)
                    isSelected = false
                } else {
                    print("➕ ADDING to favorites")
                    contactsManager.addToFavorites(contact: contact, phoneNumber: phoneString)
                    isSelected = true
                }
                
                print("🔍 After action - isSelected: \(isSelected)")
                print("🔍 Total favorites count: \(contactsManager.favorites.count)")
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
        .onAppear {
            // Initialize the local state based on current favorites
            isSelected = contactsManager.favorites.contains { favorite in
                favorite.contact.identifier == contact.identifier && favorite.phoneNumber == phoneString
            }
        }
        .onChange(of: contactsManager.favorites) { newFavorites in
            // Update local state when favorites change
            isSelected = newFavorites.contains { favorite in
                favorite.contact.identifier == contact.identifier && favorite.phoneNumber == phoneString
            }
        }
    }
}

/// Reusable view for displaying contact photos with fallback to initials
struct ContactPhotoView: View {
    let contact: CNContact
    let size: CGFloat
    
    init(contact: CNContact, size: CGFloat = 50) {
        self.contact = contact
        self.size = size
    }
    
    var body: some View {
        Group {
            if let imageData = contact.thumbnailImageData ?? contact.imageData,
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
            self.favorites = favorites
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
        print("📞 addToFavorites CALLED")
        print("📞 Contact ID: \(contact.identifier)")
        print("📞 Phone Number: \(phoneNumber)")
        print("📞 Contact has \(contact.phoneNumbers.count) phone numbers")
        print("📞 Current favorites count: \(favorites.count)")
        
        let favorite = FavoriteContact(
            contact: contact,
            phoneNumber: phoneNumber,
            displayName: "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
        )
        
        // Check if this exact combination (contact + phone number) already exists
        let alreadyExists = favorites.contains { existingFavorite in
            existingFavorite.contact.identifier == contact.identifier && existingFavorite.phoneNumber == phoneNumber
        }
        
        print("📞 Already exists: \(alreadyExists)")
        
        if !alreadyExists {
            print("📞 Adding new favorite")
            favorites.append(favorite)
            saveFavorites()
            print("📞 New favorites count: \(favorites.count)")
        } else {
            print("📞 Skipping - already exists")
        }
    }
    
    /// Legacy method for backward compatibility
    func addToFavorites(contact: CNContact) {
        guard let phoneNumber = contact.phoneNumbers.first?.value.stringValue else { return }
        addToFavorites(contact: contact, phoneNumber: phoneNumber)
    }
    
    /// Removes a contact from favorites
    func removeFavorite(contact: CNContact) {
        favorites.removeAll { $0.contact.identifier == contact.identifier }
        saveFavorites()
    }
    
    /// Removes a specific contact with specific phone number from favorites
    func removeFavorite(contact: CNContact, phoneNumber: String) {
        favorites.removeAll { favorite in
            favorite.contact.identifier == contact.identifier && favorite.phoneNumber == phoneNumber
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
    let contact: CNContact
    let phoneNumber: String
    let displayName: String
    var communicationMethod: CommunicationMethod
    var communicationApp: CommunicationApp
    
    enum CodingKeys: String, CodingKey {
        case phoneNumber, displayName, communicationMethod, communicationApp
    }
    
    init(contact: CNContact, phoneNumber: String, displayName: String, communicationMethod: CommunicationMethod = .voiceCall, communicationApp: CommunicationApp? = nil) {
        self.contact = contact
        self.phoneNumber = phoneNumber
        self.displayName = displayName
        self.communicationMethod = communicationMethod
        
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
        phoneNumber = try container.decode(String.self, forKey: .phoneNumber)
        displayName = try container.decode(String.self, forKey: .displayName)
        communicationMethod = try container.decodeIfPresent(CommunicationMethod.self, forKey: .communicationMethod) ?? .voiceCall
        communicationApp = try container.decodeIfPresent(CommunicationApp.self, forKey: .communicationApp) ?? .phone
        
        // Reconstruct contact from stored data
        let tempContact = CNContact()
        contact = tempContact
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(phoneNumber, forKey: .phoneNumber)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(communicationMethod, forKey: .communicationMethod)
        try container.encode(communicationApp, forKey: .communicationApp)
    }
    
    // MARK: - Equatable
    static func == (lhs: FavoriteContact, rhs: FavoriteContact) -> Bool {
        return lhs.contact.identifier == rhs.contact.identifier &&
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
                
                Section("Available Communication Apps") {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(CommunicationApp.allCases, id: \.self) { app in
                            HStack {
                                Image(systemName: app.icon)
                                    .foregroundColor(availableApps.contains(app) ? .green : .gray)
                                    .frame(width: 20)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(app.rawValue)
                                        .foregroundColor(availableApps.contains(app) ? .primary : .secondary)
                                    
                                    // Debug info
                                    Text("Scheme: \(app.urlScheme)://")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if availableApps.contains(app) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                } else {
                                    Text("Not Installed")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                
                Section("Debug Info") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Detection Results:")
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        ForEach(CommunicationApp.allCases, id: \.self) { app in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(app.rawValue)
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                    
                                    Text("Scheme: \(app.urlScheme)://")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text(AppDetectionUtility.isAppInstalled(urlScheme: app.urlScheme) ? "✅" : "❌")
                                    .font(.caption)
                            }
                            .padding(.vertical, 2)
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("All URL Schemes Test:")
                                .font(.caption2)
                                .fontWeight(.semibold)
                            
                            let debugResults = AppDetectionUtility.debugAllSchemes()
                            ForEach(Array(debugResults.keys.sorted()), id: \.self) { scheme in
                                HStack {
                                    Text("\(scheme)://")
                                        .font(.caption2)
                                        .monospaced()
                                    
                                    Spacer()
                                    
                                    Text(debugResults[scheme] == true ? "✅" : "❌")
                                        .font(.caption2)
                                }
                            }
                        }
                        
                        Button("Refresh Detection") {
                            loadAvailableApps()
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.top, 4)
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

#Preview {
    ContentView()
}
