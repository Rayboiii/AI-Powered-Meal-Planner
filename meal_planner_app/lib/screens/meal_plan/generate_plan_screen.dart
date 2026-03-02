import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/meal_plan_provider.dart';
import '../../utils/app_theme.dart';

class GeneratePlanScreen extends StatefulWidget {
  const GeneratePlanScreen({Key? key}) : super(key: key);

  @override
  State<GeneratePlanScreen> createState() => _GeneratePlanScreenState();
}

class _GeneratePlanScreenState extends State<GeneratePlanScreen> {
  DateTime _selectedDate = DateTime.now();
  int _duration = 7;
  bool _isGenerating = false;

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _generatePlan() async {
    if (_isGenerating) return;

    setState(() => _isGenerating = true);

    try {
      final provider = Provider.of<MealPlanProvider>(context, listen: false);
      final dateString = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final success = await provider.generateMealPlan(dateString, _duration);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meal plan generated!'),
            backgroundColor: AppTheme.successColor,
            duration: Duration(seconds: 2),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Failed to generate plan'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Meal Plan'),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Create Your Meal Plan', style: AppTheme.h3Style),
            const SizedBox(height: AppTheme.spaceSM),
            const Text(
              'Our AI will generate a customized meal plan based on your profile',
              style: AppTheme.bodySmallStyle,
            ),
            const SizedBox(height: AppTheme.spaceXL),

            // Start Date Card
            Container(
              decoration: AppTheme.cardDecoration(elevated: true),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                child: InkWell(
                  onTap: _selectDate,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spaceMD),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppTheme.spaceMD),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLightest,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMD),
                          ),
                          child: const Icon(
                            Icons.calendar_today_outlined,
                            color: AppTheme.primaryColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spaceMD),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Start Date',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('EEEE, MMMM d, yyyy')
                                    .format(_selectedDate),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: AppTheme.textTertiary, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppTheme.spaceLG),

            const Text(
              'Plan Duration',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spaceSM),

            Wrap(
              spacing: AppTheme.spaceSM,
              runSpacing: AppTheme.spaceSM,
              children: [3, 7, 14, 30].map((days) {
                final isSelected = _duration == days;
                return ChoiceChip(
                  label: Text('$days days'),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _duration = days),
                  selectedColor: AppTheme.primaryColor,
                  backgroundColor: AppTheme.surfaceColor,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.borderColor,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceMD,
                    vertical: AppTheme.spaceSM,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: AppTheme.spaceXL),

            // Summary Card
            Container(
              decoration: AppTheme.cardDecoration(elevated: false),
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spaceMD),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLightest,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSM),
                          ),
                          child: const Icon(Icons.summarize_outlined,
                              color: AppTheme.primaryColor, size: 16),
                        ),
                        const SizedBox(width: AppTheme.spaceSM),
                        const Text(
                          'Summary',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spaceMD),
                    _buildSummaryRow(
                      'Start Date',
                      DateFormat('MMM d, yyyy').format(_selectedDate),
                    ),
                    const SizedBox(height: AppTheme.spaceSM),
                    _buildSummaryRow(
                      'End Date',
                      DateFormat('MMM d, yyyy').format(
                        _selectedDate.add(Duration(days: _duration - 1)),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceSM),
                    _buildSummaryRow('Duration', '$_duration days'),
                    const SizedBox(height: AppTheme.spaceSM),
                    _buildSummaryRow('Total Meals', '${_duration * 4}'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppTheme.spaceXL),

            // Generate Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isGenerating ? null : _generatePlan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  disabledBackgroundColor:
                      AppTheme.primaryColor.withOpacity(0.6),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  ),
                ),
                child: _isGenerating
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Generate Meal Plan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: AppTheme.spaceMD),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTheme.bodySmallStyle),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
