import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/meal_log.dart';
import '../../providers/tracking_provider.dart';
import '../../providers/profile_provider.dart';
import '../../services/api_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/skeleton_loader.dart';

class MealLogScreen extends StatefulWidget {
  const MealLogScreen({Key? key}) : super(key: key);

  @override
  State<MealLogScreen> createState() => _MealLogScreenState();
}

class _MealLogScreenState extends State<MealLogScreen> {
  Map<String, dynamic>? _suggestion;
  bool _loadingSuggestion = false;

  // Personalised daily targets from the suggest endpoint — used as a fallback
  // when ProfileProvider hasn't loaded computed targets yet.
  double? _cachedCalTarget;
  double? _cachedCalMin;
  double? _cachedCalMax;
  double? _cachedProteinTarget;
  double? _cachedCarbsTarget;
  double? _cachedFatsTarget;

  // ── Date navigation ──────────────────────────────────────────────────────
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _historyMeals = [];
  bool _loadingHistory = false;

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  @override
  void initState() {
    super.initState();
    _loadTodayMeals();
    _fetchSuggestion();
  }

  Future<void> _loadTodayMeals() async {
    final provider = Provider.of<TrackingProvider>(context, listen: false);
    await provider.fetchTodayMeals();
  }

  Future<void> _loadMealsForDate() async {
    setState(() => _loadingHistory = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final data = await ApiService().get(
        AppConstants.mealsDateEndpoint,
        includeAuth: true,
        queryParams: {'date': dateStr},
      );
      if (mounted) {
        setState(() {
          _historyMeals = (data['logs'] as List<dynamic>?)
                  ?.map((e) => Map<String, dynamic>.from(e as Map))
                  .toList() ??
              [];
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingHistory = false);
  }

  void _changeDate(int days) {
    final newDate = _selectedDate.add(Duration(days: days));
    if (newDate.isAfter(DateTime.now())) return;
    setState(() {
      _selectedDate = newDate;
      _historyMeals = [];
    });
    if (_isToday) {
      _loadTodayMeals();
      _fetchSuggestion();
    } else {
      _loadMealsForDate();
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppTheme.primaryColor,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
        _historyMeals = [];
      });
      if (_isToday) {
        _loadTodayMeals();
        _fetchSuggestion();
      } else {
        _loadMealsForDate();
      }
    }
  }

  Future<void> _fetchSuggestion() async {
    if (!mounted) return;
    setState(() => _loadingSuggestion = true);
    try {
      final data = await ApiService().get(
        AppConstants.suggestEndpoint,
        includeAuth: true,
      );
      if (mounted) {
        setState(() {
          _suggestion = data;
          // Cache the targets returned by the backend so the summary card
          // always shows personalised values even if the profile GET failed.
          final t = data['targets'] as Map<String, dynamic>?;
          if (t != null) {
            _cachedCalTarget     = (t['calories']     as num?)?.toDouble();
            _cachedCalMin        = (t['calories_min'] as num?)?.toDouble();
            _cachedCalMax        = (t['calories_max'] as num?)?.toDouble();
            _cachedProteinTarget = (t['protein']      as num?)?.toDouble();
            _cachedCarbsTarget   = (t['carbs']        as num?)?.toDouble();
            _cachedFatsTarget    = (t['fats']         as num?)?.toDouble();
          }
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingSuggestion = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: Colors.white),
              onPressed: () => _changeDate(-1),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            GestureDetector(
              onTap: _pickDate,
              child: Row(
                children: [
                  Text(
                    _isToday
                        ? 'Today'
                        : DateFormat('MMM d, yyyy').format(_selectedDate),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.calendar_today_outlined,
                      size: 14, color: Colors.white70),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.chevron_right,
                  color: _isToday
                      ? Colors.white.withOpacity(0.3)
                      : Colors.white),
              onPressed: _isToday ? null : () => _changeDate(1),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
        centerTitle: true,
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
      body: RefreshIndicator(
        color: AppTheme.primaryColor,
        onRefresh: () async {
          if (_isToday) {
            await _loadTodayMeals();
            _fetchSuggestion();
          } else {
            await _loadMealsForDate();
          }
        },
        child: Consumer2<TrackingProvider, ProfileProvider>(
          builder: (context, tracking, profileProv, child) {
            if (_isToday && tracking.isLoading && tracking.todayMeals.isEmpty) {
              return const MealLogSkeleton();
            }

            final profile = profileProv.profile;
            // Priority: profile-computed targets → suggest-endpoint cache → defaults
            final calTarget     = profile?.dailyCalorieTarget?.toDouble() ?? _cachedCalTarget     ?? 2000.0;
            final proteinTarget = profile?.dailyProteinTarget              ?? _cachedProteinTarget ?? 150.0;
            final carbsTarget   = profile?.dailyCarbsTarget                ?? _cachedCarbsTarget   ?? 250.0;
            final fatsTarget    = profile?.dailyFatsTarget                 ?? _cachedFatsTarget    ?? 65.0;

            // For history mode, compute totals from fetched meals
            final displayMeals = _isToday ? tracking.todayMeals : null;
            final histCal  = _historyMeals.fold(0.0, (s, m) => s + (m['calories'] as num? ?? 0).toDouble());
            final histPro  = _historyMeals.fold(0.0, (s, m) => s + (m['protein']  as num? ?? 0).toDouble());
            final histCarb = _historyMeals.fold(0.0, (s, m) => s + (m['carbs']    as num? ?? 0).toDouble());
            final histFat  = _historyMeals.fold(0.0, (s, m) => s + (m['fats']     as num? ?? 0).toDouble());

            final shownCal  = _isToday ? tracking.totalCalories  : histCal;
            final shownPro  = _isToday ? tracking.totalProtein   : histPro;
            final shownCarb = _isToday ? tracking.totalCarbs     : histCarb;
            final shownFat  = _isToday ? tracking.totalFats      : histFat;
            final shownCount = _isToday
                ? tracking.todayMeals.length
                : _historyMeals.length;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppTheme.spaceMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── SUMMARY CARD ───────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spaceMD),
                    decoration: AppTheme.cardDecoration(elevated: true),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(_isToday ? "Today's Total" : "Day's Total",
                                style: AppTheme.h3Style),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryLightest,
                                borderRadius: BorderRadius.circular(
                                    AppTheme.radiusSM),
                              ),
                              child: Text(
                                '$shownCount meals',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spaceMD),

                        // Calorie ring + macro bars
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Calorie ring
                            _CalorieRing(
                              consumed: shownCal,
                              target: calTarget,
                              targetMin: _cachedCalMin,
                              targetMax: _cachedCalMax,
                            ),
                            const SizedBox(width: AppTheme.spaceMD),

                            // Macro bars
                            Expanded(
                              child: Column(
                                children: [
                                  _MacroBar(
                                    label: 'Protein',
                                    consumed: shownPro,
                                    target: proteinTarget,
                                    color: AppTheme.proteinColor,
                                  ),
                                  const SizedBox(height: 10),
                                  _MacroBar(
                                    label: 'Carbs',
                                    consumed: shownCarb,
                                    target: carbsTarget,
                                    color: AppTheme.carbsColor,
                                  ),
                                  const SizedBox(height: 10),
                                  _MacroBar(
                                    label: 'Fats',
                                    consumed: shownFat,
                                    target: fatsTarget,
                                    color: AppTheme.fatsColor,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppTheme.spaceLG),

                  // ── AI SUGGESTION CARD (today only) ───────────────────
                  if (_isToday && _loadingSuggestion)
                    const Padding(
                      padding: EdgeInsets.only(bottom: AppTheme.spaceLG),
                      child: LinearProgressIndicator(
                        minHeight: 2,
                        color: AppTheme.primaryColor,
                        backgroundColor: AppTheme.primaryLightest,
                      ),
                    ),
                  if (_isToday &&
                      !_loadingSuggestion &&
                      _suggestion != null &&
                      _suggestion!['status'] == 'ok') ...[
                    _SuggestionCard(
                      suggestion: _suggestion!,
                      onLogTap: (meal) =>
                          _showAddMealDialog(context, prefill: meal),
                    ),
                    const SizedBox(height: AppTheme.spaceLG),
                  ],

                  // ── MEAL LIST HEADER ───────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_isToday ? "Today's Meals" : "Meals on this Day",
                          style: AppTheme.h3Style),
                      if (_isToday)
                        ElevatedButton.icon(
                          onPressed: () => _showAddMealDialog(context),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Log Meal'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spaceMD,
                              vertical: AppTheme.spaceSM,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMD),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: AppTheme.spaceMD),

                  // History loading indicator
                  if (_loadingHistory)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator(
                          color: AppTheme.primaryColor)),
                    )
                  else if (_isToday && tracking.todayMeals.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.space2XL),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppTheme.spaceLG),
                              decoration: const BoxDecoration(
                                color: AppTheme.primaryLightest,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.restaurant_menu_outlined,
                                size: 40,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spaceMD),
                            const Text(
                              'No meals logged today',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spaceSM),
                            const Text(
                              'Tap "Log Meal" to track what you ate',
                              style: AppTheme.bodySmallStyle,
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (!_isToday && _historyMeals.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.space2XL),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppTheme.spaceLG),
                              decoration: const BoxDecoration(
                                color: AppTheme.primaryLightest,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.history_outlined,
                                size: 40,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spaceMD),
                            const Text(
                              'No meals logged on this day',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_isToday)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: tracking.todayMeals.length,
                      itemBuilder: (context, index) {
                        final log = tracking.todayMeals[index];
                        return _SwipeToDeleteMealCard(
                          log: log,
                          onDeleted: () async {
                            if (log.logId == null) return;
                            final provider = Provider.of<TrackingProvider>(
                                context,
                                listen: false);
                            final success =
                                await provider.deleteMeal(log.logId!);
                            if (!success && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(provider.errorMessage ??
                                      'Failed to delete meal'),
                                  backgroundColor: AppTheme.errorColor,
                                ),
                              );
                            }
                            if (success) _fetchSuggestion();
                          },
                        );
                      },
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _historyMeals.length,
                      itemBuilder: (context, index) {
                        final m = _historyMeals[index];
                        return _HistoryMealCard(meal: m);
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showAddMealDialog(BuildContext context,
      {Map<String, dynamic>? prefill}) async {
    final profile =
        Provider.of<ProfileProvider>(context, listen: false).profile;
    final calTarget = profile?.dailyCalorieTarget?.toDouble() ??
        _cachedCalTarget ??
        2000.0;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddMealBottomSheet(
        initialFoodItems: prefill?['name'] as String?,
        initialCalories: (prefill?['calories'] as num?)?.toDouble(),
        initialProtein: (prefill?['protein'] as num?)?.toDouble(),
        initialCarbs: (prefill?['carbs'] as num?)?.toDouble(),
        initialFats: (prefill?['fats'] as num?)?.toDouble(),
        initialMealType: prefill?['category'] as String?,
        dailyCalTarget: calTarget,
      ),
    );
    _fetchSuggestion();
  }
}

// ── Calorie Ring ──────────────────────────────────────────────────────────────

class _CalorieRing extends StatelessWidget {
  final double consumed;
  final double target;
  final double? targetMin;
  final double? targetMax;

  const _CalorieRing({
    required this.consumed,
    required this.target,
    this.targetMin,
    this.targetMax,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveMax = targetMax ?? target;
    final progress = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;

    Color ringColor;
    if (consumed > effectiveMax) {
      ringColor = AppTheme.errorColor;
    } else if (consumed > target) {
      ringColor = AppTheme.warningColor;
    } else {
      ringColor = AppTheme.primaryColor;
    }

    final rangeLabel = (targetMin != null && targetMax != null)
        ? '${targetMin!.toStringAsFixed(0)}–${targetMax!.toStringAsFixed(0)}'
        : 'of ${target.toStringAsFixed(0)}';

    return SizedBox(
      width: 110,
      height: 110,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 9,
            backgroundColor: AppTheme.borderColor,
            valueColor: AlwaysStoppedAnimation(ringColor),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  consumed.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: ringColor,
                    height: 1.1,
                  ),
                ),
                Text(
                  rangeLabel,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Text(
                  'kcal',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Macro Progress Bar ────────────────────────────────────────────────────────

class _MacroBar extends StatelessWidget {
  final String label;
  final double consumed;
  final double target;
  final Color color;

  const _MacroBar({
    required this.label,
    required this.consumed,
    required this.target,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            Text(
              '${consumed.toStringAsFixed(0)} / ${target.toStringAsFixed(0)}g',
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textTertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            backgroundColor: color.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

// ── History Meal Card (read-only) ─────────────────────────────────────────────

class _HistoryMealCard extends StatelessWidget {
  final Map<String, dynamic> meal;
  const _HistoryMealCard({required this.meal});

  Color _typeColor(String type) {
    switch (type.toLowerCase()) {
      case 'breakfast': return AppTheme.warningColor;
      case 'lunch':     return AppTheme.successColor;
      case 'dinner':    return AppTheme.primaryDark;
      case 'snack':     return AppTheme.secondaryColor;
      default:          return AppTheme.primaryColor;
    }
  }

  IconData _typeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'breakfast': return Icons.wb_sunny_outlined;
      case 'lunch':     return Icons.restaurant_outlined;
      case 'dinner':    return Icons.nightlight_outlined;
      case 'snack':     return Icons.cookie_outlined;
      default:          return Icons.restaurant_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = (meal['meal_type'] as String? ?? '').toLowerCase();
    final color = _typeColor(type);
    final icon = _typeIcon(type);
    final typeLabel = type.isEmpty ? '' : type[0].toUpperCase() + type.substring(1);
    final cal  = (meal['calories'] as num? ?? 0).toDouble();
    final pro  = (meal['protein']  as num? ?? 0).toDouble();
    final carb = (meal['carbs']    as num? ?? 0).toDouble();
    final fat  = (meal['fats']     as num? ?? 0).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSM),
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: AppTheme.cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: AppTheme.spaceMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal['food_items'] as String? ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  typeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spaceSM),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${cal.toStringAsFixed(0)} kcal',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.caloriesColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'P${pro.toStringAsFixed(0)}g · C${carb.toStringAsFixed(0)}g · F${fat.toStringAsFixed(0)}g',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Swipe-to-Delete Meal Card ─────────────────────────────────────────────────

class _SwipeToDeleteMealCard extends StatelessWidget {
  final MealLog log;
  final VoidCallback onDeleted;

  const _SwipeToDeleteMealCard(
      {required this.log, required this.onDeleted});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('meal_${log.logId}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.only(bottom: AppTheme.spaceSM),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.errorColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 24),
            SizedBox(height: 4),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            ),
            title: const Text('Delete Meal?', style: AppTheme.h3Style),
            content: Text(
              'Remove "${log.foodItems}" from today\'s log?',
              style: AppTheme.bodySmallStyle,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(
                    foregroundColor: AppTheme.errorColor),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => onDeleted(),
      child: _MealLogCard(log: log),
    );
  }
}

// ── Meal Log Card ─────────────────────────────────────────────────────────────

class _MealLogCard extends StatelessWidget {
  final MealLog log;
  const _MealLogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    Color mealColor;
    IconData mealIcon;

    switch (log.mealType.toLowerCase()) {
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
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSM),
      decoration: AppTheme.cardDecoration(elevated: true),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceMD),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceMD),
              decoration: BoxDecoration(
                color: mealColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              ),
              child: Icon(mealIcon, color: mealColor, size: 26),
            ),
            const SizedBox(width: AppTheme.spaceMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.mealType.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: mealColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    log.foodItems,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceSM),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _NutrientChip(
                          '${log.calories.toStringAsFixed(0)} cal',
                          AppTheme.caloriesColor),
                      if (log.protein != null)
                        _NutrientChip(
                            '${log.protein!.toStringAsFixed(0)}g P',
                            AppTheme.proteinColor),
                      if (log.carbs != null)
                        _NutrientChip(
                            '${log.carbs!.toStringAsFixed(0)}g C',
                            AppTheme.carbsColor),
                      if (log.fats != null)
                        _NutrientChip(
                            '${log.fats!.toStringAsFixed(0)}g F',
                            AppTheme.fatsColor),
                    ],
                  ),
                ],
              ),
            ),
            // Swipe hint icon
            const Icon(Icons.swipe_left_outlined,
                size: 16, color: AppTheme.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _NutrientChip extends StatelessWidget {
  final String text;
  final Color color;
  const _NutrientChip(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Add Meal Bottom Sheet ─────────────────────────────────────────────────────

class AddMealBottomSheet extends StatefulWidget {
  final String? initialFoodItems;
  final double? initialCalories;
  final double? initialProtein;
  final double? initialCarbs;
  final double? initialFats;
  final String? initialMealType;
  final double dailyCalTarget;

  const AddMealBottomSheet({
    Key? key,
    this.initialFoodItems,
    this.initialCalories,
    this.initialProtein,
    this.initialCarbs,
    this.initialFats,
    this.initialMealType,
    this.dailyCalTarget = 2000.0,
  }) : super(key: key);

  @override
  State<AddMealBottomSheet> createState() => _AddMealBottomSheetState();
}

class _AddMealBottomSheetState extends State<AddMealBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _foodItemsController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatsController = TextEditingController();

  String _selectedMealType = 'breakfast';
  final List<String> _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];

  // Food autocomplete
  List<Map<String, dynamic>> _foodSuggestions = [];
  bool _isSearching = false;
  Timer? _debounce;

  // Recently logged foods
  List<Map<String, dynamic>> _recentFoods = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialFoodItems != null) {
      _foodItemsController.text = widget.initialFoodItems!;
    }
    if (widget.initialCalories != null) {
      _caloriesController.text = widget.initialCalories!.toStringAsFixed(0);
    }
    if (widget.initialProtein != null) {
      _proteinController.text = widget.initialProtein!.toStringAsFixed(0);
    }
    if (widget.initialCarbs != null) {
      _carbsController.text = widget.initialCarbs!.toStringAsFixed(0);
    }
    if (widget.initialFats != null) {
      _fatsController.text = widget.initialFats!.toStringAsFixed(0);
    }
    if (widget.initialMealType != null) {
      _selectedMealType = widget.initialMealType!;
    }
    _foodItemsController.addListener(_onFoodChanged);
    _loadRecentFoods();
  }

  Future<void> _loadRecentFoods() async {
    try {
      final results = await ApiService().getList(
        AppConstants.recentFoodsEndpoint,
        includeAuth: true,
      );
      if (mounted) {
        setState(() {
          _recentFoods = results.cast<Map<String, dynamic>>();
        });
      }
    } catch (_) {}
  }

  // Fill form with a previously-logged food item using its exact logged values.
  void _selectRecentFood(Map<String, dynamic> food) {
    _foodItemsController.removeListener(_onFoodChanged);
    _foodItemsController.text = food['food_items'] as String;
    _foodItemsController.addListener(_onFoodChanged);
    _caloriesController.text =
        (food['calories'] as num).toStringAsFixed(0);
    _proteinController.text =
        (food['protein'] as num?)?.toStringAsFixed(1) ?? '';
    _carbsController.text =
        (food['carbs'] as num?)?.toStringAsFixed(1) ?? '';
    _fatsController.text =
        (food['fats'] as num?)?.toStringAsFixed(1) ?? '';
    if (food['meal_type'] != null) {
      setState(() => _selectedMealType = food['meal_type'] as String);
    }
    setState(() => _foodSuggestions = []);
  }

  void _onFoodChanged() {
    final q = _foodItemsController.text.trim();
    if (q.isEmpty) {
      setState(() => _foodSuggestions = []);
      _debounce?.cancel();
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _searchFood(q));
  }

  Future<void> _searchFood(String q) async {
    if (!mounted) return;
    setState(() => _isSearching = true);
    try {
      final results = await ApiService().getList(
        AppConstants.foodSearchEndpoint,
        includeAuth: true,
        queryParams: {'q': q},
      );
      if (mounted) {
        setState(() {
          _foodSuggestions = results.cast<Map<String, dynamic>>();
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectSuggestion(Map<String, dynamic> meal) {
    const mealSplits = {
      'breakfast': 0.25,
      'lunch': 0.35,
      'dinner': 0.30,
      'snack': 0.10,
    };
    final baseCal = (meal['calories'] as num).toDouble();
    final idealCal =
        widget.dailyCalTarget * (mealSplits[_selectedMealType] ?? 0.25);
    final rawScale = baseCal > 0 ? idealCal / baseCal : 1.0;
    // Round to nearest 0.5 serving for realistic portion guidance
    final servings = ((rawScale * 2).round() / 2).clamp(0.5, 5.0);

    _foodItemsController.removeListener(_onFoodChanged);
    _foodItemsController.text = meal['name'] as String;
    _foodItemsController.addListener(_onFoodChanged);
    _caloriesController.text = (baseCal * servings).round().toString();
    _proteinController.text =
        ((meal['protein'] as num) * servings).toStringAsFixed(1);
    _carbsController.text =
        ((meal['carbs'] as num) * servings).toStringAsFixed(1);
    _fatsController.text =
        ((meal['fats'] as num) * servings).toStringAsFixed(1);
    setState(() => _foodSuggestions = []);
  }

  void _showIngredientSheet(BuildContext context, Map<String, dynamic> meal) {
    final ingredients =
        (meal['ingredients'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
            [];
    if (ingredients.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppTheme.radius2XL),
            topRight: Radius.circular(AppTheme.radius2XL),
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spaceLG),
          shrinkWrap: true,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spaceMD),
            Text(meal['name'] as String, style: AppTheme.h3Style),
            const SizedBox(height: 4),
            Text(
              '${meal['calories']} kcal · P ${meal['protein']}g · C ${meal['carbs']}g · F ${meal['fats']}g',
              style: AppTheme.bodySmallStyle,
            ),
            const SizedBox(height: AppTheme.spaceMD),
            const Divider(),
            const SizedBox(height: AppTheme.spaceSM),
            const Text(
              'Ingredients (1 serving)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.spaceSM),
            ...ingredients.map((ing) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        ing['name'] as String,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '${ing['amount']} ${ing['unit']}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: AppTheme.spaceLG),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _foodItemsController.removeListener(_onFoodChanged);
    _foodItemsController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatsController.dispose();
    super.dispose();
  }

  Future<void> _handleLogMeal() async {
    if (_formKey.currentState!.validate()) {
      final meal = MealLog(
        mealDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        mealType: _selectedMealType,
        foodItems: _foodItemsController.text,
        calories: double.parse(_caloriesController.text),
        protein: _proteinController.text.isEmpty
            ? null
            : double.parse(_proteinController.text),
        carbs: _carbsController.text.isEmpty
            ? null
            : double.parse(_carbsController.text),
        fats: _fatsController.text.isEmpty
            ? null
            : double.parse(_fatsController.text),
      );

      final provider = Provider.of<TrackingProvider>(context, listen: false);
      final success = await provider.logMeal(meal);

      if (success && mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meal logged successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Failed to log meal'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppTheme.radius2XL),
          topRight: Radius.circular(AppTheme.radius2XL),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spaceLG),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spaceMD),
              const Text('Log a Meal', style: AppTheme.h3Style),
              const SizedBox(height: AppTheme.spaceMD),

              // Meal Type Selection
              const Text(
                'Meal Type',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: AppTheme.spaceSM),
              Wrap(
                spacing: AppTheme.spaceSM,
                children: _mealTypes.map((type) {
                  final isSelected = _selectedMealType == type;
                  return ChoiceChip(
                    label: Text(type.toUpperCase()),
                    selected: isSelected,
                    onSelected: (_) =>
                        setState(() => _selectedMealType = type),
                    selectedColor: AppTheme.primaryColor,
                    backgroundColor: AppTheme.surfaceColor,
                    labelStyle: TextStyle(
                      color:
                          isSelected ? Colors.white : AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.borderColor,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppTheme.spaceMD),

              CustomTextField(
                label: 'Food Items',
                hint: 'e.g., Chicken breast with rice',
                controller: _foodItemsController,
                validator: (value) =>
                    Validators.validateRequired(value, 'Food items'),
              ),
              // ── Recently logged quick-picks ────────────────────────────
              if (_recentFoods.isNotEmpty &&
                  _foodItemsController.text.isEmpty &&
                  _foodSuggestions.isEmpty) ...[
                const SizedBox(height: 6),
                const Text(
                  'Recently logged:',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _recentFoods.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, i) {
                      final food = _recentFoods[i];
                      return GestureDetector(
                        onTap: () => _selectRecentFood(food),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLightest,
                            borderRadius: BorderRadius.circular(
                                AppTheme.radiusSM),
                            border: Border.all(
                                color:
                                    AppTheme.primaryColor.withOpacity(0.3)),
                          ),
                          child: Text(
                            food['food_items'] as String,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 6),
              ],
              if (_isSearching)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    color: AppTheme.primaryColor,
                    backgroundColor: AppTheme.primaryLightest,
                  ),
                ),
              if (_foodSuggestions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: AppTheme.spaceSM),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    border: Border.all(color: AppTheme.borderColor),
                    boxShadow: AppTheme.shadowSM,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _foodSuggestions.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, thickness: 1),
                    itemBuilder: (context, i) {
                      final meal = _foodSuggestions[i];
                      final hasIngredients =
                          (meal['ingredients'] as List?)?.isNotEmpty ?? false;
                      return ListTile(
                        dense: true,
                        title: Text(
                          meal['name'] as String,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          '${meal['calories']} kcal · P ${meal['protein']}g · C ${meal['carbs']}g · F ${meal['fats']}g',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasIngredients)
                              GestureDetector(
                                onTap: () =>
                                    _showIngredientSheet(context, meal),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4),
                                  child: Icon(Icons.info_outline,
                                      size: 18,
                                      color: AppTheme.textTertiary),
                                ),
                              ),
                            const Icon(Icons.add_circle_outline,
                                size: 20, color: AppTheme.primaryColor),
                          ],
                        ),
                        onTap: () => _selectSuggestion(meal),
                      );
                    },
                  ),
                ),
              const SizedBox(height: AppTheme.spaceSM),

              CustomTextField(
                label: 'Calories *',
                hint: 'Enter calories',
                controller: _caloriesController,
                keyboardType: TextInputType.number,
                validator: (value) =>
                    Validators.validateNumber(value, 'Calories'),
              ),
              const SizedBox(height: AppTheme.spaceMD),

              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      label: 'Protein (g)',
                      hint: 'Optional',
                      controller: _proteinController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceSM),
                  Expanded(
                    child: CustomTextField(
                      label: 'Carbs (g)',
                      hint: 'Optional',
                      controller: _carbsController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceMD),

              CustomTextField(
                label: 'Fats (g)',
                hint: 'Optional',
                controller: _fatsController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppTheme.spaceLG),

              Consumer<TrackingProvider>(
                builder: (context, provider, child) {
                  return CustomButton(
                    text: 'Log Meal',
                    onPressed: _handleLogMeal,
                    isLoading: provider.isLoading,
                  );
                },
              ),
              const SizedBox(height: AppTheme.spaceSM),
            ],
          ),
        ),
      ),
    );
  }
}

