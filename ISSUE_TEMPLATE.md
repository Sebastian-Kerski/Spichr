# CloudKit Sharing: "Object not available" despite correct permissions

## Problem Summary

CloudKit sharing fails with "Object not available" error when recipient accepts share invitation, despite:
- ✅ Share created successfully
- ✅ `share.publicPermission = .readWrite` set
- ✅ Share URL generated
- ✅ Both users logged into iCloud
- ✅ Container identifier matches Entitlements

## Environment

- **Xcode:** 15.0+
- **iOS:** 17.0+
- **Device:** Two physical iPhones (Simulator doesn't support CloudKit sharing)
- **Apple IDs:** Two different accounts
- **Container:** `iCloud.com.de.SkerskiDev.FoodGuard`

## Reproduction Steps

### Device 1 (Owner - owner@example.com)

1. Open Spichr app
2. Navigate to: Settings → Haushalt verwalten
3. Tap "Haushalt teilen"
4. Send share URL via iMessage to Device 2
5. **Result:** ✅ Share URL created: `https://www.icloud.com/share/...`

### Device 2 (Participant - test@example.com)

1. Open iMessage
2. Tap share link
3. iOS shows share dialog: "Spichr Household öffnen?"
4. Tap "Öffnen" (Open)
5. **Result:** ❌ Error: "Objekt nicht verfügbar" (Object not available)

## Console Logs

### Device 1 (Owner) - Complete Log

```
✅ CloudKit Sharing configured for container: iCloud.com.de.SkerskiDev.FoodGuard
🔵 Starting CoreData CloudKit Sharing...
📦 Found 15 items to share
🔵 Sharing 15 items using CoreData CloudKit...
✅ Initial share created
✅ Share fetched from CloudKit
✅ Share configured with READ/WRITE permissions
✅ Share SAVED to CloudKit with READ/WRITE permissions
✅ Share URL: https://www.icloud.com/share/0f6F82kJUuU-h1Sq1TiocYpQg#Spichr_Household
🔵 Adding 14 more items to share...

[Multiple oplock errors follow:]
CoreData+CloudKit: Export failed with error:
<CKError: "Partial Failure" (2/1011); 
"Failed to modify some records"; 
partial errors: {
    cloudkit.zoneshare = <CKError: "Server Record Changed" (14/2004); 
    server message = "client oplock error updating record"; 
    clientEtag = 1g; serverEtag = 1h>
}>

✅ All items added to share
✅ Share created successfully!
```

### Device 2 (Participant) - Complete Log

```
[No relevant logs - app launches normally but share acceptance is silent]
```

## Code Implementation

### PersistenceController.swift (lines 270-370)

```swift
@MainActor
func shareItems(_ items: [FoodItem]) async throws -> (CKShare, CKContainer) {
    logger.info("🔵 Sharing \(items.count) items using CoreData CloudKit...")
    
    guard !items.isEmpty else {
        throw NSError(domain: "Spichr", code: -1, 
                     userInfo: [NSLocalizedDescriptionKey: "No items to share"])
    }
    
    let ckContainer = CKContainer(identifier: "iCloud.com.de.SkerskiDev.FoodGuard")
    let rootItem = items[0]
    
    // Step 1: Create share with first item
    let (initialShare, _): (CKShare, CKContainer) = try await withCheckedThrowingContinuation { continuation in
        container.share([rootItem], to: nil) { objectIDs, share, ckContainer, error in
            if let error = error {
                self.logger.error("❌ Share creation failed: \(error.localizedDescription)")
                continuation.resume(throwing: error)
                return
            }
            
            guard let share = share, let ckContainer = ckContainer else {
                let error = NSError(domain: "Spichr", code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: "Share or container is nil"])
                continuation.resume(throwing: error)
                return
            }
            
            continuation.resume(returning: (share, ckContainer))
        }
    }
    
    logger.info("✅ Initial share created")
    
    // Step 2: Fetch the share from CloudKit to get latest version
    let database = ckContainer.privateCloudDatabase
    let share = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKShare, Error>) in
        database.fetch(withRecordID: initialShare.recordID) { record, error in
            if let error = error {
                self.logger.error("❌ Failed to fetch share: \(error.localizedDescription)")
                continuation.resume(throwing: error)
                return
            }
            
            guard let fetchedShare = record as? CKShare else {
                let error = NSError(domain: "Spichr", code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: "Fetched record is not a CKShare"])
                continuation.resume(throwing: error)
                return
            }
            
            continuation.resume(returning: fetchedShare)
        }
    }
    
    logger.info("✅ Share fetched from CloudKit")
    
    // Step 3: Configure share permissions
    share.publicPermission = .readWrite
    share[CKShare.SystemFieldKey.title] = "Spichr Household"
    
    if #available(iOS 15.0, *) {
        share[CKShare.SystemFieldKey.shareType] = "com.de.SkerskiDev.FoodGuard.household"
    }
    
    logger.info("✅ Share configured with READ/WRITE permissions")
    
    // Step 4: Save the updated share back to CloudKit
    let savedShare = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKShare, Error>) in
        database.save(share) { savedRecord, error in
            if let error = error {
                self.logger.error("❌ Failed to save share: \(error.localizedDescription)")
                continuation.resume(throwing: error)
                return
            }
            
            guard let savedRecord = savedRecord as? CKShare else {
                let error = NSError(domain: "Spichr", code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: "Saved record is not a CKShare"])
                continuation.resume(throwing: error)
                return
            }
            
            continuation.resume(returning: savedRecord)
        }
    }
    
    logger.info("✅ Share SAVED to CloudKit with READ/WRITE permissions")
    logger.info("✅ Share URL: \(savedShare.url?.absoluteString ?? "no URL")")
    
    // Step 5: Add remaining items to the share (if more than 1)
    if items.count > 1 {
        logger.info("🔵 Adding \(items.count - 1) more items to share...")
        
        for item in items.dropFirst() {
            do {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    container.share([item], to: savedShare) { objectIDs, updatedShare, ckContainer, error in
                        if let error = error {
                            self.logger.error("❌ Failed to add item to share: \(error.localizedDescription)")
                            continuation.resume(throwing: error)
                            return
                        }
                        continuation.resume()
                    }
                }
            } catch {
                logger.error("❌ Failed to add item '\(item.name ?? "unknown")' to share: \(error.localizedDescription)")
                // Continue with other items
            }
        }
        
        logger.info("✅ All items added to share")
    }
    
    return (savedShare, ckContainer)
}
```

### Data Model Structure

```
FoodItem (NSManagedObject)
├── id: UUID
├── name: String
├── expirationDate: Date?
├── isInStock: Bool
└── [15 independent entities, no parent-child relationships]
```

**Note:** This is a flat structure with no hierarchical relationships between items.

## What I've Tried

### 1. Container Identifier Mismatch (Fixed ✅)

**Problem:** Entitlements had `iCloud.com.SeKiDev.FoodSaver` but code used `iCloud.com.de.SkerskiDev.FoodGuard`

**Solution:** Updated Entitlements to match code

**Result:** Share creation now works, but acceptance still fails

### 2. Missing `publicPermission` (Fixed ✅)

**Problem:** Share created without explicit permissions

**Solution:** Added `share.publicPermission = .readWrite`

**Result:** Permission shows in logs, but doesn't fix acceptance error

### 3. Oplock Error (Partially Fixed ✅)

**Problem:** "client oplock error" when saving share

**Solution:** Fetch share from CloudKit after creation, then modify and save

**Result:** Initial share saves successfully, but adding items causes oplock errors

### 4. URL Handler (Added ✅)

**Problem:** Share URL might not be handled by app

**Solution:** Added `onOpenURL` handler in SwiftUI

**Result:** Handler never gets called (iOS handles share dialog itself)

### 5. Nuclear Reset (Tried ✅)

**Problem:** Old shares might be cached

**Solution:** Deleted all CloudKit data, UserDefaults, restarted devices

**Result:** Same error persists

## Specific Questions

### Q1: Is this the right approach for flat data?

My `FoodItem` entities have no parent-child relationships. Should I:
- **A)** Create a "Household" entity as parent for all items?
- **B)** Use CKShare directly instead of NSPersistentCloudKitContainer?
- **C)** Share items differently (e.g., share a custom zone)?

