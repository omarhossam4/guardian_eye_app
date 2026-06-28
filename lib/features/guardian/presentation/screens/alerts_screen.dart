import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:guardian_eye/core/constants/route_paths.dart';
import 'package:guardian_eye/core/theme/app_colors.dart';
import 'package:guardian_eye/core/theme/app_text_styles.dart';
import 'package:guardian_eye/features/guardian/data/models/alert_model.dart';
import 'package:guardian_eye/features/guardian/data/models/monitored_user_model.dart';
import 'package:guardian_eye/features/guardian/presentation/providers/guardian_providers.dart';

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(guardianDashboardProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => context.go(RoutePaths.guardianHome),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        ),
        title: const Text('All Alerts'),
      ),
      body: dashboard.when(
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (error, _) => _MessageState(
          icon: Icons.error_outline_rounded,
          message: error.toString(),
        ),
        data: (state) {
          if (state.monitoredUsers.isEmpty) {
            return const _MessageState(
              icon: Icons.notifications_off_outlined,
              message: 'No linked users yet.',
            );
          }

          return FutureBuilder(
            future: ref
                .read(guardianDashboardProvider.notifier)
                .fetchAllAlerts(state.monitoredUsers),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator.adaptive(),
                );
              }

              if (snapshot.hasError) {
                return _MessageState(
                  icon: Icons.error_outline_rounded,
                  message: snapshot.error.toString(),
                );
              }

              final alerts = snapshot.data?.data ?? const <AlertModel>[];
              if (alerts.isEmpty) {
                return const _MessageState(
                  icon: Icons.notifications_none_rounded,
                  message: 'No alerts yet.',
                );
              }

              final usersById = {
                for (final user in state.monitoredUsers) user.id: user,
                for (final user in state.monitoredUsers) user.uniqueId: user,
              };

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(guardianDashboardProvider);
                },
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  itemCount: alerts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final alert = alerts[index];
                    final user = usersById[alert.userId];
                    return _AlertListTile(
                      alert: alert,
                      user: user,
                      onTap: () => _showAlertDetails(context, alert, user),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAlertDetails(
    BuildContext context,
    AlertModel alert,
    MonitoredUserModel? user,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AlertDetailsSheet(alert: alert, user: user),
    );
  }
}

class _AlertListTile extends StatelessWidget {
  const _AlertListTile({
    required this.alert,
    required this.user,
    required this.onTap,
  });

  final AlertModel alert;
  final MonitoredUserModel? user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(alert.severity);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.18)),
            boxShadow: AppColors.softShadow,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.warning_rounded, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(alert.title, style: AppTextStyles.label),
                    const SizedBox(height: 4),
                    Text(
                      user?.name ?? alert.userId,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(alert.message, style: AppTextStyles.bodySmall),
                    const SizedBox(height: 8),
                    Text(
                      DateFormat('dd MMM yyyy, hh:mm a')
                          .format(alert.createdAt.toLocal()),
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertDetailsSheet extends StatelessWidget {
  const _AlertDetailsSheet({
    required this.alert,
    required this.user,
  });

  final AlertModel alert;
  final MonitoredUserModel? user;

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(alert.severity);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.warning_rounded, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(alert.title, style: AppTextStyles.h3),
                      const SizedBox(height: 3),
                      Text(
                        user?.name ?? alert.userId,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _DetailRow(label: 'Message', value: alert.message),
            _DetailRow(
              label: 'Time',
              value: DateFormat('dd MMM yyyy, hh:mm a')
                  .format(alert.createdAt.toLocal()),
            ),
            if (alert.severity?.trim().isNotEmpty == true)
              _DetailRow(label: 'Severity', value: alert.severity!),
            if (alert.type?.trim().isNotEmpty == true)
              _DetailRow(label: 'Type', value: _toLabel(alert.type!)),
            if (alert.objectType?.trim().isNotEmpty == true)
              _DetailRow(label: 'Object', value: _toLabel(alert.objectType!)),
            if (alert.distanceMeters != null)
              _DetailRow(
                label: 'Distance',
                value: '${alert.distanceMeters!.toStringAsFixed(1)} m',
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

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

class _MessageState extends StatelessWidget {
  const _MessageState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.textHint),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _severityColor(String? severity) {
  return switch ((severity ?? '').toLowerCase()) {
    'low' => AppColors.success,
    'medium' => AppColors.warning,
    _ => AppColors.error,
  };
}

String _toLabel(String value) {
  return value
      .replaceAll('_', ' ')
      .split(RegExp(r'\s+'))
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
      )
      .join(' ');
}
