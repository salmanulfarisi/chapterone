# Ad Integration Setup Guide

## Overview
A comprehensive ad monetization system has been integrated into ChapterOne using Google Mobile Ads. This is your main revenue source, so it's been implemented with best practices for maximum revenue potential.

## What's Been Implemented

### 1. Ad Types Integrated
- **Banner Ads**: Displayed at the bottom of Home and Manga Detail screens
- **Interstitial Ads**: Shown between chapters in the Reader (every 3 chapters)
- **Native Ads**: Integrated into the Home screen feed
- **Rewarded Ads**: Available for premium features (ready to use)

### 2. Files Created/Modified

#### New Files:
- `lib/core/constants/ad_constants.dart` - Ad configuration constants
- `lib/services/ads/ad_service.dart` - Ad service managing all ad types
- `lib/widgets/ads/banner_ad_widget.dart` - Reusable banner ad widget
- `lib/widgets/ads/native_ad_widget.dart` - Reusable native ad widget

#### Modified Files:
- `pubspec.yaml` - Added `google_mobile_ads: ^5.1.0`
- `lib/main.dart` - Ad service initialization
- `lib/features/home/home_screen.dart` - Banner and native ads
- `lib/features/manga/manga_detail_screen.dart` - Banner ad
- `lib/features/reader/reader_screen.dart` - Interstitial ads
- `android/app/src/main/AndroidManifest.xml` - AdMob App ID configuration

## Configuration Steps

### Step 1: Get Your AdMob Account
1. Go to [Google AdMob](https://admob.google.com/)
2. Create an account or sign in
3. Add your app to AdMob

### Step 2: Get Your Ad Unit IDs
1. In AdMob dashboard, go to Apps → Your App
2. Create ad units for:
   - **Banner Ad** (for home and detail screens)
   - **Interstitial Ad** (for reader)
   - **Native Ad** (for home feed)
   - **Rewarded Ad** (for premium features)

### Step 3: Update Ad Constants
Edit `lib/core/constants/ad_constants.dart`:

```dart
// Replace test IDs with your production Ad Unit IDs
static const String bannerAdUnitId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
static const String interstitialAdUnitId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
static const String rewardedAdUnitId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
static const String nativeAdUnitId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';

// Set to false when ready for production
static const bool isTestMode = false;
```

### Step 4: Update Android Manifest
Edit `android/app/src/main/AndroidManifest.xml`:

Replace the test App ID with your actual AdMob App ID:
```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX"/>
```

### Step 5: Install Dependencies
Run:
```bash
flutter pub get
```

## Ad Placement Strategy

### Banner Ads
- **Home Screen**: Fixed at bottom (always visible)
- **Manga Detail Screen**: Fixed at bottom (always visible)
- **Revenue Impact**: High - constant visibility

### Interstitial Ads
- **Reader Screen**: Shown every 3 chapters when navigating to next chapter
- **Revenue Impact**: Very High - full-screen engagement
- **User Experience**: Non-intrusive timing (between chapters)

### Native Ads
- **Home Screen**: Integrated into feed after Popular section
- **Revenue Impact**: High - seamless integration
- **User Experience**: Looks like content, high engagement

### Rewarded Ads
- **Ready to use**: Can be triggered for premium features
- **Use cases**: Remove ads, unlock premium content, etc.

## Ad Service Features

### Automatic Ad Loading
- Ads are pre-loaded for instant display
- Automatic retry on failure (up to 3 attempts)
- Smart caching to minimize load times

### Error Handling
- Graceful degradation if ads fail to load
- No app crashes from ad errors
- Automatic retry with exponential backoff

### Performance Optimized
- Ads load in background
- No blocking of UI
- Efficient memory management

## Testing

### Test Mode
Currently set to test mode using Google's test ad unit IDs. This allows you to:
- Test ad placement and appearance
- Verify ad integration without real ads
- Ensure no violations before going live

### Production Mode
1. Set `isTestMode = false` in `ad_constants.dart`
2. Replace all test Ad Unit IDs with production IDs
3. Update Android Manifest with production App ID
4. Test thoroughly before release

## Revenue Optimization Tips

1. **Ad Frequency**: Interstitial ads show every 3 chapters (configurable in `ad_constants.dart`)
2. **Placement**: Banner ads are always visible for maximum impressions
3. **Native Ads**: Seamlessly integrated for better user engagement
4. **Timing**: Interstitial ads only show between chapters (not during reading)

## Monitoring

After going live, monitor in AdMob dashboard:
- Impressions
- Click-through rate (CTR)
- Revenue per user
- Ad fill rate

## Troubleshooting

### Ads Not Showing
1. Check if `isTestMode` is set correctly
2. Verify Ad Unit IDs are correct
3. Check Android Manifest has correct App ID
4. Ensure internet connection
5. Check AdMob account status

### Build Errors
1. Run `flutter clean`
2. Run `flutter pub get`
3. Rebuild the app

## Next Steps

1. ✅ Ad integration complete
2. ⏳ Get AdMob account and Ad Unit IDs
3. ⏳ Update configuration files
4. ⏳ Test with test ads
5. ⏳ Switch to production mode
6. ⏳ Monitor revenue in AdMob dashboard

## Support

For AdMob-specific issues, refer to:
- [Google AdMob Documentation](https://developers.google.com/admob)
- [Flutter AdMob Plugin](https://pub.dev/packages/google_mobile_ads)

---

**Note**: Always test thoroughly before releasing to production. Ad violations can result in account suspension.

