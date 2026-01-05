# Notification Setup Guide

This guide explains how to set up push notifications using Firebase Messaging, Flutter Local Notifications, and Firebase Functions.

## Architecture

1. **Flutter App**: Uses `firebase_messaging` and `flutter_local_notifications` to receive and display notifications
2. **Backend**: Calls Firebase Functions to send notifications
3. **Firebase Functions**: Handles the actual FCM message sending

## Setup Steps

### 1. Firebase Functions Setup

1. Install Firebase CLI:
   ```bash
   npm install -g firebase-tools
   ```

2. Login to Firebase:
   ```bash
   firebase login
   ```

3. Initialize Firebase Functions (if not already done):
   ```bash
   cd functions
   npm install
   ```

4. Deploy Firebase Functions:
   ```bash
   firebase deploy --only functions
   ```

5. After deployment, note the function URLs. They will be in the format:
   ```
   https://<region>-<project-id>.cloudfunctions.net/<function-name>
   ```

### 2. Backend Configuration

1. Add to your `.env` file:
   ```env
   FIREBASE_FUNCTIONS_URL=https://us-central1-chapterone-ca208.cloudfunctions.net
   FIREBASE_FUNCTIONS_API_KEY=your-api-key-here
   ```

   **Note**: The API key is optional if your functions don't require authentication. You can remove the API key check from `backend/services/firebaseFunctions.js` if not needed.

2. Install axios (if not already installed):
   ```bash
   cd backend
   npm install axios
   ```

### 3. Flutter App Setup

1. Dependencies are already added to `pubspec.yaml`:
   - `firebase_messaging: ^14.7.9`
   - `flutter_local_notifications: ^17.2.3`

2. Android permissions are already configured in `AndroidManifest.xml`

3. The notification service is initialized automatically after login/registration

### 4. Testing

1. **Test FCM Token Registration**:
   - Login to the app
   - Check backend logs for "FCM token received" message
   - Verify token is saved in database

2. **Test Notifications**:
   - Import a new chapter for a manga you've bookmarked
   - Check backend logs for notification sending
   - Check Firebase Functions logs for any errors

3. **Test Firebase Functions Locally** (optional):
   ```bash
   cd functions
   npm run serve
   ```

## Firebase Functions Available

1. **sendNotification**: Send notification to a single user
2. **sendBulkNotifications**: Send notifications to multiple users
3. **notifyNewChapter**: Send notification for new chapter (used by scraper)
4. **notifyNewManga**: Send notification for new manga (used by scraper)

## Troubleshooting

### Notifications not received

1. **Check FCM Token**:
   - Verify token is saved in database
   - Check token is not expired

2. **Check Firebase Functions**:
   - Verify functions are deployed
   - Check Firebase Functions logs for errors
   - Verify function URLs are correct in `.env`

3. **Check Backend Logs**:
   - Look for "Firebase Functions not configured" warnings
   - Check for API errors when calling functions

4. **Check Flutter App**:
   - Verify notification permissions are granted
   - Check app logs for notification service initialization
   - Verify Firebase is initialized correctly

### Firebase Functions 404 Error

- Verify the function URL is correct
- Check that functions are deployed
- Ensure the function name matches exactly

### Android Build Errors

- Ensure core library desugaring is enabled (already configured)
- Verify Android permissions are in `AndroidManifest.xml`
- Clean and rebuild: `flutter clean && flutter pub get`

## Notification Flow

1. User logs in → FCM token is generated and saved to backend
2. Scraper imports new chapter → Backend calls Firebase Function
3. Firebase Function sends FCM message → User receives notification
4. Flutter app receives message → Local notification is displayed (if app is in foreground)

## User Preferences

Users can control notifications via:
- `preferences.notifications.newChapters`: Notifications for new chapters
- `preferences.notifications.newManga`: Notifications for new manga
- `preferences.notifications.engagement`: Engagement notifications
- `preferences.notifications.comments`: Comment notifications

Only users with notifications enabled AND FCM tokens will receive notifications.

