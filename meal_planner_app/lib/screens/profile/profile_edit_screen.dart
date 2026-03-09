import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_profile.dart';
import '../../providers/profile_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/validators.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class _BmiStatus {
  final String label;
  final Color color;
  final Color bgColor;
  const _BmiStatus(this.label, this.color, this.bgColor);
}

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({Key? key}) : super(key: key);

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  Set<String> _selectedPreferences = {};
  Set<String> _selectedAllergens = {};

  String _selectedGender = 'male';
  String? _selectedActivityLevel;
  String? _selectedHealthGoal;

  static const List<String> _preferenceOptions = [
    'Vegetarian', 'Vegan', 'Keto', 'Gluten-Free', 'Dairy-Free',
    'High-Protein', 'Low-Carb', 'Paleo', 'Mediterranean',
  ];

  static const List<String> _allergenOptions = [
    'Nuts', 'Dairy', 'Gluten', 'Eggs', 'Fish', 'Shellfish', 'Soy',
  ];

  static const Map<String, List<String>> _prefConflicts = {
    'Vegan':        ['High-Protein', 'Keto'],
    'High-Protein': ['Vegan'],
    'Keto':         ['Vegan', 'Low-Carb'],
    'Low-Carb':     ['Keto'],
  };

  static const Map<String, List<String>> _prefToAllergenConflicts = {
    'Vegan':       ['Dairy', 'Eggs'],
    'Dairy-Free':  ['Dairy'],
    'Gluten-Free': ['Gluten'],
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

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _weightController.addListener(_onBodyMetricsChanged);
    _heightController.addListener(_onBodyMetricsChanged);
  }

  Set<String> _parseCsvToSet(String csv, List<String> validOptions) {
    if (csv.isEmpty || csv == 'none') return {};
    final tokens = csv.split(RegExp(r'[,;]')).map((e) => e.trim().toLowerCase());
    return validOptions
        .where((opt) => tokens.contains(opt.toLowerCase()))
        .toSet();
  }

  void _loadProfile() {
    final profile =
        Provider.of<ProfileProvider>(context, listen: false).profile;
    if (profile != null) {
      _nameController.text = profile.name ?? '';
      _ageController.text = profile.age?.toString() ?? '';
      _weightController.text = profile.weight?.toString() ?? '';
      _heightController.text = profile.height?.toString() ?? '';
      _selectedPreferences = _parseCsvToSet(
          profile.dietaryPreferences ?? '', _preferenceOptions);
      _selectedAllergens =
          _parseCsvToSet(profile.allergies ?? '', _allergenOptions);
      _selectedGender = profile.gender ?? 'male';
      _selectedActivityLevel = profile.activityLevel;
      _selectedHealthGoal = profile.healthGoals;
    }
  }

  @override
  void dispose() {
    _weightController.removeListener(_onBodyMetricsChanged);
    _heightController.removeListener(_onBodyMetricsChanged);
    _nameController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_formKey.currentState!.validate()) {
      final profile = UserProfile(
        name: _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
        age: int.tryParse(_ageController.text),
        weight: double.parse(_weightController.text),
        height: double.parse(_heightController.text),
        gender: _selectedGender,
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
      final success = await profileProvider.updateProfile(profile);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.of(context).pop();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                profileProvider.errorMessage ?? 'Failed to update profile'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _onBodyMetricsChanged() => setState(() {});

  double? _computeBmi() {
    final weight = double.tryParse(_weightController.text);
    final height = double.tryParse(_heightController.text);
    if (weight == null || height == null || height <= 0) return null;
    return weight / ((height / 100) * (height / 100));
  }

  _BmiStatus _getBmiStatus(double bmi) {
    if (bmi < 18.5) {
      return const _BmiStatus('Underweight', AppTheme.infoColor, Color(0xFFE8F4FD));
    } else if (bmi < 25.0) {
      return const _BmiStatus('Normal', AppTheme.successColor, Color(0xFFEAFAF1));
    } else if (bmi < 30.0) {
      return const _BmiStatus('Overweight', AppTheme.warningColor, Color(0xFFFFF3E0));
    }
    return const _BmiStatus('Obese', AppTheme.errorColor, Color(0xFFFFEBEE));
  }

  Widget _buildBmiCard() {
    final bmi = _computeBmi();
    if (bmi == null) return const SizedBox.shrink();
    final status = _getBmiStatus(bmi);
    final fraction = ((bmi - 15.0) / 25.0).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: status.bgColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: status.color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.monitor_weight_outlined, color: status.color, size: 18),
              const SizedBox(width: 6),
              const Text(
                'Body Mass Index',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: status.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: status.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                bmi.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: status.color,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  'kg/m²',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Stack(
            alignment: Alignment.centerLeft,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  height: 8,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF5B9FED),
                        Color(0xFF51CF66),
                        Color(0xFFFFB84D),
                        Color(0xFFFF6B6B),
                      ],
                    ),
                  ),
                ),
              ),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: fraction,
                child: Container(
                  height: 8,
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: 3,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('15', style: TextStyle(fontSize: 10, color: AppTheme.textTertiary)),
              Text('18.5', style: TextStyle(fontSize: 10, color: AppTheme.textTertiary)),
              Text('25', style: TextStyle(fontSize: 10, color: AppTheme.textTertiary)),
              Text('30', style: TextStyle(fontSize: 10, color: AppTheme.textTertiary)),
              Text('40+', style: TextStyle(fontSize: 10, color: AppTheme.textTertiary)),
            ],
          ),
        ],
      ),
    );
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
        _selectedPreferences.removeAll(_prefConflicts[option] ?? []);
        _selectedAllergens.removeAll(_prefToAllergenConflicts[option] ?? []);
      } else {
        _selectedPreferences.remove(option);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryDark, AppTheme.primaryColor],
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spaceLG),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                      hint: 'Enter your weight',
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
                      hint: 'Enter your height',
                      controller: _heightController,
                      keyboardType: TextInputType.number,
                      validator: (value) =>
                          Validators.validateNumber(value, 'Height'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceMD),

              _buildBmiCard(),
              const SizedBox(height: AppTheme.spaceMD),

              const Text(
                'Biological Sex',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Used to calculate your accurate calorie target',
                style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
              ),
              const SizedBox(height: AppTheme.spaceSM),
              Row(
                children: [
                  {'value': 'male',   'label': 'Male',   'icon': Icons.male},
                  {'value': 'female', 'label': 'Female', 'icon': Icons.female},
                  {'value': 'other',  'label': 'Other',  'icon': Icons.person},
                ].map((opt) {
                  final selected = _selectedGender == opt['value'];
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedGender = opt['value'] as String),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? AppTheme.primaryColor : Colors.transparent,
                          border: Border.all(
                            color: selected ? AppTheme.primaryColor : AppTheme.borderColor,
                          ),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              opt['icon'] as IconData,
                              size: 20,
                              color: selected ? Colors.white : AppTheme.textSecondary,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              opt['label'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: selected ? Colors.white : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
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
                label: 'Dietary Preferences',
                options: _preferenceOptions,
                selected: _selectedPreferences,
                disabled: _disabledPreferences,
                onChanged: _onPreferenceChanged,
              ),
              const SizedBox(height: AppTheme.spaceMD),

              _buildChipGroup(
                label: 'Allergies',
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
                    text: 'Save Changes',
                    onPressed: _handleSave,
                    isLoading: profileProvider.isLoading,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
