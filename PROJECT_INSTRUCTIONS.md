# EasyDial/My Dial - Project Instructions & Prompts

This document contains all the instructions and prompts given during the development of the EasyDial/My Dial iOS app project.

## Table of Contents
1. [App Naming & Branding](#app-naming--branding)
2. [UI/UX Improvements](#uiux-improvements)
3. [Technical Issues & Fixes](#technical-issues--fixes)
4. [Version Management](#version-management)
5. [App Store Preparation](#app-store-preparation)
6. [Persistence Issues](#persistence-issues)

---

## App Naming & Branding

### 1. App Name Alternatives
**Prompt:** "can you give me alternate names for this app"

**Response:** Provided various alternative names for the contact dialing app.

### 2. Text Changes
**Prompt:** "need to change the text 'Easy Dial' to 'My Dial' on the Favorites page as well as everywhere in the help file"

**Implementation:** 
- Updated all UI text references from "Easy Dial" to "My Dial"
- Updated help content throughout the app
- Changed app display name under the icon

### 3. App Icon Name
**Prompt:** "the name under the icon still says easy dial, can this be changed"

**Implementation:** 
- Updated `CFBundleDisplayName` in Info.plist and project.pbxproj
- Changed from "Easy Dial" to "My Dial"

---

## UI/UX Improvements

### 4. Color Adjustments
**Prompt:** "can you tone down the green colour of the dial , message camera icons on the Right hand side of the favorite screen."

**Implementation:** 
- Adjusted green color values for dial, message, and camera icons
- Made colors more muted and visually appealing

### 5. Suggestion Box Feature
**Prompt:** "in the 'i' section , can you also add a suggedtion box the user can fill to send to the app developer via email"

**Implementation:** 
- Added suggestion box in the info menu
- Integrated with email functionality using `mailto:` URL scheme
- Pre-fills email with suggestion content

### 6. Button Styling
**Prompt:** "On the favorites page change the >>My Dial<< to My Dial with a light grey background indicating a button"

**Implementation:** 
- Updated "My Dial" button styling
- Added light grey background with padding and rounded corners
- Updated corresponding help text

### 7. Navigation Button Visuals
**Prompt:** "the circular navigation button had a slight outline , that is not there anymore"

**Implementation:** 
- Restored visual styling for navigation buttons
- Added chevron icons with rounded rectangle borders
- Maintained circular navigation functionality

---

## Technical Issues & Fixes

### 8. UserDefaults Size Limit Issue
**Prompt:** Multiple reports of `CFPrefsPlistSource` warnings about storing >= 4MB data in UserDefaults

**Issue:** "This happens only on the 1st swipe" - repeated multiple times

**Root Cause:** Large image data within CNContact objects being stored in UserDefaults

**Solutions Implemented:**
1. **File-based Image Storage**: Created `ImageStorageManager` to store images in file system
2. **On-demand Contact Loading**: Fetch contact details only when needed
3. **Clean Data Storage**: Store only essential contact identifiers and names
4. **Migration Logic**: Handle existing large data gracefully

### 9. CNPropertyNotFetchedException
**Prompt:** "When trying to delete an old contact , it crashes"

**Issue:** Crash when accessing contact properties that weren't fetched

**Solution:** 
- Ensured all required contact keys are fetched
- Removed debug code accessing unfetched properties
- Added proper error handling

### 10. Navigation Issues
**Prompt:** "something broke, after going to the favorite page and then pressing my dial, a single contact page displays, by cannot navigate through to other contact, no buttons, no swiping"

**Solution:** 
- Restored TabView with PageTabViewStyle for swiping
- Re-implemented invisible navigation buttons
- Fixed direct navigation to contact detail view

### 11. Startup Logic
**Prompt:** "if saved index is -1 , then show the favorite page on startup, don't change lastViewedContactIndex to 0 , leave at -1"

**Implementation:** 
- Modified startup logic to respect -1 index
- Only change to 0 when "My Dial" button is explicitly pressed
- Maintained proper state management

### 12. Background Loading
**Prompt:** "I know the contacts are loaded on start up, can you first load the page that needs to be displayed, and then keep on loading the contacts in the background"

**Implementation:** 
- Fast startup: Load favorites first (no contact access required)
- Background loading: Load all contacts asynchronously
- Added loading indicator for background activity

### 13. Info Button Issues
**Prompt:** "the i button on the individual contact page is not working"

**Issue:** ActionSheet not appearing due to view hierarchy problems

**Solution:** 
- Replaced ActionSheet with .sheet presentation
- Created InfoMenuView for consistent presentation
- Fixed view layering with ZStack and zIndex

### 14. Circular Navigation
**Prompt:** "when using the tap navigation, tapping backwards until the index 0, one more tap should take it back to index 13, the circular indexing is not working on the tapping backwards or forward"

**Implementation:** 
- Fixed circular navigation logic for tap buttons
- Implemented proper wrapping from first to last contact
- Removed disabled state to ensure buttons are always active

---

## Version Management

### 15. Version Information
**Prompt:** "is the current version of this software"

**Response:** Provided current version information and versioning guidance.

### 16. Proper Versioning
**Prompt:** "yes help proper versioning"

**Implementation:** 
- Added CFBundleShortVersionString and CFBundleVersion to Info.plist
- Updated MARKETING_VERSION and CURRENT_PROJECT_VERSION in project.pbxproj
- Created git tags for releases

### 17. Version Updates
**Prompt:** "te the build number 1.1.0"
**Prompt:** "1.2.0"

**Implementation:** 
- Updated version numbers in both Info.plist and project.pbxproj
- Incremented build numbers accordingly
- Created corresponding git tags

---

## App Store Preparation

### 18. Promotional Text
**Prompt:** "promotional text for this app"

**Response:** Generated comprehensive App Store promotional content including:
- Short descriptions
- Subtitles
- Full descriptions
- Keywords
- Feature highlights

### 19. Privacy Policy
**Prompt:** "Please give me a Privacy Policy required by apple for this app"

**Implementation:** 
- Created comprehensive Privacy_Policy.md
- Addressed Apple's requirements, GDPR, CCPA
- Emphasized local data storage and no data sharing
- Included children's privacy section

---

## Persistence Issues

### 20. Image Persistence Regression
**Prompt:** "The app is not saving pictures, canvas etc after a reload of the app, i think we going backwards"

**Issue:** Custom images and canvas data not persisting after app reloads

**Initial Fixes:**
- Fixed canvas data encoding error handling
- Updated outdated onChange SwiftUI syntax
- Added debug logging for troubleshooting

### 21. Revert Attempts
**Prompt:** "still not working, can we go back to the old way the canvas and pictures were saved"

**Attempt 1:** Reverted to `customImageData: Data?` (direct UserDefaults storage)
**Result:** Still not working

**Prompt:** "it did not work, images, picutes & canvas are not being reloaded when app is reloaded. look at the implementation before we added voice names"

**Attempt 2:** Reverted to `customImageFileName: String?` with `ImageStorageManager` (file-based storage)
**Result:** Still not working

### 22. Debug Analysis
**Debug Output Analysis:**
- Images ARE being loaded successfully from file system
- But `customImageFileName` is `nil` in ContactPhotoView
- Issue: Filename not being properly stored/retrieved from UserDefaults

### 23. Final Solution
**Prompt:** "lets revert back to version 1.5.1"

**Implementation:** 
- Successfully reverted to commit "050b1a1 Version 1.5.1"
- Restored working image and canvas persistence
- Removed all debug code and problematic changes

---

## Voice Name Implementation (Future Feature)

### 24. Voice Name Recording Feature
**Context:** Voice names were mentioned as a feature that was added after version 1.5.1, but caused persistence issues

**Intended Implementation:**
- **Feature**: Allow users to record voice notes/names for contacts
- **Storage**: Voice recordings stored as audio files in file system
- **Data Structure**: `voiceNoteFileName: String?` in FavoriteContact
- **UI**: Voice recording button in contact configuration
- **Playback**: Tap to play recorded voice name

**Technical Requirements:**
```swift
// Data structure addition
struct FavoriteContact {
    var voiceNoteFileName: String?  // Audio file name
    // ... existing properties
}

// Audio recording functionality
- AVAudioRecorder for recording
- AVAudioPlayer for playback
- File system storage for audio files
- Audio file management (cleanup, etc.)
```

**Storage Architecture:**
- **Audio Files**: Stored in `/Documents/VoiceNotes/` directory
- **UserDefaults**: Only filename stored (similar to image approach)
- **File Format**: M4A or WAV format for iOS compatibility
- **File Naming**: `contactId_UUID.m4a`

**UI Components Needed:**
- Voice recording button in contact configuration
- Playback controls (play/pause/stop)
- Visual feedback during recording
- Audio level indicators
- Duration display

**Implementation Notes:**
- Voice names were implemented after version 1.5.1
- Caused persistence issues with image/canvas data
- Reverted to v1.5.1 to restore working state
- Voice name feature needs to be re-implemented carefully to avoid persistence conflicts

---

---

## Technical Architecture (Version 1.5.1)

### Image Storage
- **Method**: File system + UserDefaults
- **File Location**: `/Documents/ContactImages/`
- **UserDefaults**: Only filename stored
- **Benefits**: Avoids 4MB limit, persistent storage

### Canvas Storage
- **Method**: UserDefaults (JSON)
- **Key Format**: `"CanvasData_contactIdentifier"`
- **Data Structure**: CanvasData with drawings and text items
- **Benefits**: Efficient storage, easy serialization

### Contact Data
- **Method**: UserDefaults (JSON) + on-demand fetching
- **Stored**: Essential identifiers and names only
- **Not Stored**: CNContact objects (too large)
- **Benefits**: Fast loading, memory efficient

### Voice Notes (Future Feature)
- **Method**: File system + UserDefaults (filename only)
- **File Location**: `/Documents/VoiceNotes/`
- **UserDefaults**: Only filename stored
- **File Format**: M4A or WAV
- **Benefits**: Avoids UserDefaults size limit, persistent audio storage

---

## Key Learnings

1. **UserDefaults Limitations**: 4MB size limit requires careful data management
2. **File System Storage**: Better for large binary data (images)
3. **On-Demand Loading**: Fetch heavy data only when needed
4. **Version Control**: Proper git tagging for release management
5. **Debug Logging**: Essential for troubleshooting persistence issues
6. **SwiftUI Syntax**: Modern onChange syntax required for iOS updates

---

## Project Status

**Current Version**: 1.5.1 (Build 10)
**Last Working State**: Images, canvas, and contact data persist properly
**App Name**: My Dial
**Platform**: iOS (SwiftUI)

---

*This document was generated from the complete conversation history of the EasyDial/My Dial project development.*
