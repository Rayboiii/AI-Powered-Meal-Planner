import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

class ProfileProvider with ChangeNotifier {
  final ApiService _api = ApiService();
  
  UserProfile? _profile;
  bool _isLoading = false;
  String? _errorMessage;
  
  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasProfile => _profile != null && _profile!.isComplete;
  
  Future<void> fetchProfile() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      final response = await _api.get(
        AppConstants.profileEndpoint,
        includeAuth: true,
      );
      
      _profile = UserProfile.fromJson(response);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<bool> updateProfile(UserProfile profile) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      await _api.put(
        AppConstants.profileEndpoint,
        profile.toJson(),
        includeAuth: true,
      );
      
      _profile = profile;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  void clearProfile() {
    _profile = null;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}