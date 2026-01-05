# Firebase Crashlytics Setup Guide

## Overview
Firebase Crashlytics has been fully integrated into the app. This guide explains what's been set up and how it works.

## ✅ What's Been Completed

### 1. Package Installation
- ✅ `firebase_crashlytics: ^3.5.7` added to `pubspec.yaml`
- ✅ Package installed and ready to use

### 2. Service Implementation
- ✅ Complete `CrashlyticsService` implementation in `lib/services/logging/crashlytics_service.dart`
- ✅ Automatic crash reporting for Flutter framework errors
- ✅ Non-fatal error tracking
- ✅ Custom logging support
- ✅ User identification tracking
- ✅ Custom key-value pairs for context

### 3. Integration Points
- ✅ Initialized in `main.dart` during app startup
- ✅ User ID tracking in auth provider (login/logout)
- ✅ All errors automatically logged through `Logger` class

## How It Works

### Automatic Crash Reporting
The service automatically captures:
- **Flutter framework errors**: Unhandled exceptions in the UI
- **Async errors**: Errors in async operations
- **Fatal errors**: App crashes

### Manual Error Logging
You can manually log errors using:
```dart
await CrashlyticsService.instance.recordError(
  exception,
  stackTrace,
  reason: 'User-friendly error message',
  information: {'key': 'value'}, // Additional context
  fatal: false, // Set to true for fatal errors
);
```

### Custom Logging
Log custom messages:
```dart
await CrashlyticsService.instance.log('User completed chapter 5');
```

### User Identification
User IDs are automatically set when users log in and cleared when they log out. This helps identify which users are experiencing crashes.

### Custom Keys
Add context to crash reports:
```dart
await CrashlyticsService.instance.setCustomKey('app_version', '1.0.0');
await CrashlyticsService.instance.setCustomKey('user_type', 'premium');
```

## Configuration

### Test Mode vs Production
- **Debug builds**: Crashlytics collection is **disabled** (to avoid cluttering reports during development)
- **Release builds**: Crashlytics collection is **enabled** (captures real crashes)

This is automatically handled in the initialization:
```dart
await _crashlytics!.setCrashlyticsCollectionEnabled(!kDebugMode);
```

## Firebase Console Setup

### 1. Enable Crashlytics in Firebase
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to **Crashlytics** in the left menu
4. Click **Enable Crashlytics** (if not already enabled)

### 2. Verify Integration
After enabling:
1. Build a release version of your app
2. Install it on a device
3. Trigger a test crash (see Testing section below)
4. Check Firebase Console → Crashlytics for the crash report

### 3. Set Up Alerts (Optional)
1. In Firebase Console → Crashlytics
2. Go to **Settings** → **Alerts**
3. Configure email alerts for:
   - New fatal issues
   - Regression alerts
   - Velocity alerts

## Testing Crashlytics

### Test a Crash (Development Only)
Add this code temporarily to test crash reporting:

```dart
// In any screen/widget
ElevatedButton(
  onPressed: () {
    throw Exception('Test crash for Crashlytics');
  },
  child: Text('Test Crash'),
)
```

**Important**: Remove test crash code before releasing to production!

### Test Non-Fatal Error
```dart
try {
  // Some code that might fail
} catch (e, stackTrace) {
  await CrashlyticsService.instance.recordError(
    e,
    stackTrace,
    reason: 'Failed to load manga details',
    information: {'mangaId': mangaId},
  );
}
```

## Viewing Crash Reports

### In Firebase Console
1. Go to Firebase Console → Crashlytics
2. View:
   - **Issues**: List of all crashes and errors
   - **Latest release**: Crashes for the current app version
   - **Users affected**: Number of users experiencing each issue
   - **Stack traces**: Detailed error information

### Crash Report Information
Each crash report includes:
- Stack trace
- Device information (OS, model, etc.)
- App version
- User ID (if set)
- Custom keys (if set)
- Timestamp

## Best Practices

### 1. Don't Log Sensitive Information
❌ **Bad**:
```dart
await CrashlyticsService.instance.setCustomKey('password', userPassword);
```

✅ **Good**:
```dart
await CrashlyticsService.instance.setCustomKey('user_id', userId);
```

### 2. Provide Context
Always include helpful context:
```dart
await CrashlyticsService.instance.recordError(
  e,
  stackTrace,
  reason: 'Failed to unlock chapter',
  information: {
    'chapter_id': chapterId,
    'manga_id': mangaId,
    'user_premium': isPremium.toString(),
  },
);
```

### 3. Use Appropriate Severity
- **Fatal errors**: App crashes, unhandled exceptions
- **Non-fatal errors**: Recoverable errors, API failures

## Troubleshooting

### Crashes Not Appearing in Firebase?
1. **Check if Crashlytics is enabled**: Verify in Firebase Console
2. **Wait a few minutes**: Reports may take 5-10 minutes to appear
3. **Check build mode**: Only release builds send reports (debug builds are disabled)
4. **Verify Firebase setup**: Ensure `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) are properly configured
5. **Check internet connection**: Reports need internet to upload

### Too Many Debug Reports?
- Debug builds are automatically disabled
- Only release/production builds send reports
- This is configured in the initialization code

## Next Steps

1. ✅ **Enable Crashlytics in Firebase Console** (if not already done)
2. ✅ **Test crash reporting** with a test crash (remove before production!)
3. ✅ **Set up alerts** for critical crashes
4. ✅ **Monitor crash reports** after launch
5. ✅ **Fix critical issues** based on crash reports

## Support

For Firebase Crashlytics issues:
- [Firebase Crashlytics Documentation](https://firebase.google.com/docs/crashlytics)
- [FlutterFire Crashlytics Guide](https://firebase.flutter.dev/docs/crashlytics/overview)

