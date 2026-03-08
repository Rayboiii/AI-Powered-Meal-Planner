import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_profile.dart';
import '../../providers/profile_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/validators.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../home/home_screen.dart';
import '../auth/login_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({Key? key}) : super(key: key);

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  Set<String> _selectedPreferences = {};
  Set<String> _selectedAllergens = {};

  String? _selectedActivityLevel;
  String? _selectedHealthGoal;

  static const List<String> _preferenceOptions = [
    'Vegetarian', 'Vegan', 'Keto', 'Gluten-Free', 'Dairy-Free',
    'High-Protein', 'Low-Carb', 'Paleo', 'Mediterranean',
  ];

  static const List<String> _allergenOptions = [
    'Nuts', 'Dairy', 'Gluten', 'Eggs', 'Fish', 'Shellfish', 'Soy',
  ];

  // When a preference is selected, these other preferences are incompatible
  static const Map<String, List<String>> _prefConflicts = {
    'Vegan':        ['High-Protein', 'Keto'],
    'High-Protein': ['Vegan'],
    'Keto':         ['Vegan', 'Low-Carb'],
    'Low-Carb':     ['Keto'],
  };

  // When a preference is selected, these allergens are already excluded
  static const Map<String, List<String>> _prefToAllergenConflicts = {
    'Vegan':      ['Dairy', 'Eggs'],
    'Dairy-Free': ['Dairy'],
    'Gluten-Free':['Gluten'],
  };

  static const _activityLevelInfo = <String, Map<String, dynamic>>{
    'sedentary': {
      'label': 'Sedentary',
      'desc': 'Little or no exercise, mostly desk work',
      'icon': Icons.weekend,
    },
    'lightly_active': {
      'label': 'Lightly Active',
      'desc': 'Light exercise or walking 1–3 days/week',
      'icon': Icons.directions_walk,
    },
    'moderately_active': {
      'label': 'Moderately Active',
      'desc': 'Moderate exercise or sports 3–5 days/week',
      'icon': Icons.directions_bike,
    },
    'very_active': {
      'label': 'Very Active',
      'desc': 'Hard exercise or sports 6–7 days/week',
      'icon': Icons.fitness_center,
    },
    'extra_active': {
      'label': 'Extra Active',
      'desc': 'Very hard exercise plus a physical job',
      'icon': Icons.sports,
    },
  };

  static const _healthGoalInfo = <String, Map<String, dynamic>>{
    'lose weight': {
      'label': 'Lose Weight',
      'desc': 'Calorie deficit to reduce body fat',
      'icon': Icons.trending_down,
    },
    'maintain weight': {
      'label': 'Maintain Weight',
      'desc': 'Balance calorie intake with energy output',
      'icon': Icons.trending_flat,
    },
    'gain weight': {
      'label': 'Gain Weight',
      'desc': 'Calorie surplus for healthy mass gain',
      'icon': Icons.trending_up,
    },
    'build muscle': {
      'label': 'Build Muscle',
      'desc': 'High-protein focus with strength training',
      'icon': Icons.fitness_center,
    },
  };

  Set<String> get _disabledPreferences {
    final disabled = <String>{};
    for (final sel in _selectedPreferences) {
      disabled.addAll(_prefConflicts[sel] ?? []);
    }
    return disabled;
  }

  Set<String> get _disabledAllergens {
    final disabled = <String>{};
    for (final sel in _selectedPreferences) {
      disabled.addAll(_prefToAllergenConflicts[sel] ?? []);
    }
    return disabled;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedActivityLevel == null || _selectedHealthGoal == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select activity level and health goal'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }

      final profile = UserProfile(
        name: _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
        age: int.tryParse(_ageController.text),
        weight: double.parse(_weightController.text),
        height: double.parse(_heightController.text),
        dietaryPreferences: _selectedPreferences.isEmpty
            ? 'none'
            : _selectedPreferences.map((e) => e.toLowerCase()).join(', '),
        allergies: _selectedAllergens.isEmpty
            ? 'none'
            : _selectedAllergens.map((e) => e.toLowerCase()).join(', '),
        healthGoals: _selectedHealthGoal,
        activityLevel: _selectedActivityLevel,
      );

      final profileProvider =
          Provider.of<ProfileProvider>(context, listen: false);

      try {
        final success = await profileProvider.updateProfile(profile);

        if (success && mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  profileProvider.errorMessage ?? 'Failed to save profile'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      } catch (e) {
        final errorMessage = e.toString().toLowerCase();
        if (errorMessage.contains('session expired') ||
            errorMessage.contains('401') ||
            errorMessage.contains('invalid or expired token') ||
            errorMessage.contains('could not validate credentials') ||
            errorMessage.contains('authentication failed')) {
          if (mounted) {
            final authProvider =
                Provider.of<AuthProvider>(context, listen: false);
            await authProvider.logout();

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Session expired. Please login again.'),
                backgroundColor: AppTheme.errorColor,
                duration: Duration(seconds: 3),
              ),
            );

            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Error: ${e.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        ),
        title: const Text('Logout', style: AppTheme.h3Style),
        content: const Text(
          'Are you sure you want to logout? Your profile will not be saved.',
          style: AppTheme.bodySmallStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final profileProvider =
          Provider.of<ProfileProvider>(context, listen: false);
      profileProvider.clearProfile();
      await authProvider.logout();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  Widget _buildOptionCards({
    required Map<String, Map<String, dynamic>> info,
    required String? selected,
    required void Function(String) onSelect,
  }) {
    return Column(
      children: info.entries.map((entry) {
        final key = entry.key;
        final meta = entry.value;
        final isSelected = key == selected;
        return GestureDetector(
          onTap: () => onSelect(key),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryColor.withOpacity(0.08)
                  : AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              border: Border.all(
                color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryColor.withOpacity(0.15)
                        : AppTheme.borderColor.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    meta['icon'] as IconData,
                    size: 20,
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meta['label'] as String,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? AppTheme.primaryColor
                              : AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        meta['desc'] as String,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChipGroup({
    required String label,
    required List<String> options,
    required Set<String> selected,
    required void Function(String, bool) onChanged,
    Set<String> disabled = const {},
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: AppTheme.spaceSM),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selected.contains(option);
            final isDisabled = disabled.contains(option);
            return FilterChip(
              label: Text(option),
              selected: isSelected && !isDisabled,
              onSelected: isDisabled ? null : (val) => onChanged(option, val),
              selectedColor: AppTheme.primaryColor.withOpacity(0.15),
              checkmarkColor: AppTheme.primaryColor,
              disabledColor: AppTheme.surfaceColor,
              labelStyle: TextStyle(
                fontSize: 13,
                fontWeight: isSelected && !isDisabled
                    ? FontWeight.w600
                    : FontWeight.w400,
                color: isDisabled
                    ? AppTheme.textTertiary
                    : isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondary,
              ),
              side: BorderSide(
                color: isDisabled
                    ? AppTheme.borderColor.withOpacity(0.4)
                    : isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.borderColor,
              ),
              backgroundColor: AppTheme.surfaceColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _onPreferenceChanged(String option, bool val) {
    setState(() {
      if (val) {
        _selectedPreferences.add(option);
        // Auto-remove conflicting preferences
        _selectedPreferences.removeAll(_prefConflicts[option] ?? []);
        // Auto-remove allergens that are now redundant
        _selectedAllergens.removeAll(_prefToAllergenConflicts[option] ?? []);
      } else {
        _selectedPreferences.remove(option);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Column(
        children: [
          // Header
          SafeArea(
            bottom: false,
            child: SizedBox(
              height: 160,
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusLG),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.3)),
                          ),
                          child: const Icon(Icons.person_outline,
                              size: 36, color: Colors.white),
                        ),
                        const SizedBox(height: AppTheme.spaceSM),
                        const Text(
                          'Setup Your Profile',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.logout,
                          color: Colors.white, size: 22),
                      tooltip: 'Logout',
                      onPressed: _handleLogout,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Form panel
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppTheme.radius2XL),
                  topRight: Radius.circular(AppTheme.radius2XL),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(AppTheme.spaceLG,
                    AppTheme.spaceXL, AppTheme.spaceLG, AppTheme.spaceLG),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tell us about yourself',
                          style: AppTheme.h2Style),
                      const SizedBox(height: 6),
                      const Text(
                        'This helps us create a personalized meal plan for you',
                        style: AppTheme.bodySmallStyle,
                      ),
                      const SizedBox(height: AppTheme.spaceXL),

                      CustomTextField(
                        label: 'Name (Optional)',
                        hint: 'e.g., Alex',
                        controller: _nameController,
                        keyboardType: TextInputType.name,
                      ),
                      const SizedBox(height: AppTheme.spaceMD),

                      CustomTextField(
                        label: 'Age (Optional)',
                        hint: 'e.g., 25',
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: AppTheme.spaceMD),

                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              label: 'Weight (kg)',
                              hint: 'e.g., 70',
                              controller: _weightController,
                              keyboardType: TextInputType.number,
                              validator: (value) =>
                                  Validators.validateNumber(value, 'Weight'),
                            ),
                          ),
                          const SizedBox(width: AppTheme.spaceSM),
                          Expanded(
                            child: CustomTextField(
                              label: 'Height (cm)',
                              hint: 'e.g., 170',
                              controller: _heightController,
                              keyboardType: TextInputType.number,
                              validator: (value) =>
                                  Validators.validateNumber(value, 'Height'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spaceMD),

                      const Text(
                        'Activity Level',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spaceSM),
                      _buildOptionCards(
                        info: _activityLevelInfo,
                        selected: _selectedActivityLevel,
                        onSelect: (v) => setState(() => _selectedActivityLevel = v),
                      ),
                      const SizedBox(height: AppTheme.spaceMD),

                      const Text(
                        'Health Goal',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spaceSM),
                      _buildOptionCards(
                        info: _healthGoalInfo,
                        selected: _selectedHealthGoal,
                        onSelect: (v) => setState(() => _selectedHealthGoal = v),
                      ),
                      const SizedBox(height: AppTheme.spaceMD),

                      _buildChipGroup(
                        label: 'Dietary Preferences (Optional)',
                        options: _preferenceOptions,
                        selected: _selectedPreferences,
                        disabled: _disabledPreferences,
                        onChanged: _onPreferenceChanged,
                      ),
                      const SizedBox(height: AppTheme.spaceMD),

                      _buildChipGroup(
                        label: 'Allergies (Optional)',
                        options: _allergenOptions,
                        selected: _selectedAllergens,
                        disabled: _disabledAllergens,
                        onChanged: (option, val) => setState(() {
                          val
                              ? _selectedAllergens.add(option)
                              : _selectedAllergens.remove(option);
                        }),
                      ),
                      const SizedBox(height: AppTheme.spaceXL),

                      Consumer<ProfileProvider>(
                        builder: (context, profileProvider, child) {
                          return CustomButton(
                            text: 'Save Profile',
                            onPressed: _handleSave,
                            isLoading: profileProvider.isLoading,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
