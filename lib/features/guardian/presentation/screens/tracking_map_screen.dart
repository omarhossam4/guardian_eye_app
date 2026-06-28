import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:guardian_eye/core/constants/app_constants.dart';
import 'package:guardian_eye/core/constants/route_paths.dart';
import 'package:guardian_eye/core/theme/app_colors.dart';
import 'package:guardian_eye/core/theme/app_text_styles.dart';
import 'package:guardian_eye/features/guardian/data/models/location_model.dart';
import 'package:guardian_eye/features/guardian/data/models/monitored_user_model.dart';
import 'package:guardian_eye/features/guardian/presentation/providers/guardian_providers.dart';

class TrackingMapScreen extends ConsumerStatefulWidget {
  const TrackingMapScreen({
    super.key,
    this.userId,
  });

  final String? userId;

  @override
  ConsumerState<TrackingMapScreen> createState() => _TrackingMapScreenState();
}

class _TrackingMapScreenState extends ConsumerState<TrackingMapScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  Timer? _refreshTimer;
  bool _isRefreshing = false;
  bool _hasLoadedLocations = false;
  String? _selectedUserId;
  List<_TrackedUserLocation> _entries = const [];
  String _usersSignature = '';

  @override
  void initState() {
    super.initState();
    _selectedUserId = widget.userId;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TrackingMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _selectedUserId = widget.userId;
      final selected = _resolveSelectedEntry(_entries);
      if (selected != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _animateToEntry(selected);
        });
      }
    }
  }

  Future<void> _refreshLocations(List<MonitoredUserModel> users) async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      final entries = <_TrackedUserLocation>[];
      for (final user in users) {
        final location = await _fetchLocationForUser(user);
        if (location != null) {
          entries.add(_TrackedUserLocation(user: user, location: location));
        }
      }

      if (!mounted) return;
      setState(() {
        _entries = entries;
        _hasLoadedLocations = true;
        if (_selectedUserId == null || _resolveSelectedEntry(entries) == null) {
          _selectedUserId =
              entries.isNotEmpty ? entries.first.user.uniqueId : null;
        }
      });

      final selected = _resolveSelectedEntry(entries);
      if (selected != null) {
        await _focusMap(entries, selected);
      }
    } finally {
      _isRefreshing = false;
    }
  }

  void _ensureRefreshTimer(List<MonitoredUserModel> users) {
    final signature = users.map((user) => user.uniqueId).join('|');
    if (_usersSignature != signature) {
      _usersSignature = signature;
      _hasLoadedLocations = false;
      _entries = const [];
      _refreshTimer?.cancel();
      _refreshTimer = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshLocations(users);
      });
    }

    _refreshTimer ??= Timer.periodic(
      const Duration(seconds: 20),
      (_) => _refreshLocations(users),
    );
  }

  Future<LocationModel?> _fetchLocationForUser(MonitoredUserModel user) async {
    try {
      final response = await ref
          .read(guardianDashboardProvider.notifier)
          .fetchCurrentLocation(user.id);
      return response.data;
    } catch (_) {
      if (user.uniqueId == user.id) {
        return null;
      }
    }

    try {
      final response = await ref
          .read(guardianDashboardProvider.notifier)
          .fetchCurrentLocation(user.uniqueId);
      return response.data;
    } catch (_) {
      return null;
    }
  }

  _TrackedUserLocation? _resolveSelectedEntry(
      List<_TrackedUserLocation> entries) {
    if (entries.isEmpty) return null;
    for (final entry in entries) {
      if (entry.user.uniqueId == _selectedUserId ||
          entry.user.id == _selectedUserId) {
        return entry;
      }
    }
    return entries.first;
  }

  Future<void> _animateToEntry(_TrackedUserLocation entry) async {
    if (!_mapController.isCompleted) return;
    final controller = await _mapController.future;
    final target = _latLngFor(entry.location);
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: target,
          zoom: 17,
          tilt: 0,
          bearing: 0,
        ),
      ),
    );
  }

  Future<void> _focusMap(
    List<_TrackedUserLocation> entries,
    _TrackedUserLocation selected,
  ) async {
    if (!_mapController.isCompleted) return;
    if (widget.userId != null || entries.length == 1) {
      await _animateToEntry(selected);
      return;
    }

    final controller = await _mapController.future;
    final bounds = _boundsFor(entries);
    if (bounds == null) {
      await _animateToEntry(selected);
      return;
    }

    await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 70));
  }

  LatLng _latLngFor(LocationModel location) {
    return LatLng(
      location.latitude == 0 ? AppConstants.defaultLatitude : location.latitude,
      location.longitude == 0
          ? AppConstants.defaultLongitude
          : location.longitude,
    );
  }

  LatLngBounds? _boundsFor(List<_TrackedUserLocation> entries) {
    if (entries.isEmpty) return null;

    final points = entries.map((entry) => _latLngFor(entry.location)).toList();
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;

    for (final point in points.skip(1)) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    if (minLat == maxLat && minLng == maxLng) return null;

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  Future<void> _openInGoogleMaps(_TrackedUserLocation entry) async {
    final latitude = entry.location.latitude;
    final longitude = entry.location.longitude;
    final label = Uri.encodeComponent(entry.user.name);
    final uri =
        Uri.parse('geo:$latitude,$longitude?q=$latitude,$longitude($label)');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      final topPadding = MediaQuery.of(context).padding.top;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not open Google Maps.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          dismissDirection: DismissDirection.up,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: EdgeInsets.only(
            top: topPadding + 8,
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).size.height - topPadding - 100,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
    );

    final dashboard = ref.watch(guardianDashboardProvider);

    return dashboard.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      ),
      error: (error, _) => Scaffold(
        body: Center(child: Text(error.toString())),
      ),
      data: (state) {
        final users = state.monitoredUsers;
        if (users.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              leading: _MapBackButton(
                onTap: () => context.go(RoutePaths.guardianHome),
              ),
              title: const Text('Live Map'),
            ),
            body: const Center(
              child: _MapEmptyState(),
            ),
            bottomNavigationBar: _MapBottomNav(
              onHome: () => context.go(RoutePaths.guardianHome),
              onProfile: () => context.go(RoutePaths.profile),
            ),
          );
        }

        _ensureRefreshTimer(users);
        if (!_hasLoadedLocations) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _refreshLocations(users);
          });
        }

        final selectedEntry = _resolveSelectedEntry(_entries);

        if (_entries.isEmpty || selectedEntry == null) {
          return Scaffold(
            extendBodyBehindAppBar: true,
            body: Stack(
              children: [
                Container(color: AppColors.background),
                Center(
                  child: _hasLoadedLocations
                      ? _MapNoLocationsState(
                          onRetry: () => _refreshLocations(users),
                        )
                      : const CircularProgressIndicator.adaptive(),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        _MapTopButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onTap: () => context.go(RoutePaths.guardianHome),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: _MapTitleBar(subtitle: 'Loading...'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: _MapBottomNav(
              onHome: () => context.go(RoutePaths.guardianHome),
              onProfile: () => context.go(RoutePaths.profile),
            ),
          );
        }

        final target = _latLngFor(selectedEntry.location);

        return Scaffold(
          extendBodyBehindAppBar: true,
          body: Stack(
            children: [
              // Google Map
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: target,
                  zoom: 17,
                  tilt: 0,
                  bearing: 0,
                ),
                mapType: MapType.hybrid,
                markers: _entries
                    .map(
                      (entry) => Marker(
                        markerId: MarkerId(entry.user.uniqueId),
                        position: _latLngFor(entry.location),
                        infoWindow: InfoWindow(
                          title: entry.user.name,
                          snippet: 'Tap card below for details',
                        ),
                        onTap: () {
                          setState(() => _selectedUserId = entry.user.uniqueId);
                        },
                      ),
                    )
                    .toSet(),
                zoomControlsEnabled: false,
                myLocationButtonEnabled: false,
                onMapCreated: (controller) async {
                  if (!_mapController.isCompleted) {
                    _mapController.complete(controller);
                  }
                },
              ),

              // Top bar
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    children: [
                      _MapTopButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => context.go(RoutePaths.guardianHome),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MapTitleBar(
                          subtitle:
                              '${_entries.length} user${_entries.length == 1 ? '' : 's'} tracked',
                        ),
                      ),
                      const SizedBox(width: 12),
                      _MapTopButton(
                        icon: _isRefreshing
                            ? Icons.sync_rounded
                            : Icons.refresh_rounded,
                        onTap: () => _refreshLocations(users),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom cards
              Positioned(
                left: 16,
                right: 16,
                bottom: 24,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Horizontal user selector
                    SizedBox(
                      height: 100,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _entries.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final entry = _entries[index];
                          final isSelected = entry.user.uniqueId ==
                              selectedEntry.user.uniqueId;
                          return _MapUserCard(
                            entry: entry,
                            isSelected: isSelected,
                            onTap: () async {
                              setState(
                                  () => _selectedUserId = entry.user.uniqueId);
                              await _animateToEntry(entry);
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Location detail card
                    GestureDetector(
                      onTap: () => _openInGoogleMaps(selectedEntry),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: AppColors.cardShadow,
                          border: Border.all(
                              color: AppColors.border.withValues(alpha: 0.6)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF2D9CDB),
                                        Color(0xFF0F4C81),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      selectedEntry.user.name[0].toUpperCase(),
                                      style: AppTextStyles.h4.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        selectedEntry.user.name,
                                        style: AppTextStyles.h4,
                                      ),
                                      Text(
                                        'ID: ${selectedEntry.user.uniqueId}',
                                        style: AppTextStyles.caption,
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.20),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.open_in_new_rounded,
                                        size: 13,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Maps',
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Container(
                              height: 1,
                              color: AppColors.divider,
                            ),
                            const SizedBox(height: 14),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.location_on_rounded,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    selectedEntry.location.address
                                                ?.trim()
                                                .isNotEmpty ==
                                            true
                                        ? selectedEntry.location.address!
                                        : '${selectedEntry.location.latitude.toStringAsFixed(6)}, ${selectedEntry.location.longitude.toStringAsFixed(6)}',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time_rounded,
                                  size: 14,
                                  color: AppColors.textHint,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Updated ${DateFormat('dd MMM, hh:mm a').format(selectedEntry.location.updatedAt.toLocal())}',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textHint,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: _MapBottomNav(
            onHome: () => context.go(RoutePaths.guardianHome),
            onProfile: () => context.go(RoutePaths.profile),
          ),
        );
      },
    );
  }
}

// ─── Data class ───────────────────────────────────────────────────────────────

class _TrackedUserLocation {
  const _TrackedUserLocation({
    required this.user,
    required this.location,
  });
  final MonitoredUserModel user;
  final LocationModel location;
}

// ─── Top Button ───────────────────────────────────────────────────────────────

class _MapTopButton extends StatelessWidget {
  const _MapTopButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppColors.cardShadow,
          border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 18),
      ),
    );
  }
}

