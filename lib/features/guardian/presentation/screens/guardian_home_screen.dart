import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:guardian_eye/core/constants/route_paths.dart';
import 'package:guardian_eye/core/errors/app_exception.dart';
import 'package:guardian_eye/core/theme/app_colors.dart';
import 'package:guardian_eye/core/theme/app_text_styles.dart';
import 'package:guardian_eye/features/guardian/data/models/alert_model.dart';
import 'package:guardian_eye/features/guardian/data/models/guardian_notification_model.dart';
import 'package:guardian_eye/features/auth/presentation/providers/auth_providers.dart';
import 'package:guardian_eye/features/guardian/data/models/monitored_user_model.dart';
import 'package:guardian_eye/features/guardian/presentation/providers/guardian_providers.dart';
import 'package:guardian_eye/shared/widgets/primary_button.dart';
import 'package:guardian_eye/core/providers/theme_provider.dart';

class GuardianHomeScreen extends ConsumerStatefulWidget {
  const GuardianHomeScreen({super.key});

  @override
  ConsumerState<GuardianHomeScreen> createState() => _GuardianHomeScreenState();
}

class _GuardianHomeScreenState extends ConsumerState<GuardianHomeScreen> {
  final int _currentIndex = 0;
  final Set<String> _lowBatteryWarningsShown = {};
  final Set<String> _seenAlertIds = {};
  Timer? _alertPollTimer;
  Timer? _batteryPollTimer;
  bool _initialAlertLoadDone = false;

  /// Battery levels keyed by user uniqueId, fetched independently.
  final Map<String, int?> _batteryLevels = {};

  @override
  void dispose() {
    _alertPollTimer?.cancel();
    _batteryPollTimer?.cancel();
    super.dispose();
  }

  void _showDiagnosticSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(guardianDashboardProvider, (previous, next) {
      next.whenOrNull(
        error: (error, _) {
          final message = error.toString();
          debugPrint('[DASHBOARD] error -> $message');
          if (context.mounted) {
            _showDiagnosticSnackBar(message);
          }
        },
        data: (data) {
          debugPrint(
            '[DASHBOARD] loaded profile=${data.profile?.id ?? 'none'} '
            'monitoredUsers=${data.monitoredUsers.length}',
          );
          _startBatteryPolling(data.monitoredUsers);
          _startAlertPolling(data.monitoredUsers);
        },
      );
    });

    final session = ref.watch(authControllerProvider).valueOrNull;
    final dashboard = ref.watch(guardianDashboardProvider);
    final userName = session?.user.name.split(' ').first ?? 'Guardian';

