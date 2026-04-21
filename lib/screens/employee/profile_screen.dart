import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../models/attendance_model.dart';
import '../../models/salary_model.dart';
import '../../models/punishment_model.dart';
import '../../services/database_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/common/custom_text_field.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseService _dbService = DatabaseService();
  final StorageService _storageService = StorageService();
  final ImagePicker _imagePicker = ImagePicker();
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null) return;

    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _isUploadingImage = true);
    try {
      final photoUrl = await _storageService.uploadProfileImage(
        user.uid,
        File(picked.path),
      );
      final updatedUser = user.copyWith(photoUrl: photoUrl);
      await _dbService.updateUser(updatedUser);
      await authProvider.refreshUser();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated!'),
            backgroundColor: AppTheme.successColor,
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
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  void _showEditPersonalInfoDialog() {
    final authProvider = context.read<AuthProvider>();
    final employee = authProvider.currentEmployee;
    if (employee == null) return;

    final navigator = Navigator.of(context);
    String phone = employee.phone ?? '';
    String address = employee.address ?? '';
    String bankName = employee.bankName ?? '';
    String bankAccountNumber = employee.bankAccountNumber ?? '';
    String bankAccountHolder = employee.bankAccountHolder ?? '';
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (buildContext, setModalState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(buildContext).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Edit Personal Info',
                        style: Theme.of(buildContext).textTheme.headlineMedium,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => navigator.pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Contact Info Section
                  Text(
                    'Contact Information',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    label: 'Phone Number',
                    initialValue: phone,
                    keyboardType: TextInputType.phone,
                    prefixIcon: Icons.phone,
                    onChanged: (v) => phone = v,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    label: 'Address',
                    initialValue: address,
                    prefixIcon: Icons.location_on,
                    maxLines: 2,
                    onChanged: (v) => address = v,
                  ),

                  const SizedBox(height: 24),

                  // Bank Info Section
                  Text(
                    'Bank Information',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    label: 'Bank Name',
                    initialValue: bankName,
                    prefixIcon: Icons.account_balance,
                    onChanged: (v) => bankName = v,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    label: 'Account Number',
                    initialValue: bankAccountNumber,
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.credit_card,
                    onChanged: (v) => bankAccountNumber = v,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    label: 'Account Holder Name',
                    initialValue: bankAccountHolder,
                    prefixIcon: Icons.person,
                    onChanged: (v) => bankAccountHolder = v,
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              setModalState(() => isLoading = true);
                              try {
                                final updatedEmployee = employee.copyWith(
                                  phone: phone.isEmpty ? null : phone,
                                  address: address.isEmpty ? null : address,
                                  bankName: bankName.isEmpty ? null : bankName,
                                  bankAccountNumber: bankAccountNumber.isEmpty
                                      ? null
                                      : bankAccountNumber,
                                  bankAccountHolder: bankAccountHolder.isEmpty
                                      ? null
                                      : bankAccountHolder,
                                );
                                await _dbService.updateEmployee(
                                  updatedEmployee,
                                );
                                await authProvider.refreshUser();
                                if (buildContext.mounted) {
                                  navigator.pop();
                                  ScaffoldMessenger.of(
                                    buildContext,
                                  ).showSnackBar(
                                    const SnackBar(
                                      content: Text('Personal info updated!'),
                                      backgroundColor: AppTheme.successColor,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setModalState(() => isLoading = false);
                                if (buildContext.mounted) {
                                  ScaffoldMessenger.of(
                                    buildContext,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: $e'),
                                      backgroundColor: AppTheme.errorColor,
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save Changes'),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final employee = authProvider.currentEmployee;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header Card
            Container(
              margin: const EdgeInsets.all(16),
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
                children: [
                  // Profile Image
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 45,
                        backgroundColor: Colors.white,
                        backgroundImage: user?.photoUrl != null
                            ? NetworkImage(user!.photoUrl!)
                            : null,
                        child: _isUploadingImage
                            ? const CircularProgressIndicator()
                            : user?.photoUrl == null
                            ? Text(
                                user?.name[0] ?? 'E',
                                style: TextStyle(
                                  fontSize: 36,
                                  color: AppTheme.primaryColor,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _isUploadingImage ? null : _pickAndUploadImage,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: Colors.black26, blurRadius: 4),
                              ],
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              size: 18,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.name ?? 'Employee',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? '',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  // Role and Employee Code
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildBadge(user?.role.name.toUpperCase() ?? 'USER'),
                      if (employee != null) ...[
                        const SizedBox(width: 8),
                        _buildBadge(employee.employeeCode),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Work Information (Read-only)
            _buildInfoSection(
              title: 'Work Information',
              icon: Icons.work,
              items: [
                _InfoItem('Department', employee?.department ?? 'Not assigned'),
                _InfoItem('Position', employee?.position ?? 'Not assigned'),
                _InfoItem('Job Level', employee?.jobLevel ?? 'Not specified'),
                _InfoItem(
                  'Join Date',
                  employee != null
                      ? DateFormat('MMM d, yyyy').format(employee.joinDate)
                      : 'N/A',
                ),
              ],
            ),

            // Personal Information (Editable)
            _buildInfoSection(
              title: 'Personal Information',
              icon: Icons.person,
              isEditable: true,
              onEdit: _showEditPersonalInfoDialog,
              items: [
                _InfoItem('Phone', employee?.phone ?? 'Not provided'),
                _InfoItem('Address', employee?.address ?? 'Not provided'),
              ],
            ),

            // Bank Information (Editable)
            _buildInfoSection(
              title: 'Bank Information',
              icon: Icons.account_balance,
              isEditable: true,
              onEdit: _showEditPersonalInfoDialog,
              items: [
                _InfoItem('Bank', employee?.bankName ?? 'Not provided'),
                _InfoItem(
                  'Account',
                  employee?.bankAccountNumber ?? 'Not provided',
                ),
                _InfoItem(
                  'Holder',
                  employee?.bankAccountHolder ?? 'Not provided',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Tabs Section (Attendance, Salary, Punishments)
            Container(
              color: isDark ? const Color(0xFF1F2937) : Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: AppTheme.primaryColor,
                unselectedLabelColor: AppTheme.greyColor,
                indicatorColor: AppTheme.primaryColor,
                tabs: const [
                  Tab(icon: Icon(Icons.calendar_today), text: 'Attendance'),
                  Tab(icon: Icon(Icons.attach_money), text: 'Salary'),
                  Tab(icon: Icon(Icons.warning), text: 'Punishments'),
                ],
              ),
            ),

            // Tab Content
            SizedBox(
              height: 400,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAttendanceTab(),
                  _buildSalaryTab(),
                  _buildPunishmentsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoSection({
    required String title,
    required IconData icon,
    required List<_InfoItem> items,
    bool isEditable = false,
    VoidCallback? onEdit,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              if (isEditable)
                GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.edit,
                      size: 16,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text(
                    item.label,
                    style: TextStyle(color: AppTheme.greyColor, fontSize: 13),
                  ),
                  const Spacer(),
                  Text(
                    item.value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceTab() {
    final attendanceProvider = context.watch<AttendanceProvider>();
    final history = attendanceProvider.attendanceHistory;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                final attendance = history
                    .where((a) => isSameDay(a.date, date))
                    .firstOrNull;
                if (attendance == null) return null;
                Color color = attendance.status == AttendanceStatus.present
                    ? AppTheme.successColor
                    : attendance.status == AttendanceStatus.late
                    ? AppTheme.warningColor
                    : AppTheme.errorColor;
                return Positioned(
                  bottom: 1,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryTab() {
    final authProvider = context.read<AuthProvider>();
    final employeeId = authProvider.currentEmployee?.id ?? '';

    return StreamBuilder<List<SalaryModel>>(
      stream: _dbService.getEmployeeSalaries(employeeId),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final salaries = snapshot.data!;
        if (salaries.isEmpty)
          return const Center(child: Text('No salary records'));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: salaries.length,
          itemBuilder: (context, index) {
            final salary = salaries[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Icon(
                  salary.status == SalaryStatus.paid
                      ? Icons.check_circle
                      : Icons.pending,
                  color: salary.status == SalaryStatus.paid
                      ? AppTheme.successColor
                      : AppTheme.warningColor,
                ),
                title: Text(salary.monthName),
                subtitle: Text('Net: \$${salary.netAmount.toStringAsFixed(2)}'),
                trailing: Chip(
                  label: Text(salary.status.name.toUpperCase()),
                  backgroundColor: salary.status == SalaryStatus.paid
                      ? AppTheme.successColor.withValues(alpha: 0.1)
                      : AppTheme.warningColor.withValues(alpha: 0.1),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPunishmentsTab() {
    final authProvider = context.read<AuthProvider>();
    final employeeId = authProvider.currentEmployee?.id ?? '';

    return StreamBuilder<List<PunishmentModel>>(
      stream: _dbService.getEmployeePunishments(employeeId),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final punishments = snapshot.data!;
        if (punishments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle,
                  size: 48,
                  color: AppTheme.successColor,
                ),
                const SizedBox(height: 16),
                const Text('No punishments! Great job!'),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: punishments.length,
          itemBuilder: (context, index) {
            final p = punishments[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Icon(
                  p.type == PunishmentType.warning
                      ? Icons.warning
                      : Icons.money_off,
                  color: AppTheme.errorColor,
                ),
                title: Text(p.typeLabel),
                subtitle: Text(p.reason),
                trailing: Text(DateFormat('MMM d').format(p.issuedAt)),
              ),
            );
          },
        );
      },
    );
  }
}

class _InfoItem {
  final String label;
  final String value;

  _InfoItem(this.label, this.value);
}
