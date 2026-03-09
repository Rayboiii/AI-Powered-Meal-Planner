import 'package:flutter/material.dart';
import '../models/meal_log.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

class TrackingProvider with ChangeNotifier {
  final ApiService _api = ApiService();
  
  List<MealLog> _todayMeals = [];
  double _totalCalories = 0;
  bool _isLoading = false;
  String? _errorMessage;
  
  List<MealLog> get todayMeals => _todayMeals;
  double get totalCalories => _totalCalories;
  double get totalProtein =>
      _todayMeals.fold(0, (sum, m) => sum + (m.protein ?? 0));
  double get totalCarbs =>
      _todayMeals.fold(0, (sum, m) => sum + (m.carbs ?? 0));
  double get totalFats =>
      _todayMeals.fold(0, (sum, m) => sum + (m.fats ?? 0));
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  Future<void> fetchTodayMeals() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      final response = await _api.get(
        AppConstants.todayMealsEndpoint,
        includeAuth: true,
      );
      
      _todayMeals = (response['logs'] as List)
          .map((log) => MealLog.fromJson(log))
          .toList();
      _totalCalories = response['total_calories'].toDouble();
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<bool> logMeal(MealLog meal) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      await _api.post(
        AppConstants.logMealEndpoint,
        meal.toJson(),
        includeAuth: true,
      );
      
      // Refresh today's meals
      await fetchTodayMeals();
      
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
  
  Future<bool> updateMeal(int logId, MealLog meal) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _api.put(
        '${AppConstants.deleteMealEndpoint}$logId',
        meal.toJson(),
        includeAuth: true,
      );
      await fetchTodayMeals();
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

  Future<bool> deleteMeal(int logId) async {
    // Remove optimistically so the Dismissible widget leaves the tree before
    // the async API call triggers a rebuild (avoids "dismissed widget still
    // in tree" Flutter error).
    _todayMeals.removeWhere((m) => m.logId == logId);
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.delete(
        '${AppConstants.deleteMealEndpoint}$logId',
        includeAuth: true,
      );
      await fetchTodayMeals();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearTracking() {
    _todayMeals = [];
    _totalCalories = 0;
    _errorMessage = null;
    notifyListeners();
  }
}