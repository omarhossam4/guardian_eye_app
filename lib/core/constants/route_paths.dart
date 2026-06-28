class RoutePaths {
  // Auth Routes
  static const String splash = '/';
  static const String login = '/login';
  static const String blindLogin = '/login/blind';
  static const String guardianLogin = '/login/guardian';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';

  // Pairing Routes
  static const String blindPairing = '/pairing/blind';
  static const String pairingCode = '/pairing/code';
  static const String pairingSuccess = '/pairing/success';
  static const String addPerson = '/pairing/add-person';

  // Guardian Routes
  static const String guardianHome = '/guardian/home';
  static const String guardianMap = '/guardian/map';
  static const String locationHistory = '/guardian/history';
  static const String alerts = '/guardian/alerts';

  // Impaired User Routes
  static const String impairedHome = '/impaired/home';
  static const String myGuardians = '/impaired/guardians';
  static const String blindMigration = '/migration/blind-auth';

  // Common Routes
  static const String profile = '/profile';
  static const String editProfile = '/profile/edit';
  static const String settings = '/settings';
  static const String safeZones = '/settings/safe-zones';
  static const String notifications = '/settings/notifications';
  static const String about = '/settings/about';
}
