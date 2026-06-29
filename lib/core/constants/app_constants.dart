class AppConstants {
  // App Info
  static const String appName = 'Guardian Eye';
  static const String appTagline = 'Safety. Vision. Care.';
  static const String appVersion = '1.0.0';

  // API & Firebase (for future use)
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue:
        'https://ai-assistant-backend-production-c250.up.railway.app/api/v1',
  );
  static const String firebaseCollection = 'guardian_eye';

  // Local Storage Keys
  static const String userTokenKey = 'user_token';
  static const String secureTokenKey = 'secure_user_token';
  static const String secureTokenExpiryKey = 'secure_user_token_expiry';
  static const String secureRefreshAtKey = 'secure_user_token_refresh_at';
  static const String userIdKey = 'user_id';
  static const String userRoleKey = 'user_role';
  static const String isFirstLaunchKey = 'is_first_launch';
  static const String cachedUserKey = 'cached_user';

  // Location Settings
  static const int locationUpdateIntervalSeconds = 5;
  static const double locationAccuracyThreshold = 20.0; // meters
  static const int locationHistoryLimit = 100;
  static const int locationTrailLimit = 50;

  // Map Settings
  static const double defaultMapZoom = 15.0;
  static const double defaultMapTilt = 0.0;
  static const double minMapZoom = 10.0;
  static const double maxMapZoom = 20.0;

  // Default Coordinates (Cairo, Egypt)
  static const double defaultLatitude = 30.0444;
  static const double defaultLongitude = 31.2357;

  // Battery Thresholds
  static const double lowBatteryThreshold = 20.0;
  static const double criticalBatteryThreshold = 10.0;

  // Time Formats
  static const String timeFormat24 = 'HH:mm';
  static const String timeFormat12 = 'hh:mm a';
  static const String dateFormat = 'dd MMM yyyy';
  static const String dateTimeFormat = 'dd MMM yyyy, hh:mm a';

  // UI Settings
  static const double borderRadius = 12.0;
  static const double borderRadiusLarge = 16.0;
  static const double cardElevation = 2.0;
  static const double buttonHeight = 56.0;

  // Animation Durations
  static const int shortAnimationDuration = 200;
  static const int mediumAnimationDuration = 300;
  static const int longAnimationDuration = 500;
  static const int splashDuration = 2500;

  // Validation
  static const int minPasswordLength = 6;
  static const int maxPasswordLength = 50;
  static const int minNameLength = 2;
  static const int maxNameLength = 50;
  static const int pairingCodeLength = 6;

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Email (SMTP via Gmail)
  static const String smtpSenderEmail = String.fromEnvironment(
    'SMTP_EMAIL',
    defaultValue: 'omarhosssam504@gmail.com',
  );
  static const String smtpAppPassword = String.fromEnvironment(
    'SMTP_PASSWORD',
    defaultValue: 'agqq xuqf dxsg pcsu',
  );
  static const String smtpSenderName = 'Guardian Eye';

  // Mock Data (for development)
  static const String mockGuardianEmail = 'guardian@test.com';
  static const String mockImpairedEmail = 'impaired@test.com';
  static const String mockPassword = 'test123';
}
