import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/profile_provider.dart';
import '../../utils/app_theme.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/skeleton_loader.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({Key? key}) : super(key: key);

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  Map<String, dynamic>? _progressData;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadProgressData();
  }

  Future<void> _loadProgressData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 6));
      final fmt = DateFormat('yyyy-MM-dd');

      final response = await ApiService().get(
        '${AppConstants.progressEndpoint}'
        '?start_date=${fmt.format(startDate)}&end_date=${fmt.format(endDate)}',
        includeAuth: true,
      );

      setState(() {
        _progressData = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  // ── Streak: consecutive logged days ending today ──────────────────────────
  int _computeStreak(List dailyData) {
    if (dailyData.isEmpty) return 0;
    final loggedDates = dailyData
        .map((d) => _dateOnly(DateTime.parse(d['meal_date'])))
        .toSet();
    int streak = 0;
    DateTime check = _dateOnly(DateTime.now());
    while (loggedDates.contains(check)) {
      streak++;
      check = check.subtract(const Duration(days: 1));
    }
    return streak;
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  // ── Smart insights ────────────────────────────────────────────────────────
  List<_Insight> _generateInsights(
    List dailyData,
    Map<String, dynamic> summary,
    double calTarget,
    double proteinTarget,
  ) {
    final insights = <_Insight>[];
    final daysTracked = (summary['days_tracked'] as num).toInt();
    final avgCal = (summary['average_calories'] as num).toDouble();

    final avgProtein = dailyData.isEmpty
        ? 0.0
        : dailyData
                .map((d) => (d['total_protein'] as num?)?.toDouble() ?? 0.0)
                .reduce((a, b) => a + b) /
            dailyData.length;

    // Tracking consistency
    if (daysTracked >= 5) {
      insights.add(_Insight(
        icon: Icons.emoji_events_outlined,
        color: AppTheme.warningColor,
        title: 'Great consistency!',
        body: 'You tracked $daysTracked out of 7 days this week.',
      ));
    } else if (daysTracked > 0) {
      insights.add(_Insight(
        icon: Icons.trending_up,
        color: AppTheme.infoColor,
        title: 'Keep it up!',
        body:
            'You logged $daysTracked day${daysTracked > 1 ? 's' : ''} this week. '
            'Daily tracking leads to better results.',
      ));
    }

    // Calorie compliance vs target
    if (calTarget > 0) {
      final diff = avgCal - calTarget;
      if (diff.abs() < 150) {
        insights.add(_Insight(
          icon: Icons.check_circle_outline,
          color: AppTheme.successColor,
          title: 'Calories on target!',
          body:
              'Your average of ${avgCal.toStringAsFixed(0)} kcal is right in line with your goal.',
        ));
      } else if (diff > 0) {
        insights.add(_Insight(
          icon: Icons.info_outline,
          color: AppTheme.warningColor,
          title: 'Slightly over goal',
          body:
              'You averaged ${diff.toStringAsFixed(0)} kcal above your daily target. '
              'Small adjustments add up over time.',
        ));
      } else {
        insights.add(_Insight(
          icon: Icons.info_outline,
          color: AppTheme.infoColor,
          title: 'Under calorie goal',
          body:
              'You averaged ${diff.abs().toStringAsFixed(0)} kcal below target. '
              'Make sure you\'re fuelling your body adequately.',
        ));
      }
    }

    // Protein adequacy
    if (proteinTarget > 0 && avgProtein > 0) {
      final pct = avgProtein / proteinTarget;
      if (pct >= 0.9) {
        insights.add(_Insight(
          icon: Icons.fitness_center_outlined,
          color: AppTheme.proteinColor,
          title: 'Protein goal met!',
          body:
              'Strong work — you averaged ${avgProtein.toStringAsFixed(0)}g of protein per day.',
        ));
      } else {
        insights.add(_Insight(
          icon: Icons.fitness_center_outlined,
          color: AppTheme.proteinColor,
          title: 'Boost your protein',
          body:
              'You averaged ${avgProtein.toStringAsFixed(0)}g vs your '
              '${proteinTarget.toStringAsFixed(0)}g target. '
              'Try adding eggs, chicken, or legumes to your meals.',
        ));
      }
    }

    return insights.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress Insights'),
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
        onRefresh: _loadProgressData,
        child: _isLoading
            ? const ProgressSkeleton()
            : _errorMessage.isNotEmpty
                ? _buildErrorState()
                : _buildContent(),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceLG),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceLG),
                decoration: const BoxDecoration(
                  color: AppTheme.primaryLightest,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.analytics_outlined,
                    size: 48, color: AppTheme.primaryColor),
              ),
              const SizedBox(height: AppTheme.spaceLG),
              const Text('No Data Yet', style: AppTheme.h3Style),
              const SizedBox(height: AppTheme.spaceSM),
              const Text(
                'Start logging meals to see your progress here',
                style: AppTheme.bodySmallStyle,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Error state ───────────────────────────────────────────────────────────
  Widget _buildErrorState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceLG),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceLG),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.wifi_off_outlined,
                    size: 48, color: AppTheme.errorColor),
              ),
              const SizedBox(height: AppTheme.spaceLG),
              const Text('Could Not Load Data', style: AppTheme.h3Style),
              const SizedBox(height: AppTheme.spaceSM),
              Text(
                _errorMessage,
                style: AppTheme.bodySmallStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spaceXL),
              ElevatedButton.icon(
                onPressed: _loadProgressData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceLG,
                    vertical: AppTheme.spaceMD,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Main content ──────────────────────────────────────────────────────────
  Widget _buildContent() {
    if (_progressData == null ||
        (_progressData!['daily_data'] as List?)?.isEmpty != false) {
      return _buildEmptyState();
    }

    final dailyData = _progressData!['daily_data'] as List;
    final summary = _progressData!['summary'] as Map<String, dynamic>;
    final streak = _computeStreak(dailyData);

    final profile =
        Provider.of<ProfileProvider>(context, listen: false).profile;
    final calTarget = profile?.dailyCalorieTarget?.toDouble() ?? 0.0;
    final proteinTarget = profile?.dailyProteinTarget ?? 0.0;

    // Weekly macro averages
    final avgProtein = dailyData
            .map((d) => (d['total_protein'] as num?)?.toDouble() ?? 0.0)
            .fold(0.0, (a, b) => a + b) /
        dailyData.length;
    final avgCarbs = dailyData
            .map((d) => (d['total_carbs'] as num?)?.toDouble() ?? 0.0)
            .fold(0.0, (a, b) => a + b) /
        dailyData.length;
    final avgFats = dailyData
            .map((d) => (d['total_fats'] as num?)?.toDouble() ?? 0.0)
            .fold(0.0, (a, b) => a + b) /
        dailyData.length;

    final insights = _generateInsights(
        dailyData, summary, calTarget, proteinTarget);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── WEEKLY SUMMARY CARDS ────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  icon: Icons.calendar_today_outlined,
                  color: AppTheme.primaryColor,
                  value: '${(summary['days_tracked'] as num).toInt()}',
                  label: 'Days Tracked',
                ),
              ),
              const SizedBox(width: AppTheme.spaceSM),
              Expanded(
                child: _SummaryCard(
                  icon: Icons.local_fire_department_outlined,
                  color: AppTheme.secondaryColor,
                  value: '$streak',
                  label: streak == 1 ? 'Day Streak' : 'Day Streak',
                  suffix: streak >= 3 ? '🔥' : null,
                ),
              ),
              const SizedBox(width: AppTheme.spaceSM),
              Expanded(
                child: _SummaryCard(
                  icon: Icons.bolt_outlined,
                  color: AppTheme.caloriesColor,
                  value:
                      (summary['average_calories'] as num).toStringAsFixed(0),
                  label: 'Avg kcal/day',
                ),
              ),
            ],
          ),

          const SizedBox(height: AppTheme.spaceLG),

          // ── CALORIE TREND CHART ─────────────────────────────────────────
          const Text(
            'Calorie Trend',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          Container(
            decoration: AppTheme.cardDecoration(elevated: true),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spaceMD),
              child: SizedBox(
                height: 230,
                child: LineChart(
                  _buildCalorieChart(dailyData, calTarget),
                ),
              ),
            ),
          ),

          const SizedBox(height: AppTheme.spaceLG),

          // ── MACRO BREAKDOWN DONUT ───────────────────────────────────────
          const Text(
            'Macro Breakdown',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          _buildMacroDonut(avgProtein, avgCarbs, avgFats),

          const SizedBox(height: AppTheme.spaceLG),

          // ── SMART INSIGHTS ──────────────────────────────────────────────
          if (insights.isNotEmpty) ...[
            const Text(
              'Insights',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: AppTheme.spaceSM),
            ...insights.map((i) => _InsightCard(insight: i)),
            const SizedBox(height: AppTheme.spaceSM),
          ],

          // ── DAILY BREAKDOWN LIST ────────────────────────────────────────
          const Text(
            'Daily Breakdown',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: dailyData.length,
            itemBuilder: (context, index) =>
                _buildDayCard(dailyData[index], calTarget),
          ),
        ],
      ),
    );
  }

  // ── Calorie line chart (with optional goal reference line) ────────────────
  LineChartData _buildCalorieChart(List dailyData, double calTarget) {
    final spots = <FlSpot>[];
    double maxY = 0;
    for (int i = 0; i < dailyData.length; i++) {
      final cal = (dailyData[i]['total_calories'] as num?)?.toDouble() ?? 0;
      spots.add(FlSpot(i.toDouble(), cal));
      if (cal > maxY) maxY = cal;
    }
    if (calTarget > maxY) maxY = calTarget;
    // Round up to the next 500-multiple so y-axis labels are always clean
    // and the top label never crowds against the chart edge.
    maxY = (((maxY * 1.15) / 500).ceil() * 500).toDouble();
    if (maxY < 500) maxY = 500.0;

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 500,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: AppTheme.borderColor, strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            interval: 1,
            getTitlesWidget: (value, _) {
              final idx = value.toInt();
              if (idx < 0 || idx >= dailyData.length) return const Text('');
              final date =
                  DateTime.parse(dailyData[idx]['meal_date']);
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(DateFormat('E').format(date),
                    style: AppTheme.captionStyle),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 500,
            reservedSize: 42,
            getTitlesWidget: (value, _) => Text(
              value.toInt().toString(),
              style: AppTheme.captionStyle,
            ),
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: (dailyData.length - 1).toDouble(),
      minY: 0,
      maxY: maxY,
      // Optional goal reference line
      extraLinesData: calTarget > 0
          ? ExtraLinesData(horizontalLines: [
              HorizontalLine(
                y: calTarget,
                color: AppTheme.primaryColor.withOpacity(0.4),
                strokeWidth: 1.5,
                dashArray: [5, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.only(right: 4, bottom: 2),
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.primaryColor.withOpacity(0.7),
                    fontWeight: FontWeight.w600,
                  ),
                  labelResolver: (_) => 'Goal',
                ),
              ),
            ])
          : null,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: AppTheme.primaryColor,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
              radius: 4,
              color: AppTheme.primaryColor,
              strokeWidth: 2,
              strokeColor: AppTheme.surfaceColor,
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            color: AppTheme.primaryColor.withOpacity(0.08),
          ),
        ),
      ],
    );
  }

  // ── Macro donut chart ─────────────────────────────────────────────────────
  Widget _buildMacroDonut(double protein, double carbs, double fats) {
    final proteinCal = protein * 4;
    final carbsCal = carbs * 4;
    final fatsCal = fats * 9;
    final total = proteinCal + carbsCal + fatsCal;

    if (total == 0) {
      return Container(
        padding: const EdgeInsets.all(AppTheme.spaceLG),
        decoration: AppTheme.cardDecoration(elevated: true),
        child: const Center(
          child: Text('No macro data available',
              style: AppTheme.bodySmallStyle),
        ),
      );
    }

    final pPct = (proteinCal / total * 100).round();
    final cPct = (carbsCal / total * 100).round();
    final fPct = 100 - pPct - cPct; // ensure sum = 100

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: AppTheme.cardDecoration(elevated: true),
      child: Row(
        children: [
          // Donut chart
          SizedBox(
            width: 130,
            height: 130,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 38,
                sections: [
                  PieChartSectionData(
                    value: proteinCal,
                    color: AppTheme.proteinColor,
                    title: '$pPct%',
                    titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                    radius: 32,
                  ),
                  PieChartSectionData(
                    value: carbsCal,
                    color: AppTheme.carbsColor,
                    title: '$cPct%',
                    titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                    radius: 32,
                  ),
                  PieChartSectionData(
                    value: fatsCal,
                    color: AppTheme.fatsColor,
                    title: '$fPct%',
                    titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                    radius: 32,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: AppTheme.spaceMD),

          // Legend
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Average per day',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSM),
                _MacroLegendRow(
                  color: AppTheme.proteinColor,
                  label: 'Protein',
                  pct: pPct,
                  grams: protein,
                ),
                const SizedBox(height: AppTheme.spaceSM),
                _MacroLegendRow(
                  color: AppTheme.carbsColor,
                  label: 'Carbs',
                  pct: cPct,
                  grams: carbs,
                ),
                const SizedBox(height: AppTheme.spaceSM),
                _MacroLegendRow(
                  color: AppTheme.fatsColor,
                  label: 'Fats',
                  pct: fPct,
                  grams: fats,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Daily breakdown card ──────────────────────────────────────────────────
  Widget _buildDayCard(Map<String, dynamic> day, double calTarget) {
    final date = DateTime.parse(day['meal_date']);
    final calories = (day['total_calories'] as num?)?.toDouble() ?? 0;
    final protein = (day['total_protein'] as num?)?.toDouble() ?? 0;
    final carbs = (day['total_carbs'] as num?)?.toDouble() ?? 0;
    final fats = (day['total_fats'] as num?)?.toDouble() ?? 0;
    final mealCount = (day['meal_count'] as num?)?.toInt() ?? 0;
    final onTarget = calTarget > 0 && (calories - calTarget).abs() < 200;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSM),
      decoration: AppTheme.cardDecoration(elevated: true),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE').format(date),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(DateFormat('MMM d').format(date),
                        style: AppTheme.bodySmallStyle),
                  ],
                ),
                const Spacer(),
                if (onTarget)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withOpacity(0.12),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusSM),
                    ),
                    child: const Text(
                      'On target',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.successColor,
                      ),
                    ),
                  ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLightest,
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusSM),
                  ),
                  child: Text(
                    '$mealCount meals',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceMD),
            Divider(color: AppTheme.borderColor, height: 1),
            const SizedBox(height: AppTheme.spaceSM),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NutrientColumn('Cal',
                    calories.toStringAsFixed(0), AppTheme.caloriesColor),
                _NutrientColumn('Protein',
                    '${protein.toStringAsFixed(0)}g', AppTheme.proteinColor),
                _NutrientColumn('Carbs',
                    '${carbs.toStringAsFixed(0)}g', AppTheme.carbsColor),
                _NutrientColumn('Fats',
                    '${fats.toStringAsFixed(0)}g', AppTheme.fatsColor),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final String? suffix;

  const _SummaryCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: AppTheme.cardDecoration(elevated: true),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1.1,
                ),
              ),
              if (suffix != null) ...[
                const SizedBox(width: 2),
                Text(suffix!, style: const TextStyle(fontSize: 14)),
              ],
            ],
          ),
          const SizedBox(height: 3),
          Text(label,
              style: AppTheme.captionStyle, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _MacroLegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final int pct;
  final double grams;

  const _MacroLegendRow({
    required this.color,
    required this.label,
    required this.pct,
    required this.grams,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        Text(
          '$pct%  ·  ${grams.toStringAsFixed(0)}g',
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _Insight {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _Insight(
      {required this.icon,
      required this.color,
      required this.title,
      required this.body});
}

class _InsightCard extends StatelessWidget {
  final _Insight insight;
  const _InsightCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    // Stack + Positioned accent bar:
    //  - Stack sizes to its non-positioned child (the Padding/Row), giving a
    //    bounded height in a Column → no "infinite height" error.
    //  - Positioned(top:0, bottom:0) then stretches to that bounded height.
    //  - Outer Container uses a uniform border (all same colour) + borderRadius,
    //    which is legal. ClipRRect rounds the accent bar's corners.
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSM),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.shadowSM,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        child: Stack(
          children: [
            // Content — determines card height
            Padding(
              // Extra left padding to clear the 4 px accent bar
              padding: const EdgeInsets.fromLTRB(
                4 + AppTheme.spaceMD,
                AppTheme.spaceMD,
                AppTheme.spaceMD,
                AppTheme.spaceMD,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: insight.color.withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusSM),
                    ),
                    child:
                        Icon(insight.icon, color: insight.color, size: 18),
                  ),
                  const SizedBox(width: AppTheme.spaceMD),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          insight.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          insight.body,
                          style: AppTheme.bodySmallStyle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Accent bar — stretches to the Stack's bounded height
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 4, color: insight.color),
            ),
          ],
        ),
      ),
    );
  }
}

class _NutrientColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _NutrientColumn(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
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