### Q2: Why do I get oplock errors when adding items?

```swift
for item in items.dropFirst() {
    container.share([item], to: savedShare) { ... }
}
```

**Error:** "client oplock error updating record; clientEtag = 1g; serverEtag = 1h"

Is there a race condition with CoreData's automatic CloudKit sync?

### Q3: How should share acceptance work?

Currently:
1. User taps share link
2. iOS shows system dialog
3. User taps "Open"
4. Nothing happens (no logs, no error)

Should I:
- Call `CKAcceptSharesOperation` manually?
- Configure something in Info.plist?
- Handle the URL differently?

### Q4: Do I need participant management?

Should I explicitly add participants using:
```swift
let participant = CKShare.Participant()
participant.permission = .readWrite
share.addParticipant(participant)
```

Or does `publicPermission = .readWrite` handle this automatically?

## What Would Help

- ✅ Code review of my sharing implementation
- ✅ Confirmation if this approach works for flat data structures
- ✅ Working example of NSPersistentCloudKitContainer sharing
- ✅ Explanation of the oplock error pattern
- ✅ Alternative approach recommendation

## Additional Context

- **App is published:** Available on App Store, sharing is the only broken feature
- **Days of debugging:** Tried everything I could find in Apple docs and WWDC videos
- **Desperate:** This is blocking a major feature for users 😅

## Files to Review

Key implementation files:
1. `Spichr/Persistence/PersistenceController.swift` (CloudKit setup & sharing)
2. `Spichr/Services/HouseholdManager.swift` (Share coordination)
3. `Spichr/Spichr.entitlements` (Capabilities)
4. `Spichr/SpichrApp.swift` (URL handling)

---

**Thank you for any help!** 🙏 This has been incredibly frustrating and I'm at my wit's end.
