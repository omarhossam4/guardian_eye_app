import 'package:shared_preferences/shared_preferences.dart';

abstract class LocationLocalDataSource {
  Future<void> cacheLastLocation(double latitude, double longitude);
  Future<Map<String, double>?> getLastLocation();
}

class LocationLocalDataSourceImpl implements LocationLocalDataSource {
  final SharedPreferences sharedPreferences;

  LocationLocalDataSourceImpl({required this.sharedPreferences});

  @override
  Future<void> cacheLastLocation(double latitude, double longitude) async {
    await sharedPreferences.setDouble('last_latitude', latitude);
    await sharedPreferences.setDouble('last_longitude', longitude);
  }

  @override
  Future<Map<String, double>?> getLastLocation() async {
    final latitude = sharedPreferences.getDouble('last_latitude');
    final longitude = sharedPreferences.getDouble('last_longitude');

    if (latitude != null && longitude != null) {
      return {'latitude': latitude, 'longitude': longitude};
    }
    return null;
  }
}
