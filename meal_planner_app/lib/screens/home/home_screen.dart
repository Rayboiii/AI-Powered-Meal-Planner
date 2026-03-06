import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/meal_plan_provider.dart';
import '../../providers/tracking_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/app_theme.dart';
import '../meal_plan/meal_plan_screen.dart';
import '../meal_plan/generate_plan_screen.dart';
import '../tracking/meal_log_screen.dart';
import '../insights/progress_screen.dart';
import '../profile/profile_edit_screen.dart';
import '../auth/login_screen.dart';
import '../auth/change_password_screen.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeTab(),
    const MealPlanScreen(),
    const MealLogScreen(),
    const ProgressScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Builder(
        builder: (context) {
          final navBg = Theme.of(context).colorScheme.surface;
          return Container(
            decoration: BoxDecoration(
              color: navBg,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) =>
                  setState(() => _selectedIndex = index),
              backgroundColor: navBg,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          indicatorColor: AppTheme.primaryLightest,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: AppTheme.primaryColor),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.restaurant_menu_outlined),
              selectedIcon:
                  Icon(Icons.restaurant_menu, color: AppTheme.primaryColor),
              label: 'Meal Plan',
            ),
            NavigationDestination(
              icon: Icon(Icons.add_circle_outline),
              selectedIcon:
                  Icon(Icons.add_circle, color: AppTheme.primaryColor),
              label: 'Log Meal',
            ),
            NavigationDestination(
              icon: Icon(Icons.analytics_outlined),
              selectedIcon:
                  Icon(Icons.analytics, color: AppTheme.primaryColor),
              label: 'Progress',
            ),
          ],
            ),
          );
        },
      ),
    );
  }
}

class HomeTab extends StatefulWidget {
  const HomeTab({Key? key}) : super(key: key);

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  int _selectedCategory = 0;

  final List<_MealCategory> _categories = const [
    _MealCategory('All', Icons.grid_view_outlined, AppTheme.primaryColor),
    _MealCategory('Breakfast', Icons.wb_sunny_outlined, AppTheme.warningColor),
    _MealCategory('Lunch', Icons.restaurant_outlined, AppTheme.successColor),
    _MealCategory('Dinner', Icons.nightlight_outlined, AppTheme.primaryDark),
    _MealCategory('Snack', Icons.cookie_outlined, AppTheme.secondaryColor),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final mealPlanProvider =
        Provider.of<MealPlanProvider>(context, listen: false);
    final trackingProvider =
        Provider.of<TrackingProvider>(context, listen: false);

    await profileProvider.fetchProfile();
    await trackingProvider.fetchTodayMeals();

    try {
      await mealPlanProvider.fetchCurrentPlan();
    } catch (_) {}
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning!';
    if (hour < 17) return 'Good Afternoon!';
    return 'Good Evening!';
  }

