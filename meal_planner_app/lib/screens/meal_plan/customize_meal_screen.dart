import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/meal_plan.dart';
import '../../providers/meal_plan_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/custom_button.dart';

class CustomizeMealScreen extends StatefulWidget {
  final String mealDate;
  final Meal meal;

  const CustomizeMealScreen({
    Key? key,
    required this.mealDate,
    required this.meal,
  }) : super(key: key);

  @override
  State<CustomizeMealScreen> createState() => _CustomizeMealScreenState();
}

class _CustomizeMealScreenState extends State<CustomizeMealScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _caloriesController;
  late final TextEditingController _proteinController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatsController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.meal.name);
    _caloriesController =
        TextEditingController(text: widget.meal.calories.toStringAsFixed(0));
    _proteinController =
        TextEditingController(text: widget.meal.protein.toStringAsFixed(0));
    _carbsController =
        TextEditingController(text: widget.meal.carbs.toStringAsFixed(0));
    _fatsController =
        TextEditingController(text: widget.meal.fats.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final newMealData = {
      'name': _nameController.text.trim(),
      'calories': double.parse(_caloriesController.text.trim()),
      'protein': double.parse(_proteinController.text.trim()),
      'carbs': double.parse(_carbsController.text.trim()),
      'fats': double.parse(_fatsController.text.trim()),
    };

    final provider = Provider.of<MealPlanProvider>(context, listen: false);
    final success = await provider.customizeMeal(
      widget.mealDate,
      widget.meal.type,
      newMealData,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Meal updated successfully'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Failed to update meal'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mealColor = _mealColor(widget.meal.type);
    final mealIcon = _mealIcon(widget.meal.type);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customize Meal'),
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
              // Meal type header card
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceMD),
                decoration: AppTheme.cardDecoration(elevated: false),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spaceMD),
                      decoration: BoxDecoration(
                        color: mealColor.withOpacity(0.1),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMD),
                      ),
                      child: Icon(mealIcon, color: mealColor, size: 26),
                    ),
                    const SizedBox(width: AppTheme.spaceMD),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.meal.type.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: mealColor,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(widget.mealDate, style: AppTheme.bodySmallStyle),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spaceXL),

              // Meal name
              const Text(
                'Meal Name',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: AppTheme.spaceSM),
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration('e.g. Grilled Chicken Salad'),
                style: const TextStyle(
                  fontSize: 15,
                  color: AppTheme.textPrimary,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a meal name' : null,
                textCapitalization: TextCapitalization.words,
              ),

              const SizedBox(height: AppTheme.spaceLG),

              // Nutritional values
              const Text(
                'Nutritional Information',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: AppTheme.spaceSM),

              Row(
                children: [
                  Expanded(
                    child: _buildNutrientField(
                      controller: _caloriesController,
                      label: 'Calories',
                      unit: 'kcal',
                      icon: Icons.local_fire_department_outlined,
                      iconColor: AppTheme.caloriesColor,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceSM),
                  Expanded(
                    child: _buildNutrientField(
                      controller: _proteinController,
                      label: 'Protein',
                      unit: 'g',
                      icon: Icons.egg_outlined,
                      iconColor: AppTheme.proteinColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceSM),
              Row(
                children: [
                  Expanded(
                    child: _buildNutrientField(
                      controller: _carbsController,
                      label: 'Carbs',
                      unit: 'g',
                      icon: Icons.bakery_dining_outlined,
                      iconColor: AppTheme.carbsColor,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceSM),
                  Expanded(
                    child: _buildNutrientField(
                      controller: _fatsController,
                      label: 'Fats',
                      unit: 'g',
                      icon: Icons.water_drop_outlined,
                      iconColor: AppTheme.fatsColor,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppTheme.space2XL),

              CustomButton(
                text: 'Save Changes',
                onPressed: _save,
                isLoading: _isSaving,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNutrientField({
    required TextEditingController controller,
    required String label,
    required String unit,
    required IconData icon,
    required Color iconColor,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
      decoration: _inputDecoration(label).copyWith(
        prefixIcon: Icon(icon, color: iconColor, size: 20),
        suffixText: unit,
        suffixStyle: AppTheme.captionStyle,
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textSecondary),
        hintText: null,
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Required';
        if (double.tryParse(v.trim()) == null) return 'Invalid number';
        if (double.parse(v.trim()) < 0) return 'Must be ≥ 0';
        return null;
      },
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppTheme.textHint),
      filled: true,
      fillColor: AppTheme.surfaceColor,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        borderSide: const BorderSide(color: AppTheme.errorColor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        borderSide: const BorderSide(color: AppTheme.errorColor, width: 2),
      ),
    );
  }

  IconData _mealIcon(String type) {
    switch (type.toLowerCase()) {
      case 'breakfast':
        return Icons.wb_sunny_outlined;
      case 'lunch':
        return Icons.restaurant_outlined;
      case 'dinner':
        return Icons.nightlight_outlined;
      case 'snack':
        return Icons.cookie_outlined;
      default:
        return Icons.fastfood_outlined;
    }
  }

  Color _mealColor(String type) {
    switch (type.toLowerCase()) {
      case 'breakfast':
        return AppTheme.warningColor;
      case 'lunch':
        return AppTheme.successColor;
      case 'dinner':
        return AppTheme.primaryDark;
      case 'snack':
        return AppTheme.secondaryColor;
      default:
        return AppTheme.textSecondary;
    }
  }
}
