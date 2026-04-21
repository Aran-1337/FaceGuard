import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../models/user_model.dart';
import '../../models/employee_model.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_button.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _roleFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddUserDialog() {
    final formKey = GlobalKey<FormState>();
    String name = '',
        email = '',
        password = '',
        position = '',
        jobLevel = '';
    String employeeCode = '...'; // Will be auto-generated
    double baseSalary = 0;
    UserRole role = UserRole.employee;
    String? selectedDepartment;
    String? selectedManagerId;
    bool isLoading = false;

    final navigator = Navigator.of(context);

    // Auto-generate code
    _dbService.getNextEmployeeCode().then((code) {
      employeeCode = code;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (buildContext, setModalState) {
          // Fetch code if not loaded yet
          if (employeeCode == '...') {
            _dbService.getNextEmployeeCode().then((code) {
              setModalState(() => employeeCode = code);
            });
          }
          return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(buildContext).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 50,
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Add New User',
                          style: Theme.of(
                            buildContext,
                          ).textTheme.headlineMedium,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => navigator.pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Basic Info
                    CustomTextField(
                      label: 'Full Name',
                      hint: 'Enter name',
                      onChanged: (v) => name = v,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: 'Email',
                      hint: 'Enter email',
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (v) => email = v,
                      validator: (v) => v!.isEmpty || !v.contains('@')
                          ? 'Valid email required'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: 'Password',
                      hint: 'Min 6 characters',
                      obscureText: true,
                      onChanged: (v) => password = v,
                      validator: (v) =>
                          v!.length < 6 ? 'Min 6 characters' : null,
                    ),
                    const SizedBox(height: 16),

                    // Role Selection
                    DropdownButtonFormField<UserRole>(
                      value: role,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        border: OutlineInputBorder(),
                      ),
                      items: UserRole.values
                          .map(
                            (r) => DropdownMenuItem(
                              value: r,
                              child: Text(r.name.toUpperCase()),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setModalState(() => role = v!),
                    ),
                    const SizedBox(height: 16),

                    // Department Selection
                    DropdownButtonFormField<String>(
                      value: selectedDepartment,
                      decoration: const InputDecoration(
                        labelText: 'Department',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('No Department'),
                        ),
                        ...AppConstants.departments.map(
                          (d) => DropdownMenuItem(value: d, child: Text(d)),
                        ),
                      ],
                      onChanged: (v) {
                        setModalState(() {
                          selectedDepartment = v;
                          position = '';
                        });
                      },
                    ),

                    // Show employee-specific fields when role is employee
                    if (role == UserRole.employee) ...[
                      const SizedBox(height: 16),

                      // Auto-generated Employee Code
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color:
                                  AppTheme.primaryColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.badge,
                                color: AppTheme.primaryColor, size: 20),
                            const SizedBox(width: 12),
                            Text('Employee Code: ',
                                style: TextStyle(color: AppTheme.greyColor)),
                            Text(
                              employeeCode,
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Manager Selection
                      StreamBuilder<List<UserModel>>(
                        stream: _dbService.getUsers(),
                        builder: (context, snapshot) {
                          final managers = (snapshot.data ?? [])
                              .where((u) => u.role == UserRole.manager)
                              .toList();
                          return DropdownButtonFormField<String>(
                            value: selectedManagerId,
                            decoration: const InputDecoration(
                              labelText: 'Assign Manager',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('No Manager'),
                              ),
                              ...managers.map(
                                (m) => DropdownMenuItem(
                                  value: m.uid,
                                  child: Text(m.name),
                                ),
                              ),
                            ],
                            onChanged: (v) =>
                                setModalState(() => selectedManagerId = v),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: position.isEmpty ? null : position,
                        decoration: const InputDecoration(
                          labelText: 'Position',
                          border: OutlineInputBorder(),
                        ),
                        items:
                            AppConstants.getPositionsForDepartment(
                                  selectedDepartment,
                                )
                                .map(
                                  (p) => DropdownMenuItem(
                                    value: p,
                                    child: Text(p),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) =>
                            setModalState(() => position = v ?? ''),
                        validator: (v) =>
                            role == UserRole.employee &&
                                (v == null || v.isEmpty)
                            ? 'Required'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // Job Level
                      DropdownButtonFormField<String>(
                        value: jobLevel.isEmpty ? null : jobLevel,
                        decoration: const InputDecoration(
                          labelText: 'Job Level',
                          border: OutlineInputBorder(),
                        ),
                        items: AppConstants.jobLevels
                            .map(
                              (l) => DropdownMenuItem(value: l, child: Text(l)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setModalState(() => jobLevel = v ?? ''),
                        validator: (v) =>
                            role == UserRole.employee &&
                                (v == null || v.isEmpty)
                            ? 'Required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        label: 'Base Salary',
                        hint: 'Monthly salary',
                        keyboardType: TextInputType.number,
                        onChanged: (v) => baseSalary = double.tryParse(v) ?? 0,
                        validator: (v) =>
                            role == UserRole.employee && v!.isEmpty
                            ? 'Required'
                            : null,
                      ),
                    ],

                    const SizedBox(height: 24),
                    GradientButton(
                      text: 'Create User',
                      isLoading: isLoading,
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;

                        setModalState(() => isLoading = true);

                        try {
                          final authService = AuthService();

                          // Create user account
                          final newUser = await authService.createUser(
                            email: email,
                            password: password,
                            name: name,
                            role: role,
                            departmentId: selectedDepartment,
                          );

                          // If employee, create employee profile
                          if (role == UserRole.employee) {
                            final employee = EmployeeModel(
                              id: const Uuid().v4(),
                              userId: newUser.uid,
                              employeeCode: employeeCode,
                              position: position,
                              jobLevel: jobLevel,
                              baseSalary: baseSalary,
                              joinDate: DateTime.now(),
                              managerId: selectedManagerId,
                              department: selectedDepartment,
                            );
                            await _dbService.createEmployee(employee);
                          }

                          if (buildContext.mounted) {
                            navigator.pop();
                            ScaffoldMessenger.of(buildContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${role.name.toUpperCase()} $name created successfully!',
                                ),
                                backgroundColor: AppTheme.successColor,
                              ),
                            );
                          }
                        } catch (e) {
                          setModalState(() => isLoading = false);
                          if (buildContext.mounted) {
                            ScaffoldMessenger.of(buildContext).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: AppTheme.errorColor,
                              ),
                            );
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
          );
        },
      ),
    );
  }

  void _showEditUserDialog(UserModel user) {
    final navigator = Navigator.of(context);
    String name = user.name;
    String? selectedDepartment = user.departmentId;
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (buildContext, setModalState) => Padding(
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
                      'Edit User',
                      style: Theme.of(buildContext).textTheme.headlineMedium,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => navigator.pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // User info header
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getRoleColor(user.role).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _getRoleColor(user.role),
                        child: Text(
                          user.name[0],
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.email,
                              style: TextStyle(color: AppTheme.greyColor),
                            ),
                            Text(
                              user.role.name.toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _getRoleColor(user.role),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Editable name
                CustomTextField(
                  label: 'Name',
                  initialValue: name,
                  onChanged: (v) => name = v,
                ),
                const SizedBox(height: 16),

                // Department
                DropdownButtonFormField<String>(
                  value: selectedDepartment,
                  decoration: const InputDecoration(
                    labelText: 'Department',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('No Department'),
                    ),
                    ...AppConstants.departments.map(
                      (d) => DropdownMenuItem(value: d, child: Text(d)),
                    ),
                  ],
                  onChanged: (v) => setModalState(() => selectedDepartment = v),
                ),

                const SizedBox(height: 24),

                // Save button
                GradientButton(
                  text: 'Save Changes',
                  isLoading: isLoading,
                  onPressed: () async {
                    setModalState(() => isLoading = true);
                    try {
                      final updatedUser = user.copyWith(
                        name: name,
                        departmentId: selectedDepartment,
                      );
                      await _dbService.updateUser(updatedUser);
                      if (buildContext.mounted) {
                        navigator.pop();
                        ScaffoldMessenger.of(buildContext).showSnackBar(
                          const SnackBar(
                            content: Text('User updated!'),
                            backgroundColor: AppTheme.successColor,
                          ),
                        );
                      }
                    } catch (e) {
                      setModalState(() => isLoading = false);
                      if (buildContext.mounted) {
                        ScaffoldMessenger.of(buildContext).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: AppTheme.errorColor,
                          ),
                        );
                      }
                    }
                  },
                ),
                const SizedBox(height: 12),

                // Delete button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: buildContext,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Delete User?'),
                          content: Text(
                            'Are you sure you want to delete ${user.name}? This action cannot be undone.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                Navigator.pop(dialogContext);
                                navigator.pop();
                                await _dbService.deleteUser(
                                  user.uid,
                                  hardDelete: true,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('${user.name} deleted'),
                                      backgroundColor: AppTheme.errorColor,
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.errorColor,
                              ),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.delete_forever,
                      color: AppTheme.errorColor,
                    ),
                    label: const Text(
                      'Delete User',
                      style: TextStyle(color: AppTheme.errorColor),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.errorColor),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Management')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddUserDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Add User'),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SearchTextField(
                  controller: _searchController,
                  hint: 'Search users...',
                  onChanged: (v) =>
                      setState(() => _searchQuery = v.toLowerCase()),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'all'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Employees', 'employee'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Managers', 'manager'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Admins', 'admin'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: _dbService.getUsers(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                var users = snapshot.data!.where((u) {
                  bool matchesSearch =
                      _searchQuery.isEmpty ||
                      u.name.toLowerCase().contains(_searchQuery) ||
                      u.email.toLowerCase().contains(_searchQuery);
                  bool matchesRole =
                      _roleFilter == 'all' || u.role.name == _roleFilter;
                  return matchesSearch && matchesRole;
                }).toList();
                if (users.isEmpty)
                  return const Center(child: Text('No users found'));
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        onTap: () => _showEditUserDialog(user),
                        leading: CircleAvatar(
                          backgroundColor: _getRoleColor(user.role),
                          child: Text(
                            user.name[0],
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(user.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.email),
                            if (user.departmentId != null)
                              Text(
                                'Dept: ${user.departmentId}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.greyColor,
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Chip(
                              label: Text(
                                user.role.name.toUpperCase(),
                                style: const TextStyle(fontSize: 10),
                              ),
                              backgroundColor: _getRoleColor(
                                user.role,
                              ).withValues(alpha: 0.1),
                            ),
                            Switch(
                              value: user.isActive,
                              onChanged: (v) =>
                                  _dbService.toggleUserStatus(user.uid, v),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _roleFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _roleFilter = value),
      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
      checkmarkColor: AppTheme.primaryColor,
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.employee:
        return AppTheme.primaryColor;
      case UserRole.manager:
        return AppTheme.secondaryColor;
      case UserRole.admin:
        return AppTheme.errorColor;
    }
  }
}
