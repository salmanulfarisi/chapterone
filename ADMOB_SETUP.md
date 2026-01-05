# AdMob Setup Guide

## Overview
This guide explains how to replace the placeholder AdMob Ad Unit IDs with your actual production IDs.

## Current Status
- ✅ AdMob integration is complete and functional
- ✅ Test ad unit IDs are configured (safe for development)
- ⚠️ **Production ad unit IDs need to be replaced** before launching to production

## Steps to Replace Ad Unit IDs

### 1. Create AdMob Account (if you haven't already)
1. Go to [Google AdMob](https://apps.admob.com/)
2. Sign in with your Google account
3. Create a new app or select your existing app

### 2. Create Ad Units
For each ad type, create an ad unit in your AdMob dashboard:

1. **Banner Ad Unit**
   - Go to: AdMob Dashboard → Apps → Your App → Ad units
   - Click "Add ad unit"
   - Select "Banner"
   - Name it (e.g., "ChapterOne Banner")
   - Copy the Ad Unit ID (format: `ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX`)

2. **Interstitial Ad Unit**
   - Repeat the process, select "Interstitial"
   - Name it (e.g., "ChapterOne Interstitial")
   - Copy the Ad Unit ID

3. **Rewarded Ad Unit**
   - Repeat the process, select "Rewarded"
   - Name it (e.g., "ChapterOne Rewarded")
   - Copy the Ad Unit ID

4. **Native Ad Unit**
   - Repeat the process, select "Native"
   - Name it (e.g., "ChapterOne Native")
   - Copy the Ad Unit ID

### 3. Update Ad Unit IDs in Code

Open `lib/core/constants/ad_constants.dart` and replace the placeholder IDs:

```dart
// Production Ad Unit IDs
static const String bannerAdUnitId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX'; // Replace with your banner ad unit ID
static const String interstitialAdUnitId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX'; // Replace with your interstitial ad unit ID
static const String rewardedAdUnitId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX'; // Replace with your rewarded ad unit ID
static const String nativeAdUnitId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX'; // Replace with your native ad unit ID
```

### 4. Test Mode Configuration

The app automatically uses test mode in debug builds and production mode in release builds:

- **Debug builds**: Uses Google's test ad unit IDs (safe for testing)
- **Release builds**: Uses your production ad unit IDs

You can manually control this by changing:
```dart
static const bool isTestMode = kDebugMode; // Automatically switches based on build mode
```

### 5. Verify Ad Unit IDs

Before launching:
- [ ] All four ad unit IDs are replaced with your actual AdMob IDs
- [ ] Test the app in release mode to ensure ads load correctly
- [ ] Verify ads are displaying properly
- [ ] Check AdMob dashboard to see if ad requests are being received

## Important Notes

⚠️ **DO NOT use test ad unit IDs in production builds!**
- Test IDs are for development only
- Using test IDs in production violates AdMob policies
- Always use your actual AdMob ad unit IDs for release builds

## Ad Display Configuration

Current ad display intervals:
- **Interstitial ads**: Every 3 chapters
- **Native ads**: Every 5 items in feed

You can adjust these in `ad_constants.dart`:
```dart
static const int interstitialAdInterval = 3; // Change this number
static const int nativeAdInterval = 5; // Change this number
```

## Troubleshooting

### Ads not showing?
1. Check if you're in test mode (debug builds use test ads)
2. Verify your AdMob account is approved
3. Check AdMob dashboard for ad request status
4. Ensure your app is linked to your AdMob account
5. Wait a few hours after creating ad units (they may take time to activate)

### Getting "No ad config" error?
- Your AdMob account may need approval
- Ad units may not be fully activated yet
- Check your AdMob dashboard for account status

## Support

For AdMob-specific issues, refer to:
- [AdMob Help Center](https://support.google.com/admob/)
- [AdMob Documentation](https://developers.google.com/admob)

