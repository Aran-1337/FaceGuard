import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../models/user_model.dart';
import '../../widgets/common/stat_card.dart';
import '../employee/settings_screen.dart';
import '../common/notification_screen.dart';
import '../common/send_notification_screen.dart';
import '../manager/attendance_config_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final DatabaseService _dbService = DatabaseService();
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildDashboard(),
          _buildPlaceholder('Users'),
          _buildPlaceholder('Salaries'),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 1)
            Navigator.pushNamed(context, AppRoutes.userManagement);
          else if (index == 2)
            Navigator.pushNamed(context, AppRoutes.salaryManagement);
          else
            setState(() => _currentIndex = index);
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Users',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money),
            activeIcon: Icon(Icons.attach_money),
            label: 'Salaries',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin Dashboard',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.name ?? 'Admin',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ],
                ),
                StreamBuilder<int>(
                  stream: _dbService.getUnreadNotificationCount(
                      authProvider.currentUser?.uid ?? ''),
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    return Stack(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_outlined),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => NotificationScreen(
                                    userId:
                                        authProvider.currentUser?.uid ?? ''),
                              ),
                            );
                          },
                        ),
                        if (count > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppTheme.errorColor,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$count',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 10),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
              style: TextStyle(color: AppTheme.greyColor),
            ),
            const SizedBox(height: 24),
            // Stats
            StreamBuilder<List<UserModel>>(
              stream: _dbService.getUsers(),
              builder: (context, snapshot) {
                final users = snapshot.data ?? [];
                int employees = users
                    .where((u) => u.role == UserRole.employee)
                    .length;
                int managers = users
                    .where((u) => u.role == UserRole.manager)
                    .length;
                int admins = users
                    .where((u) => u.role == UserRole.admin)
                    .length;
                return Column(
                  children: [
                    GradientStatCard(
                      title: 'Total Users',
                      value: '${users.length}',
                      icon: Icons.people,
                      subtitle: 'All system users',
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            title: 'Employees',
                            value: '$employees',
                            icon: Icons.person,
                            color: AppTheme.primaryColor,
                            compact: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatCard(
                            title: 'Managers',
                            value: '$managers',
                            icon: Icons.supervisor_account,
                            color: AppTheme.secondaryColor,
                            compact: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatCard(
                            title: 'Admins',
                            value: '$admins',
                            icon: Icons.admin_panel_settings,
                            color: AppTheme.errorColor,
                            compact: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            // Quick Actions
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _buildActionCard(
                  'Manage Users',
                  Icons.people,
                  () => Navigator.pushNamed(context, AppRoutes.userManagement),
                ),
                _buildActionCard(
                  'Salaries',
                  Icons.attach_money,
                  () =>
                      Navigator.pushNamed(context, AppRoutes.salaryManagement),
                ),
                _buildActionCard(
                  'Punishments',
                  Icons.warning,
                  () => Navigator.pushNamed(
                    context,
                    AppRoutes.punishmentManagement,
                  ),
                ),
                _buildActionCard(
                  'Departments',
                  Icons.business,
                  () => Navigator.pushNamed(
                    context,
                    AppRoutes.departmentManagement,
                  ),
                ),
                _buildActionCard(
                  'Notifications',
                  Icons.campaign,
                  () {
                    final user = authProvider.currentUser;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SendNotificationScreen(
                          senderId: user?.uid ?? '',
                          senderName: user?.name ?? 'Admin',
                        ),
                      ),
                    );
                  },
                ),
                _buildActionCard(
                  'Settings',
                  Icons.settings,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AttendanceConfigScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(String title, IconData icon, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                  ),
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.primaryColor, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(String title) => Center(child: Text(title));
}
