import 'package:flutter/material.dart';

class AppConstants {
  // API Configuration
  // Override at build time: flutter run --dart-define=BASE_URL=http://192.168.x.x:8000
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://192.168.100.126:8000',
  );
  
  // API Endpoints
  static const String loginEndpoint = '/auth/login';
  static const String registerEndpoint = '/auth/register';
  static const String refreshEndpoint = '/auth/refresh';
  static const String profileEndpoint = '/profile/';
  static const String mealPlanEndpoint = '/meal-plan/generate';
  static const String currentMealPlanEndpoint = '/meal-plan/current';
  static const String customizeMealEndpoint = '/meal-plan/customize';
  static const String logMealEndpoint = '/tracking/log';
  static const String deleteMealEndpoint = '/tracking/log/';
  static const String todayMealsEndpoint = '/tracking/today';
  static const String progressEndpoint = '/tracking/progress';
  static const String foodSearchEndpoint = '/tracking/food-search';
  static const String recentFoodsEndpoint = '/tracking/recent-foods';
  static const String suggestEndpoint = '/tracking/suggest';
  static const String weightEndpoint = '/tracking/weight';
  static const String resetPasswordEndpoint = '/auth/reset-password';
  
  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userEmailKey = 'user_email';
  
  // App Theme Colors
  static const Color primaryColor = Color(0xFF6C63FF);
  static const Color secondaryColor = Color(0xFF00D9B5);
  static const Color backgroundColor = Color(0xFFF8F9FA);
  static const Color errorColor = Color(0xFFFF6B6B);
  static const Color successColor = Color(0xFF51CF66);
  
  // Text Styles
  static const TextStyle headingStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Colors.black87,
  );
  
  static const TextStyle subheadingStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Colors.black87,
  );
  
  static const TextStyle bodyStyle = TextStyle(
    fontSize: 14,
    color: Colors.black54,
  );
}