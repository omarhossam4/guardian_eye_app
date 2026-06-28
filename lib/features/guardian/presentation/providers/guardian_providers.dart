import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian_eye/core/errors/app_exception.dart';
import 'package:guardian_eye/core/models/api_response.dart';
import 'package:guardian_eye/core/services/api_service.dart';
import 'package:guardian_eye/features/auth/presentation/providers/auth_providers.dart';
import 'package:guardian_eye/features/guardian/data/models/alert_model.dart';
import 'package:guardian_eye/features/guardian/data/models/create_guardian_profile_request.dart';
import 'package:guardian_eye/features/guardian/data/models/guardian_notification_model.dart';
import 'package:guardian_eye/features/guardian/data/models/guardian_profile_model.dart';
import 'package:guardian_eye/features/guardian/data/models/link_user_request.dart';
import 'package:guardian_eye/features/guardian/data/models/location_model.dart';
import 'package:guardian_eye/features/guardian/data/models/monitored_user_model.dart';

final apiServiceProvider = Provider<ApiService>((ref) {
  return ref.watch(authApiServiceProvider);
});

final guardianDashboardProvider = AutoDisposeAsyncNotifierProvider<
    GuardianDashboardController, GuardianDashboardState>(
  GuardianDashboardController.new,
);

class GuardianDashboardController
    extends AutoDisposeAsyncNotifier<GuardianDashboardState> {
  ApiService get _apiService => ref.read(apiServiceProvider);

  @override
  Future<GuardianDashboardState> build() async {
    final session = ref.watch(authControllerProvider).valueOrNull;
    if (session == null) {
      return const GuardianDashboardState(
        profile: null,
        monitoredUsers: [],
      );
    }

    return _loadDashboard();
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_loadDashboard);
  }

  Future<void> refreshSilently() async {
    final previous = state.valueOrNull;
    try {
      state = AsyncValue.data(await _loadDashboard());
    } catch (error) {
      debugPrint('[DASHBOARD] silent refresh failed: $error');
      // Keep previous data if we had it; otherwise stay as error
      if (previous != null) {
        state = AsyncValue.data(previous);
      }
    }
  }

  Future<ApiResponse<GuardianProfileModel>> createProfile({
    required String name,
    required String phoneNumber,
  }) async {
    final response = await _apiService.createGuardianProfile(
      CreateGuardianProfileRequest(
        name: name,
        phoneNumber: phoneNumber,
      ),
    );
    await reload();
    return response;
  }

  Future<void> verifyBackendToken() {
    return _apiService.verifyToken();
  }

  Future<void> linkUser({
    required String userUniqueId,
  }) async {
    final normalizedId = userUniqueId.trim();
    if (normalizedId.isEmpty) {
      throw const AppException('Enter a user unique ID before linking.');
    }

    await _apiService.linkUser(
      LinkUserRequest(
        userUniqueId: normalizedId,
      ),
    );
    await reload();
  }

  Future<void> unlinkUser({
    required String userUniqueId,
    String? fallbackUserId,
  }) async {
    final normalizedUniqueId = userUniqueId.trim();
    final normalizedFallbackId = fallbackUserId?.trim();
    if (normalizedUniqueId.isEmpty && (normalizedFallbackId?.isEmpty ?? true)) {
      throw const AppException('Unable to unlink this user: missing user ID.');
    }

    bool apiSuccess = false;
    final firestoreIdsToRemove = <String>{
      if (normalizedUniqueId.isNotEmpty) normalizedUniqueId,
      if (normalizedFallbackId != null && normalizedFallbackId.isNotEmpty)
        normalizedFallbackId,
    };

    // Try REST API unlink with primary ID
    try {
      await _apiService.unlinkUser(
        LinkUserRequest(
          userUniqueId: normalizedUniqueId.isNotEmpty
              ? normalizedUniqueId
              : normalizedFallbackId!,
        ),
      );
      apiSuccess = true;
    } catch (error) {
      debugPrint('[DASHBOARD] unlinkUser primary failed: $error');

      // Try fallback ID if available
      final canTryFallback = normalizedFallbackId != null &&
          normalizedFallbackId.isNotEmpty &&
          normalizedFallbackId != normalizedUniqueId;
      if (canTryFallback) {
        try {
          await _apiService.unlinkUser(
            LinkUserRequest(userUniqueId: normalizedFallbackId),
          );
          apiSuccess = true;
        } catch (fallbackError) {
          debugPrint('[DASHBOARD] unlinkUser fallback failed: $fallbackError');
        }
      }
    }

    // Always remove from Firestore — the dashboard fallback rebuilds the user
    // list from Firestore IDs when the REST monitored-users endpoint returns
    // empty, so skipping this causes the user to reappear after refresh.
    await _collectFirestoreIdsFromSummary(
      normalizedUniqueId,
      firestoreIdsToRemove,
    );
    if (normalizedFallbackId != null && normalizedFallbackId.isNotEmpty) {
      await _collectFirestoreIdsFromSummary(
        normalizedFallbackId,
        firestoreIdsToRemove,
      );
    }

    try {
      final firestoreService = ref.read(firestoreAuthFlowServiceProvider);
      final profile = await firestoreService.getGuardianProfileForCurrentUser();
      for (final id in firestoreIdsToRemove) {
        await firestoreService.unlinkGuardianFromMonitoredUser(
          guardianId: profile.guardianId,
          blindId: id,
        );
      }
      debugPrint('[DASHBOARD] unlinkUser Firestore removal succeeded');
    } catch (firestoreError) {
      debugPrint('[DASHBOARD] unlinkUser Firestore removal failed: $firestoreError');
      if (!apiSuccess) {
        throw const AppException(
          'Unable to unlink this user right now. Please try again later.',
        );
      }
      // REST succeeded; Firestore failure is non-fatal
    }

    // Optimistically remove the user from local state for immediate UI update
    final current = state.valueOrNull;
    if (current != null) {
      final updated = current.monitoredUsers.where((user) {
        return !firestoreIdsToRemove.contains(user.uniqueId.trim()) &&
            !firestoreIdsToRemove.contains(user.id.trim());
      }).toList();
      state = AsyncValue.data(GuardianDashboardState(
        profile: current.profile,
        monitoredUsers: updated,
      ));
    }

    // Refresh silently to sync with server (avoids removing data branch from tree)
    await refreshSilently();
  }

  Future<void> _collectFirestoreIdsFromSummary(
    String lookupId,
    Set<String> destination,
  ) async {
    if (lookupId.trim().isEmpty) return;
    try {
      final summary = await _apiService.getUserSummary(lookupId);
      if (summary == null) return;
      const keys = <String>{
        'id',
        '_id',
        'user_id',
        'userId',
        'unique_id',
        'uniqueId',
        'user_unique_id',
        'blind_id',
        'blindId',
        'blind_user_id',
        'blindUserId',
      };
      for (final key in keys) {
        final value = summary[key]?.toString().trim();
        if (value != null && value.isNotEmpty) {
          destination.add(value);
        }
      }
    } catch (error) {
      debugPrint('[DASHBOARD] userSummary lookup failed for $lookupId: $error');
    }
  }

  Future<ApiResponse<LocationModel>> fetchCurrentLocation(String userId) {
    return _apiService.getCurrentLocation(userId);
  }

  Future<ApiResponse<List<AlertModel>>> fetchRecentAlerts(String userId) {
    return _apiService.getRecentAlerts(userId);
  }

  Future<ApiResponse<List<AlertModel>>> fetchAllAlerts(
    List<MonitoredUserModel> monitoredUsers,
  ) async {
    final alerts = <AlertModel>[];
    for (final user in monitoredUsers) {
      try {
        final response = await _apiService.getRecentAlerts(user.id);
        alerts.addAll(response.data);
        if (user.uniqueId != user.id) {
          continue;
        }
      } catch (_) {
        if (user.uniqueId == user.id) {
          continue;
        }
      }

      try {
        final response = await _apiService.getRecentAlerts(user.uniqueId);
        alerts.addAll(response.data);
      } catch (_) {}
    }

    alerts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return ApiResponse<List<AlertModel>>(data: alerts);
  }

  Future<ApiResponse<List<GuardianNotificationModel>>> fetchNotifications() {
    return _apiService.getNotifications();
  }

  Future<void> markNotificationRead(String notificationId) {
    return _apiService.markNotificationRead(notificationId);
  }

  Future<GuardianDashboardState> _loadDashboard() async {
    GuardianProfileModel? profile;
    List<MonitoredUserModel> monitoredUsers = const [];
    List<String> firestoreMonitoredUsers = const [];
    Map<String, String> labels = const {};

    try {
      final firestoreProfile =
          await ref.read(currentGuardianFirestoreProfileProvider.future);
      firestoreMonitoredUsers = firestoreProfile.monitoredUsers;
      labels = firestoreProfile.monitoredUserLabels;
      profile = GuardianProfileModel(
        id: firestoreProfile.guardianId,
        name: firestoreProfile.name,
        email: firestoreProfile.email,
        monitoredUsers: firestoreProfile.monitoredUsers,
      );
    } catch (_) {}

    try {
      final profileResponse = await _apiService.getGuardianProfile();
      profile = profileResponse.data;
    } on AppException catch (_) {} catch (_) {}

    try {
      final users = await _apiService.getMonitoredUsers();
      monitoredUsers = users.data;
    } on AppException catch (_) {
      monitoredUsers = const [];
    } catch (_) {
      monitoredUsers = const [];
    }

    // Fallback: if the monitored-users endpoint fails (e.g. server error),
    // use the IDs from the guardian profile and resolve names via user-summary.
    final fallbackIds = profile?.monitoredUsers.isNotEmpty == true
        ? profile!.monitoredUsers
        : firestoreMonitoredUsers;
    if (monitoredUsers.isEmpty && fallbackIds.isNotEmpty) {
      monitoredUsers = await Future.wait(
        fallbackIds.map((uniqueId) async {
          String name = uniqueId;
          try {
            final summary = await _apiService.getUserSummary(uniqueId);
            debugPrint('[DASHBOARD] userSummary for $uniqueId: $summary');
            final fetched = (summary?['name'] ??
                    summary?['user_name'] ??
                    summary?['blind_user_name'] ??
                    '')
                .toString()
                .trim();
            if (fetched.isNotEmpty) name = fetched;
          } catch (e) {
            debugPrint('[DASHBOARD] userSummary error for $uniqueId: $e');
          }
          return MonitoredUserModel(
            id: uniqueId,
            uniqueId: uniqueId,
            name: name,
          );
        }),
      );
    }

    // Enrich user names from user-summary if they are still IDs
    if (monitoredUsers.isNotEmpty) {
      monitoredUsers = await Future.wait(
        monitoredUsers.map((user) async {
          // Skip if name already looks like a real name (not a bare ID)
          if (user.name != user.uniqueId && user.name != user.id) {
            return user;
          }
          try {
            final summary = await _apiService.getUserSummary(user.uniqueId);
            final fetchedName =
                (summary?['name'] ?? summary?['user_name'] ?? '').toString();
            return user.copyWith(
              name: fetchedName.trim().isEmpty ? user.name : fetchedName.trim(),
            );
          } catch (_) {
            return user;
          }
        }),
      );
    }

    // Per-guardian display labels override whatever name came from the REST
    // API / user-summary. Tries both `uniqueId` and `id` because the
    // upstream code uses them interchangeably.
    if (labels.isNotEmpty && monitoredUsers.isNotEmpty) {
      monitoredUsers = monitoredUsers.map((user) {
        final label = labels[user.uniqueId.trim()] ?? labels[user.id.trim()];
        if (label == null || label.isEmpty) return user;
        return user.copyWith(name: label);
      }).toList(growable: false);
    }

    return GuardianDashboardState(
      profile: profile,
      monitoredUsers: monitoredUsers,
    );
  }
}

class GuardianDashboardState {
  const GuardianDashboardState({
    required this.profile,
    required this.monitoredUsers,
  });

  final GuardianProfileModel? profile;
  final List<MonitoredUserModel> monitoredUsers;
}
