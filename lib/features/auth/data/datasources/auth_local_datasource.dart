import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guardian_eye/core/constants/app_constants.dart';
import 'package:guardian_eye/features/auth/data/models/user_model.dart';

abstract class AuthLocalDataSource {
  Future<void> cacheUser(UserModel user);
  Future<UserModel?> getCachedUser();
  Future<void> cacheToken(String token);
  Future<String?> getToken();
  Future<void> clearCache();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final SharedPreferences sharedPreferences;

  AuthLocalDataSourceImpl({required this.sharedPreferences});

  @override
  Future<void> cacheUser(UserModel user) async {
    final userJson = jsonEncode(user.toJson());
    await sharedPreferences.setString(AppConstants.cachedUserKey, userJson);
  }

  @override
  Future<UserModel?> getCachedUser() async {
    final userJson = sharedPreferences.getString(AppConstants.cachedUserKey);
    if (userJson != null) {
      return UserModel.fromJson(jsonDecode(userJson));
    }
    return null;
  }

  @override
  Future<void> cacheToken(String token) async {
    await sharedPreferences.setString(AppConstants.userTokenKey, token);
  }

  @override
  Future<String?> getToken() async {
    return sharedPreferences.getString(AppConstants.userTokenKey);
  }

  @override
  Future<void> clearCache() async {
    await sharedPreferences.remove(AppConstants.cachedUserKey);
    await sharedPreferences.remove(AppConstants.userTokenKey);
  }
}
