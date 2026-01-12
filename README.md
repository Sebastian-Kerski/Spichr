# Spichr - CloudKit Sharing Issue 🆘

[![Help Wanted](https://img.shields.io/badge/status-help%20wanted-red)](https://github.com/Sebastian-Kerski/Spichr/issues/1)
[![Platform](https://img.shields.io/badge/platform-iOS%2017.0%2B-blue)](https://www.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange)](https://swift.org)

> **⚠️ Critical Issue:** CloudKit Sharing shows "Object not available" error when accepting share invitation, despite correct permissions configuration.

## 🐛 The Problem

I've been debugging CloudKit sharing for days and can't figure out what's wrong. The share is created successfully with `publicPermission = .readWrite`, but when the second user accepts the invitation, they get:

**German:**
> Objekt nicht verfügbar  
> Die Person, der die Datei gehört, teilt diese nicht mehr oder dein Account ist nicht berechtigt, sie zu öffnen.

**English:**
> Object not available  
> The person who owns the file is no longer sharing it, or your account is not authorized to open it.

## 📱 About Spichr

Spichr is a food inventory management app published on the App Store:
- 🍎 [App Store Link](https://apps.apple.com/de/app/spichr/id6749096170)
- Track food expiration dates
- Share inventory with family members (trying to implement this!)
- Built with SwiftUI, Core Data, and CloudKit

## 🔍 What I've Tried

### ✅ Things that work:
- Share creation succeeds
- Share URL is generated
- Share has `publicPermission = .readWrite`
- Container identifier is correct
- Both users are logged into iCloud
- Nuclear reset CloudKit data on both devices

### ❌ What doesn't work:
- Second user gets "Object not available" error
- No items appear on the second device
- Share acceptance fails silently

### 🔧 Fixes attempted:
1. Set `share.publicPermission = .readWrite` ✅
2. Fixed container identifier mismatch (Entitlements vs Code) ✅
3. Fetch share from CloudKit before saving (fix oplock error) ✅
4. Add URL handler for share acceptance ✅
5. Try to add all items to share individually ❌ (oplock errors)

## 📊 Console Logs

### Device 1 (Owner) - Share Creation:
```
✅ Share SAVED to CloudKit with READ/WRITE permissions
✅ Share URL: https://www.icloud.com/share/...
🔵 Adding 14 more items to share...
❌ CoreData+CloudKit: Export failed with error:
<CKError: "Server Record Changed" (14/2004); 
server message = "client oplock error updating record"; 
clientEtag = 1g; serverEtag = 1h>
```

### Device 2 (Participant) - Share Acceptance:
```
[No logs - Share dialog appears but nothing happens after tapping "Open"]
```

## 🏗️ Architecture

```
NSPersistentCloudKitContainer
├── FoodItem entities (15 items)
├── No parent-child relationships
└── Flat structure (all items independent)
```

**This might be the problem:** NSPersistentCloudKitContainer expects hierarchical data for sharing?

## 💻 Code

### Container Configuration
```swift
let cloudKitOptions = NSPersistentCloudKitContainerOptions(
    containerIdentifier: "iCloud.com.de.SkerskiDev.FoodGuard"
)
cloudKitOptions.databaseScope = .private
description.cloudKitContainerOptions = cloudKitOptions
```

### Share Creation
```swift
// Step 1: Create share with first item
container.share([rootItem], to: nil) { objectIDs, share, ckContainer, error in
    // ...
}

// Step 2: Fetch latest version from CloudKit
database.fetch(withRecordID: initialShare.recordID) { record, error in
    // ...
}

// Step 3: Configure permissions
share.publicPermission = .readWrite
share[CKShare.SystemFieldKey.title] = "Spichr Household"

// Step 4: Save to CloudKit
database.save(share) { savedRecord, error in
    // ✅ Success!
}

// Step 5: Try to add remaining items (❌ FAILS with oplock errors)
for item in items.dropFirst() {
    container.share([item], to: savedShare) { ... }
}
```

## ❓ Questions

1. **Is NSPersistentCloudKitContainer sharing meant for flat data structures?**  
   Or do I need a parent "Household" entity?

2. **Should I use CKShare directly instead of NSPersistentCloudKitContainer?**  
   Would that give me more control?

3. **What causes the "client oplock error" when adding items to share?**  
   Is there a race condition with CoreData's automatic sync?

4. **How should share acceptance work with NSPersistentCloudKitContainer?**  
   Does it happen automatically or do I need to call something?

## 🆘 What I Need

- **Code review:** Is my implementation fundamentally wrong?
- **Architecture advice:** Should I restructure my data model?
- **Working example:** Has anyone successfully shared flat CoreData entities?
- **Alternative approach:** Should I abandon NSPersistentCloudKitContainer for sharing?

## 🚀 How to Run

```bash
git clone https://github.com/Sebastian-Kerski/Spichr.git
cd Spichr
open Spichr.xcodeproj
```

**Setup:**
1. Select your Team in Signing & Capabilities
2. Build to two physical devices with different Apple IDs
3. Device 1: Settings → Haushalt verwalten → "Haushalt teilen"
4. Device 2: Open share link in iMessage
5. ❌ Error: "Object not available"

## 📚 References

- [Apple WWDC 2021 Session 10015](https://developer.apple.com/videos/play/wwdc2021/10015/)
- [NSPersistentCloudKitContainer Docs](https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontainer)
- [CKShare.PublicPermission Docs](https://developer.apple.com/documentation/cloudkit/ckshare/publicpermission)

## 🙏 Any Help Appreciated!

I've been stuck on this for days. If you have experience with CloudKit sharing, please take a look:
- `Spichr/Persistence/PersistenceController.swift` (lines 270-370)
- `Spichr/Services/HouseholdManager.swift` (lines 68-203)

Thank you! 🙌

---

**Built with:** SwiftUI • Core Data • CloudKit  
**Status:** Published on App Store, CloudKit sharing not working  
**Contact:** [GitHub Issues](https://github.com/Sebastian-Kerski/Spichr/issues)
