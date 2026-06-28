import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:guardian_eye/core/constants/route_paths.dart';
import 'package:guardian_eye/features/auth/domain/entities/user.dart';
import 'package:guardian_eye/features/auth/presentation/providers/auth_providers.dart';
import 'package:guardian_eye/features/auth/presentation/screens/blind_home_screen.dart';
import 'package:guardian_eye/features/auth/presentation/screens/blind_migration_screen.dart';
import 'package:guardian_eye/features/auth/presentation/screens/login_screen.dart';
import 'package:guardian_eye/features/auth/presentation/screens/register_screen.dart';
import 'package:guardian_eye/features/auth/presentation/screens/splash_screen.dart';
import 'package:guardian_eye/features/guardian/presentation/screens/guardian_home_screen.dart';
import 'package:guardian_eye/features/guardian/presentation/screens/alerts_screen.dart';
import 'package:guardian_eye/features/guardian/presentation/screens/tracking_map_screen.dart';
import 'package:guardian_eye/features/pairing/presentation/screens/add_person_screen.dart';
import 'package:guardian_eye/features/pairing/presentation/screens/blind_pairing_screen.dart';
import 'package:guardian_eye/features/pairing/presentation/screens/pairing_code_screen.dart';
import 'package:guardian_eye/features/pairing/presentation/screens/pairing_success_screen.dart';
import 'package:guardian_eye/features/profile/presentation/screens/profile_screen.dart';
import 'package:guardian_eye/features/settings/presentation/screens/settings_screen.dart';

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen<AsyncValue<dynamic>>(
      authControllerProvider,
      (_, __) => notifyListeners(),
    );
    // Re-evaluate redirects whenever the guardian's link status changes
    // (e.g. they just linked a wearable, or signed out).
    _ref.listen<AsyncValue<dynamic>>(
      guardianLinkStateProvider,
      (_, __) => notifyListeners(),
    );
  }

  final Ref _ref;
  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authControllerProvider);
    final session = authState.valueOrNull;
    final isLoading = authState.isLoading;
    final isAuthenticated = session != null;
    final location = state.matchedLocation;
    final role = session?.user.role;

    final isSplash = location == RoutePaths.splash;
    final isAuthRoute = location == RoutePaths.login ||
        location == RoutePaths.guardianLogin ||
        location == RoutePaths.register;
    final isPublicRoute = isAuthRoute;

    // Still initializing — stay on the current public/auth route.
    if (isLoading) {
      return isPublicRoute || isSplash ? null : RoutePaths.login;
    }

    // Not logged in → push to login.
    if (!isAuthenticated) {
      return isPublicRoute ? null : RoutePaths.login;
    }

    // App is now guardian-only. Anyone signed in with a blind role is a
    // leftover from old data — push them through login.
    if (role != UserRole.guardian) {
      return RoutePaths.login;
    }

    final linkAsync = _ref.read(guardianLinkStateProvider);
    final linkState = linkAsync.valueOrNull;
    final hasLinkedUser = linkState?.isLinked ?? false;

    if (!hasLinkedUser) {
      // Zero-linked guardian: keep them on the link screen.
      if (location == RoutePaths.addPerson) return null;
      return RoutePaths.addPerson;
    }

    // Linked guardian: route splash + auth screens straight to the dashboard.
    // `addPerson` is still reachable so they can link additional wearables.
    if (isSplash || isAuthRoute) {
      return RoutePaths.guardianHome;
    }
    return null;
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    initialLocation: RoutePaths.login,
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: RoutePaths.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: RoutePaths.login,
        builder: (_, __) => const LoginScreen(role: UserRole.guardian),
      ),
      GoRoute(
        path: RoutePaths.blindLogin,
        builder: (_, __) => const LoginScreen(role: UserRole.blind),
      ),
      GoRoute(
        path: RoutePaths.guardianLogin,
        builder: (_, __) => const LoginScreen(role: UserRole.guardian),
      ),
      GoRoute(
        path: RoutePaths.register,
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: RoutePaths.myGuardians,
        builder: (_, __) => const BlindHomeScreen(),
      ),
      GoRoute(
        path: RoutePaths.blindMigration,
        builder: (_, __) => const BlindMigrationScreen(),
      ),
      GoRoute(
        path: RoutePaths.pairingCode,
        builder: (_, __) => const PairingCodeScreen(),
      ),
      GoRoute(
        path: RoutePaths.blindPairing,
        builder: (_, __) => const BlindPairingScreen(),
      ),
      GoRoute(
        path: RoutePaths.pairingSuccess,
        builder: (_, __) => const PairingSuccessScreen(),
      ),
      GoRoute(
        path: RoutePaths.addPerson,
        builder: (_, __) => const AddPersonScreen(),
      ),
      GoRoute(
        path: RoutePaths.guardianHome,
        builder: (_, __) => const GuardianHomeScreen(),
      ),
      GoRoute(
        path: RoutePaths.guardianMap,
        builder: (_, state) => TrackingMapScreen(
          userId: state.uri.queryParameters['userId'],
        ),
      ),
      GoRoute(
        path: RoutePaths.alerts,
        builder: (_, __) => const AlertsScreen(),
      ),
      GoRoute(
        path: RoutePaths.profile,
        builder: (_, __) => const ProfileScreen(),
      ),
      GoRoute(
        path: RoutePaths.settings,
        builder: (_, __) => const SettingsScreen(),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.uri}')),
    ),
  );
});
