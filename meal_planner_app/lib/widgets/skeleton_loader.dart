import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../utils/app_theme.dart';

// ── Primitive placeholder ─────────────────────────────────────────────────────

class _Box extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  final bool circle;

  const _Box({
    this.width,
    required this.height,
    this.radius = AppTheme.radiusMD,
    this.circle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: circle ? height : (width ?? double.infinity),
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
      ),
    );
  }
}

Widget _card({required double height, double? width, double radius = AppTheme.radiusLG}) {
  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

// ── Shimmer wrapper ───────────────────────────────────────────────────────────

Shimmer _shimmer(Widget child) {
  return Shimmer.fromColors(
    baseColor: const Color(0xFFE8EBF0),
    highlightColor: const Color(0xFFF5F7FA),
    child: child,
  );
}

// ── Meal Plan Skeleton ────────────────────────────────────────────────────────

class MealPlanSkeleton extends StatelessWidget {
  const MealPlanSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _shimmer(
      SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spaceMD),
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plan info banner
            _card(height: 72),
            const SizedBox(height: AppTheme.spaceMD),

            // Date chip row
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 7,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, __) =>
                    _card(height: 38, width: 58, radius: 19),
              ),
            ),
            const SizedBox(height: AppTheme.spaceMD),

            // 4 meal cards (breakfast, lunch, dinner, snack)
            for (int i = 0; i < 4; i++) ...[
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceMD),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const _Box(width: 70, height: 13),
                        const Spacer(),
                        const _Box(width: 45, height: 13),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const _Box(height: 17),
                    const SizedBox(height: 8),
                    const _Box(width: 180, height: 12),
                    const SizedBox(height: 12),
                    Row(
                      children: const [
                        _Box(width: 55, height: 10),
                        SizedBox(width: 12),
                        _Box(width: 55, height: 10),
                        SizedBox(width: 12),
                        _Box(width: 55, height: 10),
                      ],
                    ),
                  ],
                ),
              ),
              if (i < 3) const SizedBox(height: AppTheme.spaceMD),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Meal Log Skeleton ─────────────────────────────────────────────────────────

class MealLogSkeleton extends StatelessWidget {
  const MealLogSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _shimmer(
      SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spaceMD),
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary card: calorie ring + macro bars
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceMD),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusLG),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _Box(width: 120, height: 16),
                      const Spacer(),
                      const _Box(width: 60, height: 22, radius: AppTheme.radiusSM),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spaceMD),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Calorie ring placeholder
                      const _Box(width: 110, height: 110, circle: true),
                      const SizedBox(width: AppTheme.spaceMD),
                      Expanded(
                        child: Column(
                          children: const [
                            _Box(height: 28, radius: AppTheme.radiusSM),
                            SizedBox(height: 10),
                            _Box(height: 28, radius: AppTheme.radiusSM),
                            SizedBox(height: 10),
                            _Box(height: 28, radius: AppTheme.radiusSM),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spaceMD),

            // Category chips
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 5,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) =>
                    _card(height: 36, width: i == 0 ? 42 : 78, radius: 18),
              ),
            ),
            const SizedBox(height: AppTheme.spaceMD),

            // 4 meal log cards
            for (int i = 0; i < 4; i++) ...[
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceMD),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const _Box(width: 65, height: 12, radius: AppTheme.radiusSM),
                        const Spacer(),
                        const _Box(width: 50, height: 12),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const _Box(height: 16),
                    const SizedBox(height: 8),
                    Row(
                      children: const [
                        _Box(width: 52, height: 10),
                        SizedBox(width: 12),
                        _Box(width: 52, height: 10),
                        SizedBox(width: 12),
                        _Box(width: 52, height: 10),
                      ],
                    ),
                  ],
                ),
              ),
              if (i < 3) const SizedBox(height: AppTheme.spaceSM),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Progress Skeleton ─────────────────────────────────────────────────────────

class ProgressSkeleton extends StatelessWidget {
  const ProgressSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _shimmer(
      SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spaceMD),
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 3 summary chips
            Row(
              children: [
                Expanded(child: _card(height: 80)),
                const SizedBox(width: AppTheme.spaceSM),
                Expanded(child: _card(height: 80)),
                const SizedBox(width: AppTheme.spaceSM),
                Expanded(child: _card(height: 80)),
              ],
            ),
            const SizedBox(height: AppTheme.spaceMD),

            // Calorie chart card
            _card(height: 240),
            const SizedBox(height: AppTheme.spaceMD),

            // Macro donut card
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusLG),
              ),
              padding: const EdgeInsets.all(AppTheme.spaceMD),
              child: Row(
                children: [
                  const _Box(width: 120, height: 120, circle: true),
                  const SizedBox(width: AppTheme.spaceLG),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        _Box(height: 12),
                        SizedBox(height: 10),
                        _Box(height: 12),
                        SizedBox(height: 10),
                        _Box(height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spaceMD),

            // Section label
            const _Box(width: 120, height: 14),
            const SizedBox(height: AppTheme.spaceSM),

            // 3 insight cards
            for (int i = 0; i < 3; i++) ...[
              _card(height: 68, radius: AppTheme.radiusMD),
              const SizedBox(height: AppTheme.spaceSM),
            ],

            const SizedBox(height: AppTheme.spaceSM),

            // Section label
            const _Box(width: 110, height: 14),
            const SizedBox(height: AppTheme.spaceSM),

            // 5 daily breakdown cards
            for (int i = 0; i < 5; i++) ...[
              _card(height: 58, radius: AppTheme.radiusMD),
              const SizedBox(height: AppTheme.spaceSM),
            ],
          ],
        ),
      ),
    );
  }
}
