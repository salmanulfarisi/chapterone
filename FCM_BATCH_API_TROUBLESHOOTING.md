# FCM Batch API 404 Error - Troubleshooting Guide

## Problem

Even though FCM API is enabled, you're still getting:
```
Error 404: The requested URL /batch was not found on this server
```

The fallback (individual sends) works, but batch API doesn't.

## Common Causes & Solutions

### 1. API Not Fully Propagated ⏱️

**Symptom:** API shows as enabled but still getting 404

**Solution:**
- Wait 5-10 minutes after enabling the API
- Google Cloud APIs can take time to propagate globally
- Restart your backend server after waiting

**Verify:**
```bash
# Check API status
curl https://fcm.googleapis.com/v1/projects/chapterone-ca208/messages:send
```

### 2. Service Account Permissions 🔐

**Symptom:** API enabled but service account can't access it

**Solution:**
1. Go to: https://console.cloud.google.com/iam-admin/iam?project=chapterone-ca208
2. Find your service account: `firebase-adminsdk-fbsvc@chapterone-ca208.iam.gserviceaccount.com`
3. Click "Edit" (pencil icon)
4. Ensure it has one of these roles:
   - **Firebase Cloud Messaging API Admin** (recommended)
   - **Firebase Admin SDK Administrator Service Agent**
   - **Editor** (has all permissions, but less secure)

**Add Role:**
1. Click "Add Another Role"
2. Search for "Firebase Cloud Messaging API Admin"
3. Select it
4. Click "Save"

### 3. Billing Not Enabled 💳

**Symptom:** API enabled but requires billing

**Solution:**
1. Go to: https://console.cloud.google.com/billing?project=chapterone-ca208
2. Link a billing account (Google provides free tier)
3. FCM has a generous free tier (unlimited notifications)

**Note:** FCM is free for most use cases, but billing account is required for some APIs.

### 4. Project ID Mismatch 🔍

**Symptom:** Service account is for different project

**Check:**
- Service account JSON: `project_id` should be `chapterone-ca208`
- Firebase options: `projectId` should be `chapterone-ca208`
- Backend logs should show matching project IDs

**Fix:**
- Download new service account JSON for correct project
- Update `FIREBASE_SERVICE_ACCOUNT_PATH` in `.env`

### 5. API Enabled in Wrong Project 🌍

**Symptom:** Enabled API in different Google Cloud project

**Solution:**
1. Verify you're in the correct project: `chapterone-ca208`
2. Check API is enabled in: https://console.cloud.google.com/apis/library/fcm.googleapis.com?project=chapterone-ca208
3. Make sure the dropdown shows: `chapterone-ca208`

### 6. Firebase Admin SDK Version 📦

**Symptom:** Old SDK version might have issues

**Check version:**
```bash
cd backend
npm list firebase-admin
```

**Update if needed:**
```bash
npm install firebase-admin@latest
```

## Verification Steps

### Step 1: Verify API is Enabled

1. Go to: https://console.cloud.google.com/apis/library/fcm.googleapis.com?project=chapterone-ca208
2. Should show: **"API enabled"** ✅
3. If not, click "Enable"

### Step 2: Verify Service Account Permissions

1. Go to: https://console.cloud.google.com/iam-admin/iam?project=chapterone-ca208
2. Find: `firebase-adminsdk-fbsvc@chapterone-ca208.iam.gserviceaccount.com`
3. Check roles include: **Firebase Cloud Messaging API Admin**

### Step 3: Test API Access

**Using curl:**
```bash
# Get access token (requires gcloud CLI)
gcloud auth activate-service-account --key-file=firebase-service-account.json
gcloud auth print-access-token

# Test FCM API
curl -X POST https://fcm.googleapis.com/v1/projects/chapterone-ca208/messages:send \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d '{"message":{"token":"test-token","notification":{"title":"Test","body":"Test"}}}'
```

### Step 4: Check Backend Logs

When you start the backend, you should see:
```
Firebase Admin initialized successfully
Project ID: chapterone-ca208
Service Account Project: chapterone-ca208
```

If project IDs don't match, that's the issue.

## Quick Fix Checklist

- [ ] FCM API enabled: https://console.cloud.google.com/apis/library/fcm.googleapis.com?project=chapterone-ca208
- [ ] Waited 5-10 minutes after enabling
- [ ] Service account has "Firebase Cloud Messaging API Admin" role
- [ ] Billing account linked (if required)
- [ ] Project ID matches in service account and Firebase options
- [ ] Restarted backend server after changes
- [ ] Firebase Admin SDK is up to date

## Alternative: Use Individual Sends

If batch API still doesn't work, the code automatically falls back to individual sends. This:
- ✅ Works reliably
- ✅ Sends all notifications
- ⚠️  Slower (but usually fine for small batches)
- ⚠️  Uses more API calls

For most use cases, individual sends are perfectly fine unless you're sending to thousands of users at once.

## Still Not Working?

1. **Check Google Cloud Status**: https://status.cloud.google.com/
2. **Try a different service account**: Generate a new one from Firebase Console
3. **Check Firebase Console**: https://console.firebase.google.com/project/chapterone-ca208/settings/serviceaccounts/adminsdk
4. **Review error logs**: Look for specific error codes in backend logs

## Expected Behavior After Fix

Once fixed, you should see:
```
Sent 1 notifications via batch API, 0 failed
```

Instead of:
```
Batch API failed, falling back to individual sends
```

