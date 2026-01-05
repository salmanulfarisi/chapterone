import 'package:flutter/material.dart';

/// Localization class for the app
/// This is a placeholder - in production, use flutter_localizations with .arb files
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  // Common strings
  String get appName => 'ChapterOne';

  // Auth
  String get login => 'Login';
  String get register => 'Register';
  String get logout => 'Logout';
  String get email => 'Email';
  String get password => 'Password';

  // Home
  String get home => 'Home';
  String get search => 'Search';
  String get bookmarks => 'Bookmarks';
  String get profile => 'Profile';

  // Reader
  String get reading => 'Reading';
  String get nextChapter => 'Next Chapter';
  String get previousChapter => 'Previous Chapter';

  // Errors
  String get error => 'Error';
  String get networkError => 'Network Error';
  String get unknownError => 'An unknown error occurred';

  // Success
  String get success => 'Success';
  String get saved => 'Saved';

  // Loading
  String get loading => 'Loading...';
  String get pleaseWait => 'Please wait...';
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