    // Watch Theme so this screen rebuilds on Dark Mode toggle
    ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: dashboard.when(
        loading: () => const Center(child: CircularProgressIndicator.adaptive()),
        error: (e, _) => _ErrorState(
          error: e.toString(),
          onRetry: () => ref.read(guardianDashboardProvider.notifier).reload(),
        ),
        data: (data) => Stack(
          children: [
            // Ambient background accent
            Positioned(
              top: -120,
              right: -60,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            RefreshIndicator(
              onRefresh: () async {
                await ref.read(guardianDashboardProvider.notifier).refreshSilently();
                if (!mounted) return;
                final currentData = ref.read(guardianDashboardProvider).valueOrNull;
                if (currentData != null) {
                  await _fetchBatteryLevels(currentData.monitoredUsers);
                  if (mounted) {
                    await _checkForNewAlerts(currentData.monitoredUsers);
                  }
                }
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  _HomeAppBar(
                    userName: userName,
                    onNotificationsTap: () =>
                        _showNotificationsSheet(data.monitoredUsers),
                    onProfileTap: () => context.go(RoutePaths.profile),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (data.profile == null)
                            _CreateProfileBanner(
                              onTap: () => _showCreateProfileDialog(
                                defaultName: session?.user.name,
                                defaultEmail: session?.user.email,
                                defaultPhone: session?.user.phoneNumber,
                              ),
                            ).animate().fadeIn().slideY(begin: 0.08),

                          const SizedBox(height: 20),

                          // Stat cards
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  label: 'Linked Users',
                                  value: '${data.monitoredUsers.length}',
                                  icon: Icons.people_outline_rounded,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: _StatCard(
                                  label: 'Security',
                                  value: 'Optimal',
                                  icon: Icons.shield_rounded,
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.05),

                          const SizedBox(height: 32),

                          // Section header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Monitored Users',
                                style: AppTextStyles.h2,
                              ).animate().fadeIn(delay: 160.ms),
                              _AddWearableButton(
                                onTap: () => context.go(RoutePaths.addPerson),
                              ).animate().fadeIn(delay: 160.ms),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // User list or empty state
                          if (data.monitoredUsers.isEmpty)
                            const _EmptyState().animate().fadeIn(delay: 240.ms)
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: data.monitoredUsers.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 14),
                              itemBuilder: (context, index) {
                                final user = data.monitoredUsers[index];
                                return _UserListItem(
                                  user: user,
                                  batteryLevel: user.batteryLevel ?? _batteryLevels[user.uniqueId],
                                  onTap: () => context.go(
                                    '${RoutePaths.guardianMap}?userId=${Uri.encodeComponent(user.uniqueId)}',
                                  ),
                                  onAlertsTap: () {
                                    if (mounted) {
                                      _showRecentAlerts(user).catchError((e) {
                                        debugPrint('[DIALOG] alerts error: $e');
                                      });
                                    }
                                  },
                                  onMoreTap: () {
                                    if (mounted) {
                                      _showUserActions(user).catchError((e) {
                                        debugPrint(
                                            '[DIALOG] actions error: $e');
                                      });
                                    }
                                  },
                                )
                                    .animate()
                                    .fadeIn(
                                      delay: (240 + (index * 80)).ms,
                                      duration: 400.ms,
                                    )
                                    .slideX(begin: 0.04, curve: Curves.easeOut);
                              },
                            ),

                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ), // RefreshIndicator
          ],
        ),
      ),
      bottomNavigationBar: _PremiumBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 0) return;
          if (index == 1) context.push(RoutePaths.guardianMap);
          if (index == 2) context.push(RoutePaths.profile);
        },
      ),
    );
  }

  void _startBatteryPolling(List<MonitoredUserModel> monitoredUsers) {
    if (monitoredUsers.isEmpty) return;

    // Fetch immediately on first load
    _fetchBatteryLevels(monitoredUsers);

    // Poll every 30 seconds for battery updates
    _batteryPollTimer?.cancel();
    _batteryPollTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _fetchBatteryLevels(monitoredUsers),
    );
  }

  Future<void> _fetchBatteryLevels(
      List<MonitoredUserModel> monitoredUsers) async {
    if (!mounted) return;
    final apiService = ref.read(apiServiceProvider);

    for (final user in monitoredUsers) {
      if (!mounted) return;
      try {
        final summary = await apiService.getUserSummary(user.uniqueId);
        if (summary == null) continue;

        // Try multiple paths for battery level
        final currentLocation = summary['current_location'];
        final batteryValue = currentLocation is Map
            ? (currentLocation['battery_level'] ?? currentLocation['batteryLevel'])
            : (summary['battery_level'] ?? summary['batteryLevel']);

        final level = _parseBattery(batteryValue);
        if (!mounted) return;

        setState(() {
          _batteryLevels[user.uniqueId] = level;
        });

        // Show low battery notification if < 20 and not already shown
        if (level != null && level < 20) {
          if (_lowBatteryWarningsShown.add(user.uniqueId)) {
            _showLowBatteryPopup(user.name, level);
          }
        }

        debugPrint(
          '[BATTERY] ${user.name} (${user.uniqueId}): $level%',
        );
      } catch (e) {
        debugPrint('[BATTERY] fetch error for ${user.uniqueId}: $e');
      }
    }
  }

  int? _parseBattery(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  void _showLowBatteryPopup(String userName, int level) {
    if (!mounted) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _TopBatteryBanner(
        userName: userName,
        level: level,
        onDismiss: () {
          entry.remove();
        },
      ),
    );
    overlay.insert(entry);
  }

  void _startAlertPolling(List<MonitoredUserModel> monitoredUsers) {
    if (monitoredUsers.isEmpty) return;

    // Run first check immediately if not done yet
    if (!_initialAlertLoadDone) {
      _checkForNewAlerts(monitoredUsers);
    }

    // Set up periodic polling every 15 seconds
    _alertPollTimer?.cancel();
    _alertPollTimer = Timer.periodic(
      const Duration(seconds: 7),
      (_) => _checkForNewAlerts(monitoredUsers),
    );
  }

  Future<void> _checkForNewAlerts(
      List<MonitoredUserModel> monitoredUsers) async {
    if (!mounted) return;

    try {
      final notifier = ref.read(guardianDashboardProvider.notifier);
      final alertsResponse = await notifier.fetchAllAlerts(monitoredUsers);
      final alerts = alertsResponse.data;

      if (!mounted) return;

      if (!_initialAlertLoadDone) {
        // First load: seed seen IDs without showing pop-ups
        for (final alert in alerts) {
          _seenAlertIds.add(alert.id);
        }
        _initialAlertLoadDone = true;
        debugPrint(
            '[ALERTS] Initial load: seeded ${_seenAlertIds.length} alert IDs');
        return;
      }

      // Find new alerts
      final newAlerts =
          alerts.where((a) => !_seenAlertIds.contains(a.id)).toList();
      if (newAlerts.isEmpty) return;

      // Mark as seen
      for (final alert in newAlerts) {
        _seenAlertIds.add(alert.id);
      }

      debugPrint('[ALERTS] ${newAlerts.length} new alert(s) detected');

      // Build user name lookup
      final userNameById = <String, String>{};
      for (final user in monitoredUsers) {
        userNameById[user.id] = user.name;
        userNameById[user.uniqueId] = user.name;
      }

      // Show pop-up for each new alert (most recent first, max 3)
      for (final alert in newAlerts.take(3)) {
        if (!mounted) return;
        final userName = userNameById[alert.userId] ?? 'User';
        _showAlertPopup(alert, userName);
        // Small delay between multiple notifications
        if (newAlerts.length > 1) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }
    } catch (error) {
      debugPrint('[ALERTS] polling error: $error');
    }
  }

  void _showAlertPopup(AlertModel alert, String userName) {
    if (!mounted) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _TopAlertBanner(
        userName: userName,
        alert: alert,
        onDismiss: () {
          entry.remove();
        },
      ),
    );
    overlay.insert(entry);
  }

  // --- Dialogs & Helpers ---

  Future<void> _showCreateProfileDialog(
      {String? defaultName, String? defaultEmail, String? defaultPhone}) async {
    final nameController = TextEditingController(text: defaultName ?? '');
    final phoneController = TextEditingController(text: defaultPhone ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Your Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Phone Number'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(guardianDashboardProvider.notifier).createProfile(
                    name: nameController.text.trim(),
                    phoneNumber: phoneController.text.trim(),
                  );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRecentAlerts(MonitoredUserModel user) async {
    if (!mounted) return;
    final notifier = ref.read(guardianDashboardProvider.notifier);
    final alerts = await notifier.fetchRecentAlerts(user.id);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PremiumSheet(
        title: 'Recent Activity',
        subtitle: user.name,
        child: alerts.data.isEmpty
            ? const _SheetEmptyState(
                icon: Icons.notifications_none_rounded,
                message: 'No recent alerts for this user.',
              )
            : Column(
                children: alerts.data
                    .map(
                      (alert) => _AlertTile(
                        alert: alert,
                        onTap: () => _showAlertDetails(alert, user),
                      ),
                    )
                    .toList(),
              ),
      ),
    );
  }

  void _showAlertDetails(AlertModel alert, MonitoredUserModel user) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PremiumSheet(
        title: alert.title,
        subtitle: user.name,
        maxHeight: 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailLine(label: 'Message', value: alert.message),
            _DetailLine(
              label: 'Time',
              value: DateFormat('dd MMM yyyy, hh:mm a')
                  .format(alert.createdAt.toLocal()),
            ),
            if (alert.severity?.trim().isNotEmpty == true)
              _DetailLine(label: 'Severity', value: alert.severity!),
            if (alert.type?.trim().isNotEmpty == true)
              _DetailLine(label: 'Type', value: _formatLabel(alert.type!)),
            if (alert.objectType?.trim().isNotEmpty == true)
              _DetailLine(
                label: 'Object',
                value: _formatLabel(alert.objectType!),
              ),
            if (alert.distanceMeters != null)
              _DetailLine(
                label: 'Distance',
                value: '${alert.distanceMeters!.toStringAsFixed(1)} m',
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showUserActions(MonitoredUserModel user) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _PremiumSheet(
        title: user.name,
        subtitle: 'ID: ${user.uniqueId}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetActionTile(
              icon: Icons.link_off_rounded,
              iconColor: AppColors.error,
              label: 'Unlink user',
              subtitle: 'Remove this user from your account',
              onTap: () => Navigator.pop(context, 'unlink'),
              isDestructive: true,
            ),
          ],
        ),
      ),
    );

    if (!mounted || selected != 'unlink') return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(28),
                boxShadow: AppColors.elevatedShadow,
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.errorLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.link_off_rounded,
                          color: AppColors.error,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Unlink User',
                        style: AppTextStyles.h3.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Are you sure you want to unlink ${user.name} (${user.uniqueId})?',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: AppTextStyles.button.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Elevated button here
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          // The global ElevatedButton theme forces
                          // minimumSize: Size(double.infinity, 56) to make
                          // buttons full-width. Inside this Row the width is
                          // unbounded, so that infinite min-width crashes
                          // layout — override it back to intrinsic sizing.
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Unlink',
                          style: AppTextStyles.button.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ) ??
        false;

    if (!mounted || !confirmed) return;

    // Read the messenger BEFORE the await so we don't depend on `context`
    // surviving a router redirect (which fires when the last monitored user
    // is removed and `monitored_users` becomes empty).
    final messenger = ScaffoldMessenger.maybeOf(context);
    final userName = user.name;

    try {
      final notifier = ref.read(guardianDashboardProvider.notifier);
      await notifier.unlinkUser(
        userUniqueId: user.uniqueId,
        fallbackUserId: user.id,
      );
      _safeShowSnackBar(
        messenger,
        '$userName was unlinked successfully.',
      );
    } catch (error) {
      final message = error is AppException ? error.message : error.toString();
      _safeShowSnackBar(messenger, message, isError: true);
    }
  }

  void _safeShowSnackBar(
    ScaffoldMessengerState? messenger,
    String message, {
    bool isError = false,
  }) {
    if (messenger == null) return;
    try {
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.error : null,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      );
    } catch (_) {
      // Messenger was disposed mid-redirect; swallow.
    }
  }

  Future<void> _showNotificationsSheet(
    List<MonitoredUserModel> monitoredUsers,
  ) async {
    final notifications = await _loadNotifications(monitoredUsers);
    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _PremiumSheet(
        title: 'Notifications',
        subtitle: 'Alerts and location updates for your users.',
        maxHeight: 0.8,
        child: notifications.isEmpty
            ? const _SheetEmptyState(
                icon: Icons.notifications_off_outlined,
                message: 'No notifications yet.',
              )
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: notifications.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  return _NotificationTile(
                    notification: notification,
                    onTap: () async {
                      final navigator = Navigator.of(sheetContext);
                      final router = GoRouter.of(context);
                      try {
                        await ref
                            .read(guardianDashboardProvider.notifier)
                            .markNotificationRead(notification.id);
                      } catch (error) {
                        debugPrint(
                          '[NOTIFICATIONS] mark read failed for '
                          '${notification.id}: $error',
                        );
                      }
                      if (!mounted) return;
                      navigator.pop();
                      if (notification.kind ==
                          _GuardianNotificationKind.locationUpdate) {
                        router.go(
                          '${RoutePaths.guardianMap}?userId=${Uri.encodeComponent(notification.userUniqueId)}',
                        );
                        return;
                      }
                      _showNotificationDetails(notification);
                    },
                  );
                },
              ),
      ),
    );
  }

  Future<List<_GuardianNotification>> _loadNotifications(
    List<MonitoredUserModel> monitoredUsers,
  ) async {
    final monitoredById = {
      for (final user in monitoredUsers) user.id: user,
      for (final user in monitoredUsers) user.uniqueId: user,
    };

    try {
      final response = await ref
          .read(guardianDashboardProvider.notifier)
          .fetchNotifications();
      final notifications = response.data
          .map(
            (notification) => _GuardianNotification.fromApi(
              notification: notification,
              monitoredUsersById: monitoredById,
            ),
          )
          .toList();
      notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return notifications;
    } catch (_) {
      return [];
    }
  }

  void _showNotificationDetails(_GuardianNotification notification) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notification.userName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.message, style: AppTextStyles.bodyMedium),
            const SizedBox(height: 12),
            Text(
              notification.details,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('dd MMM yyyy, hh:mm a').format(notification.timestamp),
              style:
                  AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// ─── Premium Sheet ─────────────────────────────────────────────────────────────

class _PremiumSheet extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final double maxHeight;

  const _PremiumSheet({
    required this.title,
    this.subtitle,
    required this.child,
    this.maxHeight = 0.65,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * maxHeight,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.h3),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sheet utilities ──────────────────────────────────────────────────────────

class _SheetEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _SheetEmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: AppColors.textHint),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style:
                  AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SheetActionTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.label.copyWith(
                      color: isDestructive
                          ? AppColors.error
                          : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── App Bar ──────────────────────────────────────────────────────────────────

class _HomeAppBar extends StatelessWidget {
  final String userName;
  final VoidCallback onNotificationsTap;
  final VoidCallback onProfileTap;

  const _HomeAppBar({
    required this.userName,
    required this.onNotificationsTap,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 148,
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        expandedTitleScale: 1.0,
        titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        title: Text(
          'Guardian Hub',
          style: AppTextStyles.h3.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        background: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Good ${_greeting()},',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      userName,
                      style: AppTextStyles.h2.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Hero(
                  tag: 'profile_pic',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Notification button
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                          boxShadow: AppColors.softShadow,
                        ),
                        child: IconButton(
                          onPressed: onNotificationsTap,
                          icon: Icon(
                            Icons.notifications_outlined,
                            color: AppColors.textPrimary,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Avatar
                      GestureDetector(
                        onTap: onProfileTap,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF2D9CDB),
                                Color(0xFF0F4C81),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: AppColors.cardShadow,
                          ),
                          child: Center(
                            child: Text(
                              userName[0].toUpperCase(),
                              style: AppTextStyles.h3.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: AppTextStyles.h2.copyWith(
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── User List Item ───────────────────────────────────────────────────────────

class _UserListItem extends StatelessWidget {
  final MonitoredUserModel user;
  final int? batteryLevel;
  final VoidCallback onTap;
  final VoidCallback onAlertsTap;
  final VoidCallback onMoreTap;

  const _UserListItem({
    required this.user,
    this.batteryLevel,
    required this.onTap,
    required this.onAlertsTap,
    required this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = user.active;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.8),
            ),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            children: [
              // Top row
              Row(
                children: [
                  // Avatar
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.14),
                          AppColors.primary.withValues(alpha: 0.06),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        user.name[0].toUpperCase(),
                        style: AppTextStyles.h3.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Name + status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: AppTextStyles.h4.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _StatusPill(
                              label: isActive ? 'Active Now' : 'Offline',
                              color: isActive
                                  ? AppColors.success
                                  : AppColors.textHint,
                              background: isActive
                                  ? AppColors.success.withValues(alpha: 0.10)
                                  : AppColors.surfaceVariant,
                            ),
                            if (batteryLevel != null)
                              _StatusPill(
                                label: '$batteryLevel%',
                                color: batteryLevel! < 20
                                    ? AppColors.error
                                    : AppColors.primary,
                                background: (batteryLevel! < 20
                                        ? AppColors.error
                                        : AppColors.primary)
                                    .withValues(alpha: 0.10),
                                icon: batteryLevel! < 20
                                    ? Icons.battery_alert_rounded
                                    : Icons.battery_5_bar_rounded,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // More button
                  IconButton(
                    onPressed: onMoreTap,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.more_horiz_rounded,
                        color: AppColors.textSecondary,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Divider
              Container(height: 1, color: AppColors.divider),
              const SizedBox(height: 14),

              // Action row – Alerts only
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: onAlertsTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_none_rounded,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Alerts',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    required this.background,
    this.icon,
  });

  final String label;
  final Color color;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon == null)
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            )
          else
            Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Alert Tile ───────────────────────────────────────────────────────────────

class _AlertTile extends StatelessWidget {
  const _AlertTile({
    required this.alert,
    required this.onTap,
  });

  final AlertModel alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final severityColor = switch ((alert.severity ?? '').toLowerCase()) {
      'high' => AppColors.error,
      'medium' => AppColors.warning,
      'low' => AppColors.success,
      _ => AppColors.error,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: severityColor.withValues(alpha: 0.15)),
            boxShadow: AppColors.softShadow,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: severityColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.warning_rounded,
                  color: severityColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(alert.title, style: AppTextStyles.label),
                    const SizedBox(height: 3),
                    Text(alert.message, style: AppTextStyles.bodySmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (alert.objectType != null)
                          _AlertChip(
                            label: 'Object: ${_toLabel(alert.objectType!)}',
                            color: AppColors.primary,
                          ),
                        if (alert.type != null)
                          _AlertChip(
                            label: 'Obstacle: ${_toLabel(alert.type!)}',
                            color: severityColor,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _toLabel(String value) {
    return value
        .replaceAll('_', ' ')
        .split(RegExp(r'\s+'))
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' ');
  }
}

class _AlertChip extends StatelessWidget {
  const _AlertChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Notification Tile ────────────────────────────────────────────────────────

enum _GuardianNotificationKind { alert, locationUpdate }

class _GuardianNotification {
  const _GuardianNotification({
    required this.id,
    required this.kind,
    required this.userName,
    required this.userUniqueId,
    required this.message,
    required this.details,
    required this.timestamp,
    this.isRead = false,
  });

  final String id;
  final _GuardianNotificationKind kind;
  final String userName;
  final String userUniqueId;
  final String message;
  final String details;
  final DateTime timestamp;
  final bool isRead;

  factory _GuardianNotification.fromApi({
    required GuardianNotificationModel notification,
    required Map<String, MonitoredUserModel> monitoredUsersById,
  }) {
    final resolvedUser = monitoredUsersById[notification.userUniqueId] ??
        monitoredUsersById[notification.userId];
    final resolvedName = resolvedUser?.name ??
        notification.userName ??
        notification.userUniqueId ??
        notification.userId ??
        'Linked User';
    final resolvedUniqueId = resolvedUser?.uniqueId ??
        notification.userUniqueId ??
        notification.userId ??
        '';
    final details = notification.details?.trim().isNotEmpty == true
        ? notification.details!
        : (notification.title?.trim().isNotEmpty == true
            ? notification.title!
            : notification.message);

    return _GuardianNotification(
      id: notification.id,
      kind: notification.isLocationUpdate
          ? _GuardianNotificationKind.locationUpdate
          : _GuardianNotificationKind.alert,
      userName: resolvedName,
      userUniqueId: resolvedUniqueId,
      message: notification.message,
      details: details,
      timestamp: notification.timestamp,
      isRead: notification.isRead,
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  final _GuardianNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLocation =
        notification.kind == _GuardianNotificationKind.locationUpdate;
    final color = isLocation ? AppColors.primary : AppColors.error;

    return Material(
      color: notification.isRead
          ? AppColors.surface
          : color.withValues(alpha: 0.03),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: notification.isRead
                  ? AppColors.border
                  : color.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isLocation
                      ? Icons.location_on_outlined
                      : Icons.notifications_active_rounded,
                  color: color,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notification.userName, style: AppTextStyles.label),
                    const SizedBox(height: 3),
                    Text(notification.message, style: AppTextStyles.bodySmall),
                    const SizedBox(height: 5),
                    Text(
                      DateFormat('dd MMM, hh:mm a')
                          .format(notification.timestamp),
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textHint),
                    ),
                  ],
                ),
              ),
              if (!notification.isRead)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Premium Bottom Nav ───────────────────────────────────────────────────────

class _PremiumBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _PremiumBottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.home_rounded, Icons.home_outlined, 'Home'),
      (Icons.map_rounded, Icons.map_outlined, 'Map'),
      (Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
        boxShadow: AppColors.elevatedShadow,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final isSelected = currentIndex == i;
              final (filledIcon, outlineIcon, label) = items[i];
              return GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.10)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? filledIcon : outlineIcon,
                        color:
                            isSelected ? AppColors.primary : AppColors.textHint,
                        size: 22,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        label,
                        style: AppTextStyles.caption.copyWith(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textHint,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ─── Create Profile Banner ────────────────────────────────────────────────────

class _CreateProfileBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _CreateProfileBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.person_add_outlined,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile Incomplete',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Complete your profile to unlock all features.',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Setup',
                style: AppTextStyles.labelSmall.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _AddWearableButton extends StatelessWidget {
  const _AddWearableButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              'Add',
              style: AppTextStyles.labelSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.07),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_search_rounded,
              size: 34,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No Monitored Users',
            style: AppTextStyles.h3,
          ),
          const SizedBox(height: 6),
          Text(
            'Tap the Add button above to link\na user and start monitoring.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Error State ──────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.errorLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text('Something went wrong', style: AppTextStyles.h3),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 28),
            PrimaryButton(
              text: 'Try Again',
              onPressed: onRetry,
              width: 160,
              height: 48,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textHint,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(value, style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}

String _formatLabel(String value) {
  return value
      .replaceAll('_', ' ')
      .split(RegExp(r'\s+'))
      .map((word) => word.isEmpty
          ? word
          : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
      .join(' ');
}

// ─── Top Alert Banner (Overlay-based) ─────────────────────────────────────────

class _TopAlertBanner extends StatefulWidget {
  final String userName;
  final AlertModel alert;
  final VoidCallback onDismiss;

  const _TopAlertBanner({
    required this.userName,
    required this.alert,
    required this.onDismiss,
  });

  @override
  State<_TopAlertBanner> createState() => _TopAlertBannerState();
}

class _TopAlertBannerState extends State<_TopAlertBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _autoDismissTimer;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _controller.forward();
    _autoDismissTimer = Timer(const Duration(seconds: 5), _dismiss);
  }

  void _dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    _autoDismissTimer?.cancel();
    _controller.reverse().then((_) {
      widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null &&
                  details.primaryVelocity! < -100) {
                _dismiss();
              }
            },
            onTap: _dismiss,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: EdgeInsets.only(
                  top: topPadding + 12,
                  left: 16,
                  right: 16,
                  bottom: 14,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFE65100), Color(0xFFBF360C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.userName} — ${widget.alert.title}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.alert.message,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.close_rounded,
                      color: Colors.white.withValues(alpha: 0.6),
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Top Battery Banner (Overlay-based) ───────────────────────────────────────

class _TopBatteryBanner extends StatefulWidget {
  final String userName;
  final int level;
  final VoidCallback onDismiss;

  const _TopBatteryBanner({
    required this.userName,
    required this.level,
    required this.onDismiss,
  });

  @override
  State<_TopBatteryBanner> createState() => _TopBatteryBannerState();
}

class _TopBatteryBannerState extends State<_TopBatteryBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _autoDismissTimer;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _controller.forward();
    _autoDismissTimer = Timer(const Duration(seconds: 5), _dismiss);
  }

  void _dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    _autoDismissTimer?.cancel();
    _controller.reverse().then((_) {
      widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null &&
                  details.primaryVelocity! < -100) {
                _dismiss();
              }
            },
            onTap: _dismiss,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: EdgeInsets.only(
                  top: topPadding + 12,
                  left: 16,
                  right: 16,
                  bottom: 14,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFEF6C00), Color(0xFFE65100)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.battery_alert_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.userName} — Low Battery',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Battery is at ${widget.level}%. Device may go offline soon.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.close_rounded,
                      color: Colors.white.withValues(alpha: 0.6),
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
