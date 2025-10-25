# User Prompts History - EasyDial Project

This file contains all the prompts and requests made during the development of the EasyDial iOS application.

## **📋 All User Prompts and Requests:**

### **1. Initial Voice Call Detection Questions:**
- "Voice calls using the native IOS calling does not leave the My Dial app, so we should only send a notification if the MyDial app is not in focus, is that the case, just checking"
- "even during a whatsapp call, the user could navigate back to the Mydial app, if that happens what does the app do ?"

### **2. Version and Build Updates:**
- "we need to increase the build number, want to get it ready for distribution"
- "can we change the version to 1.4.1"
- "Change version to 1.4.2 Build 7"
- "Change version to 1.4.3 , build 8"
- "Lets update the version to 1.5.0 and build 9"
- "can we update the version to 1.5.1"

### **3. CallKit and China Region:**
- "does this app have CallKit functionality"
- "can we disable this for users in china"

### **4. Help File Updates:**
- "In the help file, underr customizing contacts, please add something like this as well, you can correct and elaborate: You can have the same contact person added multiple times..."
- "update the hellp file on the new features on the canvas, also write the fonts availabe in the font itself in the help file"

### **5. Communication App Label Changes:**
- "In the call type option , please change Factime /Message to Facetime and the other option from Phone / Message to Phone iOS"

### **6. Canvas Feature Development:**
- "in the edit menu of a contact, we have Gallery & Camera, can we add 1 more option Canvas"
- "I have the way i want the canvas editing and options working in another project, how would i share it so you can implement it exactly like that"
- "When adding a text field, and the up and down arrors appear, can we make the colour subtle and transparent, also make all the other button colors more subtle"
- "ok, do it"
- "all the font names in the drop down menu are in system font only"
- "is there anything you need to unto since the preview font in picklist did not work"
- "lets do option 2 first"
- "lets do option 3 now"
- "the font menu shows all fonts in the system font, when i long press a font type from the pick list, could it be possible to pop up the text name in that text font , like a preview, until i release my press"
- "undo last change"
- "can we fit the word color next to the color picker , maybe move the word Canvas lightly more left"
- "the word 'color' only shows c... (C & 3 dots)"
- "there must be another reason why the text 'color' was not showing in normal size, because there is enough space between the word canvas and the waord save"

### **7. Floating Done Button:**
- "when adding a new contact, if you not scrolling through available contacts, but searching available contacts to add to my dial, give me a popup done button, when this button is pressed, simulate pressing the 'cancel' button visible on the search dialouge"
- "can you make this 'done' button a floating done button"
- "nice done button, but is not moveable,"
- "i dont see the button at all now"
- "can this initial position of the new done button be on the top of that same frame instaed of where its placed"
- "prefect that works, but the button when moving does not drag with your finger, its stays in its old position and then appears at the new position"
- "its still not dragging,"
- "can you change the initial position , same horizontal position but the highest possible vertical postion"
- "please move the button horizontally very slightly left"

### **8. Voice Name File Naming:**
- "explain to me how you name the jpg file names for canvas favourites, especially after the contact identifier"
- "don't do it yet, but is this possible : can you do the same method for the voice name files : File Name Creation: contactId + "Voice" + randomUUID + ".mp4""
- "m4a is fine, do this method for the voice files"
- "change m4a filename to this pattern : Pattern: contactId + "_voice_" + randomUUID + ".m4a""

### **9. Voice File Persistence Issues:**
- "before closing the app : contact 0 had a voice file : 🎯 Final result: ["FaceTime", "Phone iOS", "Telegram", "WhatsApp"]... after closing and reopening the app : no voice file"
- "No, after closing and reopening the app the recording does not persist"
- "im not seeing any of the test 1 test 2 etc messages ?"
- "No test messages, and it still does not work"
- "delete the temp recording file not found - message"
- "when going into the voice name menu, the save button should only be available after a record has been done, not after just a playback"

### **10. Voice File Overwriting Issues:**
- "For some reason if the same name is more than 2 favourites, the last voicenote owerwrites the 1st voicenote, see saame voice filename for Favorite 0 and 3"
- "I have deleted all 5 contacts voicename, and when editing them, the screen shows no voice note, but how come the debug screen indicates voice nootes for some of the favourites"
- "undo the recursive delete"
- "I dont think it goto do with uniquness, when editing and saving on name index2, how is name index1 voice file name being overwritten. you saving it for index2 and overwriting index1's voicenote. you should only deal with the index you working with, not itterate through other favourites. In this case index 1 had a unique name, and when a name for index 2 was created, and on the save action for index 2 it owerwrote index 1's voicenote name"

### **11. Play Button Issue:**
- "after the recording, i cannot press play immediatly to hear recording, i have to save, exit comeback and press play to replay recording."

### **12. Delete Voice Logic:**
- "Also in the voice name screen, if you delete a voice name, the save option must be available to save the delete, if you press cancel , the delete must not occur"

### **13. File Management Requests:**
- "can i get a list of all my prompts thus far"
- "can all these prompts be written to a file"

---

## **📊 Summary Statistics:**
- **Total Prompts:** 40+
- **Major Features Implemented:** Canvas drawing, Voice recording, Floating buttons, Version updates
- **Bug Fixes:** Voice persistence, File overwriting, Play button functionality, Delete logic
- **UI/UX Improvements:** Color picker, Font selection, Button positioning, Navigation

---

## **📝 Notes:**
This file was generated automatically and contains all user prompts from the EasyDial project development session. Each prompt represents a specific feature request, bug report, or improvement suggestion that was implemented or addressed during the development process.

**Generated on:** $(date)
**Project:** EasyDial iOS Application
**Total Development Time:** Multiple sessions
