import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian_eye/core/theme/app_colors.dart';
import 'package:guardian_eye/core/theme/app_text_styles.dart';
import 'package:guardian_eye/features/auth/presentation/providers/auth_providers.dart';
import 'package:guardian_eye/shared/widgets/primary_button.dart';

class BlindMigrationScreen extends ConsumerWidget {
  const BlindMigrationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(blindMigrationControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Blind User Migration')),
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('One-time migration', style: AppTextStyles.h1),
            const SizedBox(height: 8),
            Text(
              'This creates Firebase Auth accounts for blind_users documents that do not yet have auth_uid, then shows the credentials for manual distribution.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              text: 'Run Migration',
              onPressed: state.isLoading
                  ? null
                  : () => ref
                      .read(blindMigrationControllerProvider.notifier)
                      .runMigration(),
              isLoading: state.isLoading,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: state.when(
                loading: () => const Center(
                  child: CircularProgressIndicator.adaptive(),
                ),
                error: (error, _) => Center(
                  child: Text(
                    error.toString(),
                    style: AppTextStyles.bodyMedium,
                  ),
                ),
                data: (results) {
                  if (results.isEmpty) {
                    return Center(
                      child: Text(
                        'No migration results yet.',
                        style: AppTextStyles.bodyMedium,
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = results[index];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${item.name} (${item.blindId})',
                                style: AppTextStyles.h3),
                            const SizedBox(height: 6),
                            SelectableText('Email: ${item.email}'),
                            SelectableText('Password: ${item.password}'),
                            if (item.authUid.isNotEmpty)
                              SelectableText('Auth UID: ${item.authUid}'),
                            const SizedBox(height: 6),
                            Text(
                              'Status: ${item.status}',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: item.status == 'created'
                                    ? AppColors.success
                                    : AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
