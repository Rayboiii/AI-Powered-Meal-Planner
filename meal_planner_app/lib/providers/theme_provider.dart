import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDark = false;

  bool get isDark => _isDark;

  Future<void> load() async {
    _isDark = await StorageService().getDarkMode();
    notifyListeners();
  }

  Future<void> toggle() async {
    _isDark = !_isDark;
    await StorageService().saveDarkMode(_isDark);
    notifyListeners();
  }
}
