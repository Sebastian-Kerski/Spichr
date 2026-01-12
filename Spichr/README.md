# Spichr - Food Inventory Management App

A SwiftUI app for managing food inventory with expiration tracking and CloudKit sharing.

## 🐛 Current Issue - Help Needed

**Problem:** CloudKit Sharing shows "Object not available" error when accepting share invitation.

**What I've tried:**
- ✅ Set `share.publicPermission = .readWrite` in `PersistenceController.swift` (line 310)
- ✅ Nuclear Reset CloudKit data
- ✅ Tested with two different Apple IDs
- ❌ Still getting "Objekt nicht verfügbar" / "Object not available" error

**Logs show:**
```
✅ Share created with READ/WRITE permissions
✅ Share URL: https://www.icloud.com/share/[ID]#Spichr_Household
```

But when second user opens the link:
```
❌ "Die Person, der die Datei gehört, teilt diese nicht mehr 
    oder dein Account 'test@example.com' ist nicht 
    berechtigt, sie zu öffnen."
```

**Need help with:** CloudKit sharing permissions setup

---

## 📱 Features

- ✅ Food inventory management
- ✅ Expiration date tracking
- ✅ Barcode scanning
- ✅ Shopping list
- ✅ CloudKit sync
- ⚠️ CloudKit sharing (currently broken)
- ✅ 19 language localizations
- ✅ Dark mode support

## 🏗️ Architecture

- **SwiftUI** for UI
- **Core Data** for local storage
- **CloudKit** for sync and sharing
- **NSPersistentCloudKitContainer** for CoreData + CloudKit integration

## 📂 Project Structure

```
Spichr/
├── Persistence/
│   ├── PersistenceController.swift  ⭐ CloudKit sharing logic here
│   └── CoreDataMigration.swift
├── Models/
│   ├── FoodItem+Extensions.swift
│   └── FoodItem+Household.swift
├── Views/
│   ├── Settings/SimpleHouseholdView.swift  ⭐ Sharing UI
│   ├── Stock/
│   ├── Shopping/
│   └── Shared/
├── Services/
│   ├── HouseholdManager.swift  ⭐ Sharing coordination
│   ├── CloudKitCleanupManager.swift
│   ├── BarcodeService.swift
│   └── NotificationService.swift
├── ViewModels/
└── Resources/ (19 languages)
```

## 🔧 CloudKit Setup

**Container:** `iCloud.com.de.SkerskiDev.FoodGuard`

**Capabilities:**
- iCloud (CloudKit)
- Background Modes (Remote notifications)

**Core Data Model:**
- Entity: `FoodItem`
- CloudKit integration: YES
- Share support: YES

## 💡 Sharing Implementation

### Current Implementation (PersistenceController.swift, lines 270-320)

```swift
func shareItems(_ items: [FoodItem]) async throws -> (CKShare, CKContainer) {
    // ...
    container.share([rootItem], to: nil) { objectIDs, share, ckContainer, error in
        // ...
        
        // ⭐ THE FIX (but still not working)
        share.publicPermission = .readWrite
        share[CKShare.SystemFieldKey.title] = "Spichr Household"
        
        if #available(iOS 15.0, *) {
            share[CKShare.SystemFieldKey.shareType] = "com.de.SkerskiDev.FoodGuard.household"
        }
        
        continuation.resume(returning: (share, ckContainer))
    }
}
```

### What I expected:
- Owner creates share
- Owner sends link via iMessage
- Recipient opens link
- Share is accepted
- Items sync automatically

### What actually happens:
- Owner creates share ✅
- Share URL is generated ✅
- Recipient gets error ❌: "Account not authorized to open"

## 🆘 Questions for the Community

1. Is `share.publicPermission = .readWrite` correct for NSPersistentCloudKitContainer sharing?
2. Do I need to explicitly add participants? (Currently relying on share URL)
3. Is there a CoreData configuration I'm missing?
4. Could this be an iCloud container entitlement issue?

## 🔍 Debugging Steps Tried

- [x] Verified iCloud container identifier matches everywhere
- [x] Checked that both users are logged into iCloud
- [x] Nuclear reset CloudKit data on both devices
- [x] Deleted and recreated shares multiple times
- [x] Checked CloudKit Dashboard (shares exist with correct permissions)
- [x] Verified share.publicPermission is set before saving
- [x] Tested on physical devices (not simulator)

## 📚 References

Based on:
- Apple WWDC 2021 Session 10015: "Build apps that share data through CloudKit and Core Data"
- NSPersistentCloudKitContainer documentation
- CKShare.PublicPermission documentation

## 🚀 How to Run

1. Clone the repository
2. Open `Spichr.xcodeproj` in Xcode
3. Select your team in Signing & Capabilities
4. Build and run (⌘R)

**Requirements:**
- Xcode 15.0+
- iOS 17.0+
- Two iOS devices with different Apple IDs for testing sharing

## 🤝 Contributing

**I need help!** If you have experience with CloudKit sharing, please take a look at:
- `Spichr/Persistence/PersistenceController.swift` (lines 270-320)
- `Spichr/Services/HouseholdManager.swift` (lines 68-146)

Any insights appreciated! 🙏

## 📄 License

[Your License Here]

## 👤 Author

Sebastian Kerski - spichr.contact@gmail.com

---

**Status:** Looking for help with CloudKit sharing implementation ⚠️