// ── AI Suggestion Card ────────────────────────────────────────────────────────

class _SuggestionCard extends StatelessWidget {
  final Map<String, dynamic> suggestion;
  final void Function(Map<String, dynamic>) onLogTap;

  const _SuggestionCard({required this.suggestion, required this.onLogTap});

  @override
  Widget build(BuildContext context) {
    final suggestions =
        (suggestion['suggestions'] as List).cast<Map<String, dynamic>>();
    if (suggestions.isEmpty) return const SizedBox.shrink();

    final primary = suggestions[0];
    final alts = suggestions.skip(1).toList();
    final nextType = suggestion['next_meal_type'] as String;

    Color mealColor;
    switch (nextType) {
      case 'breakfast':
        mealColor = AppTheme.warningColor;
        break;
      case 'lunch':
        mealColor = AppTheme.successColor;
        break;
      case 'dinner':
        mealColor = AppTheme.primaryDark;
        break;
      default:
        mealColor = AppTheme.secondaryColor;
    }

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: AppTheme.cardDecoration(elevated: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLightest,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: const Icon(Icons.auto_awesome,
                    size: 16, color: AppTheme.primaryColor),
              ),
              const SizedBox(width: AppTheme.spaceSM),
              const Expanded(
                child: Text('Suggested Next Meal', style: AppTheme.h3Style),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: mealColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: Text(
                  nextType.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: mealColor,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMD),
          const Divider(height: 1),
          const SizedBox(height: AppTheme.spaceMD),

          // ── Primary suggestion ─────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      primary['name'] as String,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${primary['calories']} kcal · P ${primary['protein']}g · C ${primary['carbs']}g · F ${primary['fats']}g',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      primary['reason'] as String,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textTertiary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    if (primary['serving'] != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.restaurant_outlined,
                              size: 12, color: AppTheme.textTertiary),
                          const SizedBox(width: 4),
                          Text(
                            primary['serving'] as String,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textTertiary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spaceSM),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLightest,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: Text(
                  '${primary['match_score']}%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMD),

          // ── Log button ─────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => onLogTap(primary),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Log This Meal'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(vertical: AppTheme.spaceSM),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
              ),
            ),
          ),

          // ── Alternative options ────────────────────────────────────────────
          if (alts.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spaceSM),
            const Text(
              'Other options:',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textTertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: alts
                  .map(
                    (alt) => GestureDetector(
                      onTap: () => onLogTap(alt),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.borderColor),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSM),
                        ),
                        child: Text(
                          '${alt['name']}  ·  ${alt['calories']} kcal',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
