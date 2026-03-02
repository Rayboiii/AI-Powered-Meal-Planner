import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/meal_plan.dart';
import '../../providers/meal_plan_provider.dart';
import '../../providers/profile_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/skeleton_loader.dart';
import 'generate_plan_screen.dart';
import 'customize_meal_screen.dart';
import '../tracking/meal_log_screen.dart';

class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({Key? key}) : super(key: key);

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  String? _selectedDate;

  @override
  void initState() {
    super.initState();
    _loadMealPlan();
  }

  Future<void> _loadMealPlan() async {
    final provider = Provider.of<MealPlanProvider>(context, listen: false);
    await provider.fetchCurrentPlan();

    if (provider.currentPlan != null) {
      final dates = provider.currentPlan!.mealsByDate.keys.toList();
      if (dates.isNotEmpty) {
        setState(() {
          _selectedDate = dates.first;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Plan'),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              Navigator.of(context)
                  .push(MaterialPageRoute(
                      builder: (_) => const GeneratePlanScreen()))
                  .then((_) => _loadMealPlan());
            },
          ),
        ],
      ),
      body: Consumer<MealPlanProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const MealPlanSkeleton();
          }

          if (provider.errorMessage != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spaceLG),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spaceLG),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLightest,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.restaurant_menu_outlined,
                        size: 48,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceLG),
                    const Text('No Active Meal Plan', style: AppTheme.h3Style),
                    const SizedBox(height: AppTheme.spaceSM),
                    const Text(
                      'Generate a personalized meal plan to get started',
                      style: AppTheme.bodySmallStyle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.spaceXL),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context)
                            .push(MaterialPageRoute(
                                builder: (_) => const GeneratePlanScreen()))
                            .then((_) => _loadMealPlan());
                      },
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Generate Meal Plan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceLG,
                          vertical: AppTheme.spaceMD,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMD),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final mealPlan = provider.currentPlan;
          if (mealPlan == null) {
            return const Center(child: Text('No meal plan available'));
          }

          final mealsByDate = mealPlan.mealsByDate;
          final dates = mealsByDate.keys.toList()..sort();

          return Column(
            children: [
              // Nutritional Target Card
              Container(
                margin: const EdgeInsets.all(AppTheme.spaceMD),
                padding: const EdgeInsets.all(AppTheme.spaceMD),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                  boxShadow: AppTheme.shadowPrimary,
                ),
                child: Column(
                  children: [
                    const Text(
                      'Daily Nutritional Target',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceMD),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildNutrientInfo(
                          'Calories',
                          '${mealPlan.nutritionalTarget['daily_calories']?.toStringAsFixed(0) ?? 'N/A'}',
                          Icons.local_fire_department,
                        ),
                        _buildNutrientInfo(
                          'Protein',
                          '${mealPlan.nutritionalTarget['protein_g']?.toStringAsFixed(0) ?? 'N/A'}g',
                          Icons.egg,
                        ),
                        _buildNutrientInfo(
                          'Carbs',
                          '${mealPlan.nutritionalTarget['carbs_g']?.toStringAsFixed(0) ?? 'N/A'}g',
                          Icons.bakery_dining,
                        ),
                        _buildNutrientInfo(
                          'Fats',
                          '${mealPlan.nutritionalTarget['fats_g']?.toStringAsFixed(0) ?? 'N/A'}g',
                          Icons.water_drop,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Date Selector
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceMD),
                  itemCount: dates.length,
                  itemBuilder: (context, index) {
                    final date = dates[index];
                    final isSelected = date == _selectedDate;
                    final dateTime = DateTime.parse(date);

                    return GestureDetector(
                      onTap: () => setState(() => _selectedDate = date),
                      child: Container(
                        width: 68,
                        margin: const EdgeInsets.only(right: AppTheme.spaceSM),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : AppTheme.surfaceColor,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMD),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primaryColor
                                : AppTheme.borderColor,
                          ),
                          boxShadow:
                              isSelected ? AppTheme.shadowPrimary : AppTheme.shadowSM,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat('EEE').format(dateTime),
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected
                                    ? Colors.white
                                    : AppTheme.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('d').format(dateTime),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              DateFormat('MMM').format(dateTime),
                              style: TextStyle(
                                fontSize: 11,
                                color: isSelected
                                    ? Colors.white70
                                    : AppTheme.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: AppTheme.spaceSM),

              // Meals List
              Expanded(
                child: _selectedDate == null
                    ? const Center(child: Text('Select a date'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(AppTheme.spaceMD),
                        itemCount: mealsByDate[_selectedDate]?.length ?? 0,
                        itemBuilder: (context, index) {
                          final meal = mealsByDate[_selectedDate]![index];
                          return _buildMealCard(meal, _selectedDate!);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _logMealFromPlan(Meal meal) async {
    final profile =
        Provider.of<ProfileProvider>(context, listen: false).profile;
    final calTarget =
        profile?.dailyCalorieTarget?.toDouble() ?? 2000.0;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddMealBottomSheet(
        initialFoodItems: meal.name,
        initialCalories: meal.calories,
        initialProtein: meal.protein,
        initialCarbs: meal.carbs,
        initialFats: meal.fats,
        initialMealType: meal.type,
        dailyCalTarget: calTarget,
      ),
    );
  }

  Widget _buildNutrientInfo(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 22),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildMealCard(meal, String mealDate) {
    Color mealColor;
    IconData mealIcon;

    switch (meal.type.toLowerCase()) {
      case 'breakfast':
        mealIcon = Icons.wb_sunny_outlined;
        mealColor = AppTheme.warningColor;
        break;
      case 'lunch':
        mealIcon = Icons.restaurant_outlined;
        mealColor = AppTheme.successColor;
        break;
      case 'dinner':
        mealIcon = Icons.nightlight_outlined;
        mealColor = AppTheme.primaryDark;
        break;
      case 'snack':
        mealIcon = Icons.cookie_outlined;
        mealColor = AppTheme.secondaryColor;
        break;
      default:
        mealIcon = Icons.fastfood_outlined;
        mealColor = AppTheme.textSecondary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMD),
      decoration: AppTheme.cardDecoration(elevated: true),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spaceSM),
                  decoration: BoxDecoration(
                    color: mealColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  ),
                  child: Icon(mealIcon, color: mealColor, size: 22),
                ),
                const SizedBox(width: AppTheme.spaceMD),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meal.type.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: mealColor,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        meal.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (meal.serving != null) ...[
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: mealColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            meal.serving!,
                            style: TextStyle(fontSize: 11, color: mealColor, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  color: AppTheme.successColor,
                  tooltip: 'Log this meal',
                  onPressed: () => _logMealFromPlan(meal),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  color: AppTheme.primaryColor,
                  tooltip: 'Customize meal',
                  onPressed: () {
                    Navigator.of(context)
                        .push(MaterialPageRoute(
                          builder: (_) => CustomizeMealScreen(
                            mealDate: mealDate,
                            meal: meal,
                          ),
                        ))
                        .then((_) => _loadMealPlan());
                  },
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceMD),
            Divider(color: AppTheme.borderColor, height: 1),
            const SizedBox(height: AppTheme.spaceSM),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMealNutrient(
                    'Cal', meal.calories.toStringAsFixed(0), AppTheme.caloriesColor),
                _buildMealNutrient(
                    'Protein', '${meal.protein.toStringAsFixed(0)}g', AppTheme.proteinColor),
                _buildMealNutrient(
                    'Carbs', '${meal.carbs.toStringAsFixed(0)}g', AppTheme.carbsColor),
                _buildMealNutrient(
                    'Fats', '${meal.fats.toStringAsFixed(0)}g', AppTheme.fatsColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealNutrient(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: AppTheme.captionStyle),
      ],
    );
  }
}
