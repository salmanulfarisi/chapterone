# Notification Troubleshooting Guide

## Error: "No users with FCM tokens found from 0 user IDs"

This error occurs when trying to send notifications but:
1. **No users have FCM tokens saved** - Users need to log in and grant notification permissions
2. **Empty user ID array** - The notification is being sent to an empty list
3. **FCM tokens not being saved** - The token saving process is failing

## How to Fix

### 1. Verify FCM Tokens Are Being Saved

**Check if users have tokens:**
```javascript
// In MongoDB or backend console
db.users.find({ fcmToken: { $ne: null } }).count()
```

**Check a specific user:**
```javascript
db.users.findOne({ email: "user@example.com" }, { fcmToken: 1, email: 1 })
```

### 2. Ensure Users Log In and Grant Permissions

FCM tokens are only saved when:
- User logs in successfully
- NotificationService.initialize() is called
- User grants notification permissions
- FCM token is received and saved to backend

**Check Flutter app logs for:**
```
Initializing notifications after login...
Notification permission status: AuthorizationStatus.authorized
FCM token received: Yes (...)
FCM token saved successfully
```

### 3. Test FCM Token Saving

**From Flutter app:**
1. Log in as a user
2. Go to Settings → "Initialize Notifications"
3. Grant notification permissions
4. Check backend logs for: "FCM token updated successfully"

**Check token status via API:**
```bash
GET /api/user/fcm-token-status
Authorization: Bearer <token>
```

### 4. Test Notification Sending

**Send test notification to specific user:**
```javascript
// In backend
const notificationService = require('./services/notificationService');
const User = require('./models/User');

const user = await User.findOne({ email: 'test@example.com' });
if (user && user.fcmToken) {
  await notificationService.sendNotification(
    user._id,
    'Test Notification',
    'This is a test',
    { type: 'test' }
  );
}
```

**Send to all users with tokens:**
```javascript
const users = await User.find({ fcmToken: { $ne: null } }).select('_id').lean();
const userIds = users.map(u => u._id);

await notificationService.sendBulkNotifications(
  userIds,
  'Test',
  'Testing notifications',
  { type: 'test' }
);
```

## Common Issues

### Issue 1: Users Don't Have Tokens
**Symptom:** "No users with FCM tokens found"
**Solution:** 
- Users must log in and grant notification permissions
- Check that NotificationService.initialize() is called after login
- Verify FCM token endpoint is working: `POST /api/user/fcm-token`

### Issue 2: Empty User ID Array
**Symptom:** "No users with FCM tokens found from 0 user IDs"
**Solution:**
- Check where notifications are being triggered
- Verify user IDs are being passed correctly
- Check if users exist in database

### Issue 3: Token Not Saving
**Symptom:** Token received but not saved to database
**Solution:**
- Check backend `/user/fcm-token` endpoint logs
- Verify database connection
- Check user authentication token is valid

## Debugging Steps

1. **Check Backend Logs:**
   ```
   FCM token updated successfully for user <id>
   ```

2. **Check Database:**
   ```javascript
   // Count users with tokens
   db.users.countDocuments({ fcmToken: { $ne: null } })
   
   // List users with tokens
   db.users.find({ fcmToken: { $ne: null } }, { email: 1, fcmToken: 1 })
   ```

3. **Test Token Endpoint:**
   ```bash
   curl -X POST http://localhost:3000/api/user/fcm-token \
     -H "Authorization: Bearer <token>" \
     -H "Content-Type: application/json" \
     -d '{"token": "test-token-123"}'
   ```

4. **Check Notification Service:**
   ```javascript
   // In backend console
   const notificationService = require('./services/notificationService');
   const User = require('./models/User');
   
   // Check how many users have tokens
   const count = await User.countDocuments({ fcmToken: { $ne: null } });
   console.log(`Users with FCM tokens: ${count}`);
   ```

## Prevention

1. **Always check token status before sending:**
   ```javascript
   const users = await User.find({ fcmToken: { $ne: null } });
   if (users.length === 0) {
     console.warn('No users with FCM tokens. Skipping notification.');
     return;
   }
   ```

2. **Handle empty arrays gracefully:**
   ```javascript
   if (!userIds || userIds.length === 0) {
     return { success: false, error: 'No user IDs provided' };
   }
   ```

3. **Log token saving:**
   - Always log when tokens are saved
   - Log when tokens fail to save
   - Monitor token count regularly

## Next Steps

1. Have users log in and grant notification permissions
2. Verify tokens are being saved to database
3. Test sending a notification to a single user first
4. Then test bulk notifications

