# Firebase Admin Setup Guide

## Why Firebase Admin?

Firebase Admin SDK is required on the backend to send push notifications to users. The Flutter app can receive notifications, but the backend needs Admin credentials to send them.

## Quick Setup (5 minutes)

### Step 1: Get Service Account JSON

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **chapterone-ca208**
3. Click the gear icon ⚙️ → **Project Settings**
4. Go to **Service Accounts** tab
5. Click **Generate new private key**
6. Click **Generate key** in the dialog
7. A JSON file will download (e.g., `chapterone-ca208-firebase-adminsdk-xxxxx.json`)

### Step 2: Save the JSON File

**Option A: Save in backend folder (Recommended for local development)**

1. Move the downloaded JSON file to your `backend` folder
2. Rename it to `firebase-service-account.json` (or keep original name)
3. Add to `.gitignore`:
   ```
   backend/firebase-service-account.json
   backend/*-firebase-adminsdk-*.json
   ```

**Option B: Save outside project (More secure)**

1. Save the JSON file in a secure location (e.g., `C:\secure\firebase-service-account.json`)
2. Use absolute path in `.env`

### Step 3: Configure Environment Variable

1. Open `backend/.env` file
2. Add one of these options:

**Option 1: File Path (Recommended)**
```env
FIREBASE_SERVICE_ACCOUNT_PATH=./firebase-service-account.json
```

**Option 2: Absolute Path**
```env
FIREBASE_SERVICE_ACCOUNT_PATH=C:\secure\firebase-service-account.json
```

**Option 3: JSON String (For production/containers)**
```env
FIREBASE_SERVICE_ACCOUNT='{"type":"service_account","project_id":"chapterone-ca208",...}'
```

### Step 4: Restart Backend Server

```bash
# Stop the server (Ctrl+C)
# Then restart
npm run dev
```

You should see:
```
Firebase Admin initialized successfully
```

## Verify Setup

### Test 1: Check Initialization

When you start the backend, you should see:
```
Firebase Admin initialized successfully
```

If you see an error, check:
- File path is correct
- JSON file is valid
- File permissions allow reading

### Test 2: Send Test Notification

1. Log in to the app
2. Go to Settings → "Initialize Notifications"
3. Grant notification permissions
4. Go to Admin panel → Send test notification
5. You should receive the notification!

## Troubleshooting

### Error: "Failed to determine project ID"

**Cause:** Firebase Admin trying to use default credentials (only works on GCP)

**Solution:** Configure `FIREBASE_SERVICE_ACCOUNT_PATH` in `.env`

### Error: "Cannot find module" or "ENOENT"

**Cause:** File path is incorrect

**Solution:**
- Check file exists: `ls backend/firebase-service-account.json` (or `dir` on Windows)
- Use absolute path if relative path doesn't work
- Check file permissions

### Error: "Invalid credential"

**Cause:** JSON file is corrupted or invalid

**Solution:**
- Re-download service account JSON from Firebase Console
- Verify JSON is valid: `cat firebase-service-account.json | jq .` (or open in text editor)
- Make sure you downloaded the correct project's service account

### Error: "Permission denied"

**Cause:** Service account doesn't have required permissions

**Solution:**
- Service account should have "Firebase Cloud Messaging API Admin" role
- This is usually set automatically when you generate the key
- If not, go to Firebase Console → IAM & Admin → Service Accounts → Edit permissions

## Security Best Practices

1. **Never commit service account JSON to Git**
   - Add to `.gitignore`:
     ```
     backend/firebase-service-account.json
     backend/*-firebase-adminsdk-*.json
     ```

2. **Use environment variables in production**
   - Don't store JSON files on production servers
   - Use `FIREBASE_SERVICE_ACCOUNT` (JSON string) instead
   - Store in secure secret management (AWS Secrets Manager, etc.)

3. **Rotate keys regularly**
   - Generate new keys every 90 days
   - Delete old keys from Firebase Console

4. **Limit service account permissions**
   - Only grant necessary permissions
   - Use principle of least privilege

## File Structure

After setup, your backend folder should look like:
```
backend/
├── .env                    (contains FIREBASE_SERVICE_ACCOUNT_PATH)
├── firebase-service-account.json  (service account JSON - NOT in git)
├── services/
│   └── notificationService.js
└── ...
```

## Next Steps

Once Firebase Admin is configured:
1. ✅ Users can save FCM tokens (already working)
2. ✅ Backend can send notifications (now working)
3. ✅ Test notifications work
4. ✅ New chapter notifications work automatically

## Need Help?

If you're still having issues:
1. Check backend logs for detailed error messages
2. Verify JSON file is valid
3. Test with a simple notification first
4. Check Firebase Console → Project Settings → Service Accounts

