import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../models/attendance_model.dart';
import '../../widgets/common/stat_card.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../services/spot_check_service.dart';
import '../../services/database_service.dart';
import '../common/notification_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'attendance_history_screen.dart';

class EmployeeDashboard extends StatefulWidget {
  const EmployeeDashboard({super.key});

  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard> {
  int _currentIndex = 0;
  final SpotCheckService _spotCheckService = SpotCheckService();
  final DatabaseService _dbService = DatabaseService();
  List<Map<String, dynamic>> _pendingSpotChecks = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final authProvider = context.read<AuthProvider>();
    final attendanceProvider = context.read<AttendanceProvider>();

    if (authProvider.currentEmployee != null) {
      final employeeId = authProvider.currentEmployee!.id;
      final userId = authProvider.currentUser?.uid ?? '';
      attendanceProvider.loadTodayAttendance(employeeId);
      attendanceProvider.loadMonthlyStats(employeeId);
      attendanceProvider.loadAttendanceHistory(employeeId);

      // Start spot check service
      _spotCheckService.startPeriodicChecks(employeeId, userId);

      // Check for pending spot checks
      _checkPendingSpotChecks(employeeId);
    }
  }

  Future<void> _checkPendingSpotChecks(String employeeId) async {
    final pending = await _spotCheckService.checkPending(employeeId);
    if (mounted) {
      setState(() => _pendingSpotChecks = pending);
    }
  }