  LinearGradient _avatarGradient(String initial) {
    const gradients = [
      [Color(0xFF6C63FF), Color(0xFF3F3D8E)], // purple
      [Color(0xFF00D9B5), Color(0xFF009E7B)], // teal
      [Color(0xFFFF6B9D), Color(0xFFE84393)], // pink
      [Color(0xFFFFA726), Color(0xFFFF5722)], // orange
      [Color(0xFF26C6DA), Color(0xFF0097A7)], // cyan
      [Color(0xFF66BB6A), Color(0xFF2E7D32)], // green
      [Color(0xFFAB47BC), Color(0xFF6A1B9A)], // violet
      [Color(0xFFEF5350), Color(0xFFB71C1C)], // red
    ];
    final idx = initial.isEmpty ? 0 : initial.codeUnitAt(0) % gradients.length;
    return LinearGradient(
      colors: gradients[idx],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  IconData _mealTypeIcon(String type) {
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
        return Icons.restaurant_outlined;
    }
  }

  Color _mealTypeColor(String type) {
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
        return AppTheme.primaryColor;
    }
  }

  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLG)),
        title: const Text('Sign Out', style: AppTheme.h3Style),
        content: const Text('Are you sure you want to sign out?',
            style: AppTheme.bodySmallStyle),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Sign Out'),
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
            MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    }
  }

  Future<void> _handleDeleteAccount() async {
    // First confirmation
    final confirm1 = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLG)),
        title: const Text('Delete Account', style: AppTheme.h3Style),
        content: const Text(
          'This will permanently delete your account and all your data. This action cannot be undone.',
          style: AppTheme.bodySmallStyle,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirm1 != true || !mounted) return;

    // Second confirmation
    final confirm2 = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLG)),
        title: const Text('Are you absolutely sure?', style: AppTheme.h3Style),
        content: const Text(
          'All meals, plans, and progress data will be lost forever.',
          style: AppTheme.bodySmallStyle,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No, keep my account')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Yes, delete everything'),
          ),
        ],
      ),
    );
    if (confirm2 != true || !mounted) return;

    try {
      await ApiService().delete(AppConstants.deleteAccountEndpoint,
          includeAuth: true);
      if (!mounted) return;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final profileProvider =
          Provider.of<ProfileProvider>(context, listen: false);
      profileProvider.clearProfile();
      await authProvider.logout();
      if (mounted) {
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppTheme.errorColor,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        color: AppTheme.primaryColor,
        onRefresh: _loadData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Custom header
            SliverToBoxAdapter(
              child: Consumer2<ProfileProvider, TrackingProvider>(
                builder: (context, profileProvider, trackingProvider, child) {
                  final name = profileProvider.profile?.name;
                  final initials = (name != null && name.isNotEmpty)
                      ? name.trim()[0].toUpperCase()
                      : '?';
                  final consumed = trackingProvider.totalCalories;
                  final calories = consumed.toStringAsFixed(0);
                  final meals = trackingProvider.todayMeals.length;
                  final calTarget = profileProvider.profile
                          ?.dailyCalorieTarget
                          ?.toDouble() ??
                      0.0;
                  final calProgress = calTarget > 0
                      ? (consumed / calTarget).clamp(0.0, 1.0)
                      : 0.0;
                  final calOver = calTarget > 0 && consumed > calTarget;

                  return Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primaryDark, AppTheme.primaryColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Decorative bubble — large, top right
                        Positioned(
                          top: -40,
                          right: -40,
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.07),
                            ),
                          ),
                        ),
                        // Decorative bubble — medium, bottom left
                        Positioned(
                          bottom: -30,
                          left: -30,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.07),
                            ),
                          ),
                        ),
                        // Decorative bubble — small, middle area
                        Positioned(
                          top: 50,
                          right: 100,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                        ),
                        // Main content
                        SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                                AppTheme.spaceLG, AppTheme.spaceMD,
                                AppTheme.spaceLG, AppTheme.spaceLG),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Greeting row
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _greeting(),
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w400,
                                              color: Colors.white
                                                  .withOpacity(0.8),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            name != null && name.isNotEmpty
                                                ? 'Hi $name!'
                                                : 'Welcome back!',
                                            style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                              letterSpacing: -0.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Dark mode toggle
                                    Consumer<ThemeProvider>(
                                      builder: (_, tp, __) => IconButton(
                                        icon: Icon(
                                          tp.isDark
                                              ? Icons.light_mode_outlined
                                              : Icons.dark_mode_outlined,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                        onPressed: tp.toggle,
                                        tooltip: tp.isDark
                                            ? 'Switch to light mode'
                                            : 'Switch to dark mode',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 36,
                                          minHeight: 36,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    // Avatar with dropdown menu
                                    PopupMenuButton<String>(
                                      offset: const Offset(0, 52),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                            AppTheme.radiusLG),
                                      ),
                                      onSelected: (value) {
                                        switch (value) {
                                          case 'edit':
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      const ProfileEditScreen()),
                                            );
                                            break;
                                          case 'password':
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      const ChangePasswordScreen()),
                                            );
                                            break;
                                          case 'delete':
                                            _handleDeleteAccount();
                                            break;
                                          case 'signout':
                                            _handleSignOut();
                                            break;
                                        }
                                      },
                                      itemBuilder: (_) => [
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(children: [
                                            Icon(Icons.person_outline,
                                                size: 18,
                                                color: AppTheme.textSecondary),
                                            SizedBox(width: 10),
                                            Text('Edit Profile'),
                                          ]),
                                        ),
                                        const PopupMenuItem(
                                          value: 'password',
                                          child: Row(children: [
                                            Icon(Icons.lock_outline,
                                                size: 18,
                                                color: AppTheme.textSecondary),
                                            SizedBox(width: 10),
                                            Text('Change Password'),
                                          ]),
                                        ),
                                        const PopupMenuDivider(),
                                        const PopupMenuItem(
                                          value: 'signout',
                                          child: Row(children: [
                                            Icon(Icons.logout,
                                                size: 18,
                                                color: AppTheme.textSecondary),
                                            SizedBox(width: 10),
                                            Text('Sign Out'),
                                          ]),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(children: [
                                            Icon(Icons.delete_outline,
                                                size: 18,
                                                color: AppTheme.errorColor),
                                            SizedBox(width: 10),
                                            Text('Delete Account',
                                                style: TextStyle(
                                                    color:
                                                        AppTheme.errorColor)),
                                          ]),
                                        ),
                                      ],
                                      child: Container(
                                        width: 46,
                                        height: 46,
                                        decoration: BoxDecoration(
                                          gradient: _avatarGradient(initials),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color:
                                                Colors.white.withOpacity(0.5),
                                            width: 2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.18),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Text(
                                            initials,
                                            style: const TextStyle(
                                              fontSize: 19,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppTheme.spaceMD),
                                // Stats row
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildHeaderStat(
                                        icon: Icons
                                            .local_fire_department_outlined,
                                        value: calories,
                                        label: 'kcal today',
                                      ),
                                    ),
                                    const SizedBox(width: AppTheme.spaceSM),
                                    Expanded(
                                      child: _buildHeaderStat(
                                        icon: Icons.restaurant_outlined,
                                        value: meals.toString(),
                                        label: 'meals logged',
                                      ),
                                    ),
                                  ],
                                ),

                                // Calorie goal progress bar
                                if (calTarget > 0) ...[
                                  const SizedBox(height: AppTheme.spaceMD),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        calOver
                                            ? 'Over daily goal'
                                            : '${(calProgress * 100).toStringAsFixed(0)}% of daily goal',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.white.withOpacity(0.8),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        '${calTarget.toStringAsFixed(0)} kcal target',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.white.withOpacity(0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: calProgress,
                                      minHeight: 6,
                                      backgroundColor:
                                          Colors.white.withOpacity(0.2),
                                      valueColor: AlwaysStoppedAnimation(
                                        calOver
                                            ? AppTheme.errorColor
                                            : Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Body content on themed background
            SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppTheme.radius2XL),
                    topRight: Radius.circular(AppTheme.radius2XL),
                  ),
                ),
                transform: Matrix4.translationValues(0, -5, 0),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppTheme.spaceLG,
                      AppTheme.spaceLG, AppTheme.spaceLG, AppTheme.spaceLG),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── TODAY'S MEALS ──────────────────────────────────
                      Row(
                        children: [
                          const Text("Today's Meals",
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                                letterSpacing: -0.2,
                              )),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const MealLogScreen()),
                            ),
                            child: const Text(
                              'See all →',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spaceSM),

                      Consumer<TrackingProvider>(
                        builder: (context, trackingProvider, child) {
                          final filtered = _selectedCategory == 0
                              ? trackingProvider.todayMeals
                              : trackingProvider.todayMeals
                                  .where((m) =>
                                      m.mealType.toLowerCase() ==
                                      _categories[_selectedCategory]
                                          .label
                                          .toLowerCase())
                                  .toList();

                          if (filtered.isEmpty) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 24, horizontal: 16),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceColor,
                                borderRadius: BorderRadius.circular(
                                    AppTheme.radiusLG),
                                border:
                                    Border.all(color: AppTheme.borderColor),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.restaurant_menu_outlined,
                                      size: 38, color: AppTheme.textTertiary),
                                  const SizedBox(height: 8),
                                  Text(
                                    _selectedCategory == 0
                                        ? 'No meals logged yet'
                                        : 'No ${_categories[_selectedCategory].label.toLowerCase()} logged',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Track your nutrition to reach your goals',
                                    style: AppTheme.bodySmallStyle,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  GestureDetector(
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const MealLogScreen()),
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryLightest,
                                        borderRadius: BorderRadius.circular(
                                            AppTheme.radiusMD),
                                      ),
                                      child: const Text(
                                        'Log your first meal →',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return SizedBox(
                            height: 110,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: AppTheme.spaceSM),
                              itemBuilder: (context, index) {
                                final meal = filtered[index];
                                final color = _mealTypeColor(meal.mealType);
                                final icon = _mealTypeIcon(meal.mealType);
                                final typeLabel =
                                    meal.mealType[0].toUpperCase() +
                                        meal.mealType.substring(1);
                                return Container(
                                  width: 140,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceColor,
                                    borderRadius: BorderRadius.circular(
                                        AppTheme.radiusLG),
                                    border: Border.all(
                                        color: AppTheme.borderColor),
                                    boxShadow: AppTheme.shadowSM,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(5),
                                            decoration: BoxDecoration(
                                              color:
                                                  color.withOpacity(0.12),
                                              borderRadius:
                                                  BorderRadius.circular(7),
                                            ),
                                            child: Icon(icon,
                                                color: color, size: 14),
                                          ),
                                          const SizedBox(width: 5),
                                          Expanded(
                                            child: Text(
                                              typeLabel,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: color,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 7),
                                      Expanded(
                                        child: Text(
                                          meal.foodItems,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: AppTheme.textPrimary,
                                            height: 1.3,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${meal.calories.toStringAsFixed(0)} kcal',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.caloriesColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: AppTheme.spaceLG),

                      // ── MEAL CATEGORIES ────────────────────────────────
                      const Text(
                        'Filter by Meal Type',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spaceSM),

                      SizedBox(
                        height: 80,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _categories.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: AppTheme.spaceSM),
                          itemBuilder: (context, index) {
                            final cat = _categories[index];
                            final selected = _selectedCategory == index;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedCategory = index),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? cat.color
                                      : AppTheme.surfaceColor,
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.radiusLG),
                                  border: Border.all(
                                    color: selected
                                        ? cat.color
                                        : AppTheme.borderColor,
                                  ),
                                  boxShadow: selected
                                      ? [
                                          BoxShadow(
                                            color:
                                                cat.color.withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          )
                                        ]
                                      : null,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      cat.icon,
                                      color: selected
                                          ? Colors.white
                                          : cat.color,
                                      size: 24,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      cat.label,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: selected
                                            ? Colors.white
                                            : AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: AppTheme.spaceLG),

                      // ── QUICK ACTIONS GRID (2 × 2) ─────────────────────
                      const Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spaceSM),

                      Consumer<MealPlanProvider>(
                        builder: (context, mealPlanProvider, child) {
                          return Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildGridAction(
                                      title: mealPlanProvider.hasPlan
                                          ? 'Meal Plan'
                                          : 'Generate Plan',
                                      icon: Icons.calendar_today_outlined,
                                      color: AppTheme.primaryColor,
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              mealPlanProvider.hasPlan
                                                  ? const MealPlanScreen()
                                                  : const GeneratePlanScreen(),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppTheme.spaceSM),
                                  Expanded(
                                    child: _buildGridAction(
                                      title: 'Log Meal',
                                      icon: Icons.add_circle_outline,
                                      color: AppTheme.secondaryColor,
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const MealLogScreen()),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppTheme.spaceSM),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildGridAction(
                                      title: 'Progress',
                                      icon: Icons.analytics_outlined,
                                      color: AppTheme.infoColor,
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const ProgressScreen()),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppTheme.spaceSM),
                                  Expanded(
                                    child: _buildGridAction(
                                      title: 'Edit Profile',
                                      icon: Icons.person_outline,
                                      color: AppTheme.primaryDark,
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const ProfileEditScreen()),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: AppTheme.spaceLG),

                      // ── SIGN OUT ───────────────────────────────────────
                      Consumer<AuthProvider>(
                        builder: (context, authProvider, child) {
                          return Center(
                            child: TextButton.icon(
                              onPressed: () async {
                                final profileProvider =
                                    Provider.of<ProfileProvider>(context,
                                        listen: false);
                                profileProvider.clearProfile();
                                await authProvider.logout();
                                if (mounted) {
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                        builder: (_) => const LoginScreen()),
                                  );
                                }
                              },
                              icon: const Icon(Icons.logout,
                                  size: 16, color: AppTheme.textTertiary),
                              label: const Text(
                                'Sign out',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textTertiary,
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: AppTheme.spaceMD),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderStat({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.8),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGridAction({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.shadowSM,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withOpacity(0.15),
                        color.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MealCategory {
  final String label;
  final IconData icon;
  final Color color;
  const _MealCategory(this.label, this.icon, this.color);
}
