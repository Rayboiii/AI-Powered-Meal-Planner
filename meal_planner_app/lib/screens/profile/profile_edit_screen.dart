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

  String? _selectedActivityLevel;
  String? _selectedHealthGoal;

  static const List<String> _preferenceOptions = [
    'Vegetarian', 'Vegan', 'Keto', 'Gluten-Free', 'Dairy-Free',
    'High-Protein', 'Low-Carb', 'Paleo', 'Mediterranean',
  ];

  static const List<String> _allergenOptions = [
    'Nuts', 'Dairy', 'Gluten', 'Eggs', 'Fish', 'Shellfish', 'Soy',
  ];

  final List<String> _activityLevels = [
    'sedentary',
    'lightly_active',
    'moderately_active',
    'very_active',
    'extra_active',
  ];

  final List<String> _healthGoals = [
    'lose weight',
    'maintain weight',
    'gain weight',
    'build muscle',
  ];

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
        age: int.parse(_ageController.text),
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

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: AppTheme.surfaceColor,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        borderSide: const BorderSide(color: AppTheme.borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        borderSide: const BorderSide(color: AppTheme.borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
      ),
    );
  }

  Widget _buildChipGroup({
    required String label,
    required List<String> options,
    required Set<String> selected,
    required void Function(String, bool) onChanged,
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
            return FilterChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (val) => onChanged(option, val),
              selectedColor: AppTheme.primaryColor.withOpacity(0.15),
              checkmarkColor: AppTheme.primaryColor,
              labelStyle: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
              ),
              side: BorderSide(
                color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
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
                label: 'Age',
                hint: 'Enter your age',
                controller: _ageController,
                keyboardType: TextInputType.number,
                validator: (value) =>
                    Validators.validateNumber(value, 'Age'),
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
                'Activity Level',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: AppTheme.spaceSM),
              DropdownButtonFormField<String>(
                value: _selectedActivityLevel,
                decoration: _dropdownDecoration(),
                items: _activityLevels.map((level) {
                  return DropdownMenuItem(
                    value: level,
                    child: Text(
                      level.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) =>
                    setState(() => _selectedActivityLevel = value),
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
              DropdownButtonFormField<String>(
                value: _selectedHealthGoal,
                decoration: _dropdownDecoration(),
                items: _healthGoals.map((goal) {
                  return DropdownMenuItem(
                    value: goal,
                    child: Text(
                      goal.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) =>
                    setState(() => _selectedHealthGoal = value),
              ),
              const SizedBox(height: AppTheme.spaceMD),

              _buildChipGroup(
                label: 'Dietary Preferences',
                options: _preferenceOptions,
                selected: _selectedPreferences,
                onChanged: (option, val) => setState(() {
                  val ? _selectedPreferences.add(option) : _selectedPreferences.remove(option);
                }),
              ),
              const SizedBox(height: AppTheme.spaceMD),

              _buildChipGroup(
                label: 'Allergies',
                options: _allergenOptions,
                selected: _selectedAllergens,
                onChanged: (option, val) => setState(() {
                  val ? _selectedAllergens.add(option) : _selectedAllergens.remove(option);
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