  @override
  void dispose() {
    _spotCheckService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildDashboardContent(),
          const _CameraPlaceholder(),
          const ProfileScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildDashboardContent() {
    final authProvider = context.watch<AuthProvider>();
    final attendanceProvider = context.watch<AttendanceProvider>();
    final user = authProvider.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: isDark ? AppTheme.darkGradient : null,
        color: isDark ? null : AppTheme.lightColor,
      ),
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _loadData(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getGreeting(),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.name ?? 'Employee',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        // Notification Bell
                        StreamBuilder<int>(
                          stream: _dbService.getUnreadNotificationCount(
                              authProvider.currentUser?.uid ?? ''),
                          builder: (context, snapshot) {
                            final count = snapshot.data ?? 0;
                            return Stack(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                      Icons.notifications_outlined),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => NotificationScreen(
                                            userId: authProvider
                                                    .currentUser?.uid ??
                                                ''),
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
                                            color: Colors.white,
                                            fontSize: 10),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => setState(() => _currentIndex = 2),
                          child: CircleAvatar(
                            radius: 24,
                            backgroundColor: AppTheme.primaryColor,
                            backgroundImage: user?.photoUrl != null
                                ? NetworkImage(user!.photoUrl!)
                                : null,
                            child: user?.photoUrl == null
                                ? Text(
                                    user?.name.isNotEmpty == true
                                        ? user!.name[0].toUpperCase()
                                        : 'E',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppTheme.greyColor),
                ),
                const SizedBox(height: 16),

                // Spot Check Banner
                if (_pendingSpotChecks.isNotEmpty)
                  _buildSpotCheckBanner(),
                const SizedBox(height: 8),

                // Today's Attendance Card
                _buildTodayAttendanceCard(attendanceProvider),
                const SizedBox(height: 20),

                // Quick Action Button
                _buildQuickActionButton(attendanceProvider),
                const SizedBox(height: 24),

                // Monthly Stats
                Text(
                  'This Month',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                _buildMonthlyStats(attendanceProvider),
                const SizedBox(height: 24),

                // Recent Activity
                Text(
                  'Recent Activity',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                _buildRecentActivity(attendanceProvider),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpotCheckBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFFF3B30)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B35).withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🔒 Face Verification Required',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'A random security check is pending. Please verify now.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () async {
              // Navigate to camera for face verification
              await Navigator.pushNamed(
                context,
                AppRoutes.camera,
              );
              // After returning, complete the spot check
              if (mounted) {
                final authProvider = context.read<AuthProvider>();
                if (authProvider.currentEmployee != null &&
                    _pendingSpotChecks.isNotEmpty) {
                  final spotCheck = _pendingSpotChecks.first;
                  await _dbService.completeSpotCheck(
                    spotCheck['id'],
                    null,
                    true,
                  );
                  _checkPendingSpotChecks(
                      authProvider.currentEmployee!.id);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFFF3B30),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
            ),
            child: const Text(
              'Verify',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayAttendanceCard(AttendanceProvider provider) {
    final attendance = provider.todayAttendance;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Today\'s Attendance',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  attendance != null
                      ? attendance.status.name.toUpperCase()
                      : 'NOT CHECKED IN',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildTimeColumn(
                  'Check In',
                  attendance?.checkIn != null
                      ? DateFormat('h:mm a').format(attendance!.checkIn!)
                      : '--:--',
                  Icons.login,
                ),
              ),
              Container(height: 60, width: 1, color: Colors.white24),
              Expanded(
                child: _buildTimeColumn(
                  'Check Out',
                  attendance?.checkOut != null
                      ? DateFormat('h:mm a').format(attendance!.checkOut!)
                      : '--:--',
                  Icons.logout,
                ),
              ),
              Container(height: 60, width: 1, color: Colors.white24),
              Expanded(
                child: _buildTimeColumn(
                  'Duration',
                  attendance?.formattedWorkDuration ?? '--:--',
                  Icons.timer_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeColumn(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton(AttendanceProvider provider) {
    final hasCheckedIn = provider.hasCheckedInToday;
    final hasCheckedOut = provider.hasCheckedOutToday;

    if (hasCheckedOut) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.successColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.successColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: AppTheme.successColor),
            const SizedBox(width: 12),
            Text(
              'Today\'s attendance completed!',
              style: TextStyle(
                color: AppTheme.successColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, AppRoutes.camera);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: hasCheckedIn
              ? const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                )
              : AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color:
                  (hasCheckedIn ? AppTheme.warningColor : AppTheme.primaryColor)
                      .withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasCheckedIn ? Icons.logout : Icons.camera_alt,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              hasCheckedIn ? 'Check Out Now' : 'Take Attendance',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyStats(AttendanceProvider provider) {
    final stats = provider.monthlyStats;

    if (stats == null) {
      return const Center(child: LoadingIndicator(size: 30));
    }

    final present = (stats['present'] ?? 0) as int;
    final absent = (stats['absent'] ?? 0) as int;
    final late = (stats['late'] ?? 0) as int;
    final totalHours = (stats['totalHours'] ?? 0) as int;
    final totalMinutes = (stats['totalMinutes'] ?? 0) as int;
    final total = present + absent + late;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Pie Chart
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F2937) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Pie Chart
              Expanded(
                child: total > 0
                    ? PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 35,
                          sections: [
                            PieChartSectionData(
                              value: present.toDouble(),
                              title: present > 0 ? '$present' : '',
                              color: AppTheme.successColor,
                              radius: 45,
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            PieChartSectionData(
                              value: absent.toDouble(),
                              title: absent > 0 ? '$absent' : '',
                              color: AppTheme.errorColor,
                              radius: 45,
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            PieChartSectionData(
                              value: late.toDouble(),
                              title: late > 0 ? '$late' : '',
                              color: AppTheme.warningColor,
                              radius: 45,
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Center(
                        child: Text(
                          'No data yet',
                          style: TextStyle(color: AppTheme.greyColor),
                        ),
                      ),
              ),
              // Legend
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLegendItem('Present', present, AppTheme.successColor),
                  const SizedBox(height: 8),
                  _buildLegendItem('Absent', absent, AppTheme.errorColor),
                  const SizedBox(height: 8),
                  _buildLegendItem('Late', late, AppTheme.warningColor),
                ],
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Stat Cards Row
        Row(
          children: [
            Expanded(
              child: StatCard(
                title: 'Present',
                value: '$present',
                icon: Icons.check_circle_outline,
                color: AppTheme.successColor,
                compact: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                title: 'Absent',
                value: '$absent',
                icon: Icons.cancel_outlined,
                color: AppTheme.errorColor,
                compact: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                title: 'Late',
                value: '$late',
                icon: Icons.schedule,
                color: AppTheme.warningColor,
                compact: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Total Hours Worked Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.access_time, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Text(
                'Total Hours: ${totalHours}h ${totalMinutes}m',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, int value, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text('$label: $value', style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildRecentActivity(AttendanceProvider provider) {
    final allHistory = provider.attendanceHistory;
    final history = allHistory.take(7).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (allHistory.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: Text('No recent activity')),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: history.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            ),
            itemBuilder: (context, index) {
              final attendance = history[index];
              return _buildActivityItem(attendance);
            },
          ),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AttendanceHistoryScreen(),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'View All History',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward,
                    color: AppTheme.primaryColor,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(AttendanceModel attendance) {
    Color statusColor;
    IconData statusIcon;

    switch (attendance.status) {
      case AttendanceStatus.present:
        statusColor = AppTheme.successColor;
        statusIcon = Icons.check_circle;
        break;
      case AttendanceStatus.late:
        statusColor = AppTheme.warningColor;
        statusIcon = Icons.schedule;
        break;
      case AttendanceStatus.absent:
        statusColor = AppTheme.errorColor;
        statusIcon = Icons.cancel;
        break;
      case AttendanceStatus.excused:
        statusColor = AppTheme.infoColor;
        statusIcon = Icons.info;
        break;
    }

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(statusIcon, color: statusColor, size: 20),
      ),
      title: Text(DateFormat('EEEE, MMM d').format(attendance.date)),
      subtitle: Text(
        attendance.hasCheckedIn
            ? '${DateFormat('h:mm a').format(attendance.checkIn!)} - ${attendance.hasCheckedOut ? DateFormat('h:mm a').format(attendance.checkOut!) : 'Not checked out'}'
            : 'No check-in',
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          attendance.status.name.toUpperCase(),
          style: TextStyle(
            color: statusColor,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 1) {
            Navigator.pushNamed(context, AppRoutes.camera);
          } else {
            setState(() => _currentIndex = index);
          }
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt_outlined),
            activeIcon: Icon(Icons.camera_alt),
            label: 'Camera',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
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

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning 👋';
    if (hour < 17) return 'Good Afternoon 👋';
    return 'Good Evening 👋';
  }
}

// Placeholder widget for camera tab navigation
class _CameraPlaceholder extends StatelessWidget {
  const _CameraPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Camera'));
  }
}
