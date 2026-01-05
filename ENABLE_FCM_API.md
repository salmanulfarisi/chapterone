# Enable Firebase Cloud Messaging (FCM) API

## Problem

You're seeing this error:
```
Error 404: The requested URL /batch was not found on this server
```

This means the **Firebase Cloud Messaging API is not enabled** for your project.

## Quick Fix (2 minutes)

### Option 1: Via Google Cloud Console (Recommended)

1. Go to: https://console.cloud.google.com/apis/library/fcm.googleapis.com
2. **Select your project**: `chapterone-ca208`
3. Click **"Enable"** button
4. Wait for it to enable (usually takes 10-30 seconds)
5. Restart your backend server

### Option 2: Via Firebase Console

1. Go to: https://console.firebase.google.com/
2. Select project: **chapterone-ca208**
3. Click the gear icon ⚙️ → **Project Settings**
4. Go to **Cloud Messaging** tab
5. If you see "Enable Cloud Messaging API", click it
6. Or go to: https://console.cloud.google.com/apis/library/fcm.googleapis.com?project=chapterone-ca208

### Option 3: Via Command Line (if you have gcloud CLI)

```bash
gcloud services enable fcm.googleapis.com --project=chapterone-ca208
```

## Verify It's Enabled

1. Go to: https://console.cloud.google.com/apis/library?project=chapterone-ca208
2. Search for "Firebase Cloud Messaging API"
3. It should show **"API enabled"** with a green checkmark ✅

## After Enabling

1. **Restart your backend server**:
   ```bash
   # Stop server (Ctrl+C)
   npm run dev
   ```

2. **Test sending a notification**:
   - Log in to app
   - Go to Admin panel
   - Send test notification
   - Should work now! ✅

## Why This Happens

The Firebase Cloud Messaging API needs to be explicitly enabled for your project. Even though you have:
- ✅ Firebase project created
- ✅ Service account configured
- ✅ FCM tokens saved

The API itself needs to be enabled to use the `/batch` endpoint for sending notifications.

## Fallback Behavior

The code now has a **fallback mechanism**:
- If batch API fails (404), it will send notifications **one by one**
- This is slower but will still work
- Once you enable the API, it will use the faster batch method

## Still Having Issues?

1. **Check API is enabled**: https://console.cloud.google.com/apis/library/fcm.googleapis.com?project=chapterone-ca208
2. **Check service account permissions**: Should have "Firebase Cloud Messaging API Admin" role
3. **Wait a few minutes**: API enablement can take 1-2 minutes to propagate
4. **Check project ID matches**: Service account should be for `chapterone-ca208`

## Related APIs (Optional but Recommended)

While you're at it, you might want to enable:
- **Firebase Cloud Messaging API** ✅ (Required)
- **Firebase Installations API** (Auto-enabled with FCM)
- **Firebase Remote Config API** (If using Remote Config)

All can be enabled from: https://console.cloud.google.com/apis/library?project=chapterone-ca208

