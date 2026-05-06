# Support

**Spichr — Pantry & Food Inventory**

---

If you're experiencing an issue or have a question, this page covers the most common topics. For anything not addressed here, email [sekidev@icloud.com](mailto:sekidev@icloud.com) and I'll get back to you as soon as possible.

---

## Frequently Asked Questions

### General

**Is Spichr free?**  
Spichr offers a free tier with core features. Some advanced features may require a one-time purchase or optional upgrade, available through the App Store.

**Does Spichr require an account?**  
No. Spichr works entirely without an account. iCloud sync is optional and uses your existing Apple ID — no separate account is required.

**Which devices are supported?**  
Spichr requires iPhone running iOS 17.0 or later.

**Is my data backed up?**  
If you enable iCloud sync, your data is automatically backed up through Apple's CloudKit. You can also create a manual backup at any time using the JSON Export feature in Settings.

---

## Sync Issues

**iCloud sync isn't working**

1. Open **Settings** on your iPhone → tap your name at the top → tap **iCloud** → confirm that iCloud Drive is enabled.
2. Open **Settings → [Your Name] → iCloud** and check that Spichr is listed and toggled on.
3. Ensure your device has an active internet connection.
4. In the Spichr app, go to **Settings → Sync** and tap **Sync Now** if available.
5. If the issue persists, try signing out of iCloud on your device and signing back in.

**Data isn't appearing on a second device**

- Both devices must be signed in to the same Apple ID.
- Allow a few minutes for initial sync — CloudKit sync is not always instantaneous.
- Ensure both devices have an active internet connection at the time of sync.

**Sync shows an error message**

- This is typically a temporary iCloud service issue. Check [Apple's System Status page](https://www.apple.com/support/systemstatus/) to confirm CloudKit is operational.
- Wait a few minutes and try again.

---

## Notification Issues

**I'm not receiving expiry notifications**

1. Go to **Settings → Notifications → Spichr** and confirm notifications are enabled.
2. Check that **Do Not Disturb** or **Focus** modes are not blocking Spichr notifications.
3. In the Spichr app, open **Settings → Notifications** and verify your notification preferences.
4. Confirm that items have expiry dates set — notifications are only triggered for items with valid dates.

**I'm receiving too many notifications**

Go to **Settings → Notifications** inside the app to adjust how far in advance you receive reminders, or disable notifications for specific categories.

---

## Widget Issues

**The Home Screen widget isn't showing**

1. Remove the widget and re-add it from the widget gallery.
2. Open Spichr at least once to allow the widget to refresh its data.
3. If the widget shows stale data, tap it to open the app and allow a full refresh.

**The widget shows "No data"**

- This typically means the widget has not yet synced with the app's data. Open the app once and return to the Home Screen.
- If using iCloud sync, ensure the app has had an opportunity to sync before checking the widget.

---

## Backup & Restore

**How do I export my data?**

Open **Settings → Export Data** in the app to generate a JSON file containing all your pantry data. You can save this to Files, send via AirDrop, or store it elsewhere.

**How do I restore from a JSON backup?**

Open **Settings → Import Data** and select your previously exported JSON file. The import will merge with or replace your existing data, depending on the option you select.

**I accidentally deleted an item**

Check the **Activity Log** (accessible from the main menu) — recently deleted items may still be visible there depending on your log retention settings.

---

## Data & Privacy

**How do I delete all my data?**

Deleting the app from your device removes all locally stored data. If iCloud sync is enabled, go to **Settings → [Your Name] → iCloud → Manage Account Storage**, find Spichr, and delete its iCloud data.

**Can the developer see my data?**

No. Your data is stored on your device or in your personal iCloud container. CloudKit private databases are not accessible to the developer.

→ [Read the full Privacy Policy](PRIVACY.md)

---

## Feature Requests

Feature requests are genuinely welcomed. If there's something you'd like to see in a future update — a workflow improvement, a missing feature, or an integration idea — please send it to [sekidev@icloud.com](mailto:sekidev@icloud.com) with the subject line **Feature Request: Spichr**.

You can also leave feedback through the App Store review system. Reviews are read carefully.

---

## Reporting a Bug

If you encounter unexpected behavior, please include the following when reaching out:

- Your iOS version (Settings → General → About)
- The Spichr version (visible in Settings → About)
- A clear description of what happened and what you expected
- Steps to reproduce the issue, if possible
- Screenshots or screen recordings if they help illustrate the problem

Send bug reports to [sekidev@icloud.com](mailto:sekidev@icloud.com) with the subject line **Bug Report: Spichr**.

---

## Contact

**Email:** [sekidev@icloud.com](mailto:sekidev@icloud.com)  
**Developer:** Sebastian Kerski  
**GitHub:** [github.com/Sebastian-Kerski](https://github.com/Sebastian-Kerski)

Response time is typically within 2–3 business days.

---

*Last updated: May 2026*
