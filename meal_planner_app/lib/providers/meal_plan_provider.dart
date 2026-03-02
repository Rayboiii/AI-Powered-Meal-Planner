import 'package:flutter/material.dart';
import '../models/meal_plan.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

class MealPlanProvider with ChangeNotifier {
  final ApiService _api = ApiService();
  
  MealPlan? _currentPlan;
  bool _isLoading = false;
  String? _errorMessage;
  
  MealPlan? get currentPlan => _currentPlan;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasPlan => _currentPlan != null;
  
  Future<void> fetchCurrentPlan() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.get(
        AppConstants.currentMealPlanEndpoint,
        includeAuth: true,
      );
      _currentPlan = MealPlan.fromJson(response);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _currentPlan = null;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> generateMealPlan(String startDate, int durationDays) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.post(
        AppConstants.mealPlanEndpoint,
        {
          'start_date': startDate,
          'duration_days': durationDays,
        },
        includeAuth: true,
      );

      await fetchCurrentPlan();
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

  Future<bool> customizeMeal(
    String mealDate,
    String mealType,
    Map<String, dynamic> newMealData,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.put(
        AppConstants.customizeMealEndpoint,
        {
          'meal_date': mealDate,
          'meal_type': mealType,
          'new_meal_data': newMealData,
        },
        includeAuth: true,
      );

      await fetchCurrentPlan();
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

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}