// ─── Title Bar ────────────────────────────────────────────────────────────────

class _MapTitleBar extends StatelessWidget {
  const _MapTitleBar({required this.subtitle});
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Live Map',
                style: AppTextStyles.h4,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Back Button wrapper ─────────────────────────────────────────────────────

class _MapBackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _MapBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: IconButton(
        onPressed: onTap,
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
      ),
    );
  }
}

// ─── Map User Card ────────────────────────────────────────────────────────────

class _MapUserCard extends StatelessWidget {
  const _MapUserCard({
    required this.entry,
    required this.isSelected,
    required this.onTap,
  });
  final _TrackedUserLocation entry;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        width: 168,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected ? AppColors.buttonShadow : AppColors.softShadow,
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.border.withValues(alpha: 0.6),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.user.name,
              style: AppTextStyles.label.copyWith(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              entry.user.uniqueId,
              style: AppTextStyles.caption.copyWith(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.78)
                    : AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: 12,
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.9)
                      : AppColors.primary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    entry.location.address?.trim().isNotEmpty == true
                        ? entry.location.address!
                        : '${entry.location.latitude.toStringAsFixed(3)}, ${entry.location.longitude.toStringAsFixed(3)}',
                    style: AppTextStyles.caption.copyWith(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.85)
                          : AppColors.textSecondary,
                      fontSize: 10,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Map Empty State ──────────────────────────────────────────────────────────

class _MapEmptyState extends StatelessWidget {
  const _MapEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.07),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.map_outlined,
              size: 34,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text('No Monitored Users', style: AppTextStyles.h3),
          const SizedBox(height: 8),
          Text(
            'Link a user from the home screen\nto track them on the map.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Map Bottom Nav ───────────────────────────────────────────────────────────

class _MapNoLocationsState extends StatelessWidget {
  const _MapNoLocationsState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_off_outlined,
              size: 34,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(height: 20),
          Text('No Location Yet', style: AppTextStyles.h3),
          const SizedBox(height: 8),
          Text(
            'No live location was returned for the linked users yet.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _MapBottomNav extends StatelessWidget {
  const _MapBottomNav({
    required this.onHome,
    required this.onProfile,
  });
  final VoidCallback onHome;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.home_rounded, Icons.home_outlined, 'Home'),
      (Icons.map_rounded, Icons.map_outlined, 'Map'),
      (Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
    ];

    final callbacks = [onHome, () {}, onProfile];

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
              final isSelected = i == 1; // Map is selected
              final (filledIcon, outlineIcon, label) = items[i];
              return GestureDetector(
                onTap: callbacks[i],
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
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
