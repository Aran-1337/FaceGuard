import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../config/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/employee_provider.dart';
import '../../models/user_model.dart';
import '../../models/employee_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_button.dart';

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddEmployeeDialog() {
    final formKey = GlobalKey<FormState>();
    final authProvider = context.read<AuthProvider>();
    final manager = authProvider.currentUser;

    String name = '',
        email = '',
        password = '',
        position = '',
        jobLevel = '';
    String employeeCode = '...'; // Will be auto-generated
    String? selectedDepartment;
    double baseSalary = 0;
    bool isLoading = false;

    final dbService = DatabaseService();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          // Fetch code if not loaded yet
          if (employeeCode == '...') {
            dbService.getNextEmployeeCode().then((code) {
              setModalState(() => employeeCode = code);
            });
          }
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
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
                          'Add New Employee',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Department: ${manager?.departmentId ?? 'Your Department'}',
                      style: TextStyle(color: AppTheme.greyColor),
                    ),
                    const SizedBox(height: 12),
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
                    CustomTextField(
                      label: 'Full Name',
                      hint: 'Enter employee name',
                      onChanged: (v) => name = v,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: 'Email',
                      hint: 'Enter email address',
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (v) => email = v,
                      validator: (v) => v!.isEmpty || !v.contains('@')
                          ? 'Valid email required'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: 'Password',
                      hint: 'Create password (min 6 chars)',
                      obscureText: true,
                      onChanged: (v) => password = v,
                      validator: (v) =>
                          v!.length < 6 ? 'Min 6 characters' : null,
                    ),
                    const SizedBox(height: 16),

                    // Department selection
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
                    const SizedBox(height: 16),

                    // Position (filtered by department)
                    DropdownButtonFormField<String>(
                      value: position.isEmpty ? null : position,
                      decoration: const InputDecoration(
                        labelText: 'Position',
                        border: OutlineInputBorder(),
                      ),
                      items: AppConstants.getPositionsForDepartment(
                            selectedDepartment,
                          )
                          .map(
                            (p) =>
                                DropdownMenuItem(value: p, child: Text(p)),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setModalState(() => position = v ?? ''),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
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
                          .map((l) =>
                              DropdownMenuItem(value: l, child: Text(l)))
                          .toList(),
                      onChanged: (v) =>
                          setModalState(() => jobLevel = v ?? ''),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: 'Base Salary',
                      hint: 'Enter monthly salary',
                      keyboardType: TextInputType.number,
                      onChanged: (v) =>
                          baseSalary = double.tryParse(v) ?? 0,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 24),
                    GradientButton(
                      text: 'Add Employee',
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
                            role: UserRole.employee,
                            departmentId:
                                selectedDepartment ?? manager?.departmentId,
                          );

                          // Create employee profile
                          final employee = EmployeeModel(
                            id: const Uuid().v4(),
                            userId: newUser.uid,
                            employeeCode: employeeCode,
                            position: position,
                            jobLevel: jobLevel,
                            baseSalary: baseSalary,
                            joinDate: DateTime.now(),
                            managerId: manager?.uid,
                            department:
                                selectedDepartment ?? manager?.departmentId,
                          );

                          await dbService.createEmployee(employee);

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Employee $name added successfully!',
                                ),
                                backgroundColor: AppTheme.successColor,
                              ),
                            );
                          }
                        } catch (e) {
                          setModalState(() => isLoading = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
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
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final employeeProvider = context.watch<EmployeeProvider>();
    final employees = employeeProvider.employees.where((e) {
      if (_searchQuery.isEmpty) return true;
      return e.employeeCode.toLowerCase().contains(_searchQuery) ||
          e.position.toLowerCase().contains(_searchQuery) ||
          (e.department?.toLowerCase().contains(_searchQuery) ?? false);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Team Members')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddEmployeeDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Employee'),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SearchTextField(
              controller: _searchController,
              hint: 'Search employees...',
              onChanged: (value) =>
                  setState(() => _searchQuery = value.toLowerCase()),
              onClear: () => setState(() {
                _searchQuery = '';
                _searchController.clear();
              }),
            ),
          ),
          Expanded(
            child: employees.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: AppTheme.greyColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No employees yet',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap the button below to add your first employee',
                          style: TextStyle(color: AppTheme.greyColor),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: employees.length,
                    itemBuilder: (context, index) {
                      final employee = employees[index];
                      final user = employeeProvider.userMap[employee.userId];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          onTap: () => Navigator.pushNamed(
                            context,
                            AppRoutes.employeeDetail,
                            arguments: {'employeeId': employee.id},
                          ),
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryColor,
                            backgroundImage: user?.photoUrl != null
                                ? NetworkImage(user!.photoUrl!)
                                : null,
                            child: user?.photoUrl == null
                                ? Text(
                                    user?.name[0] ?? 'E',
                                    style: const TextStyle(color: Colors.white),
                                  )
                                : null,
                          ),
                          title: Text(user?.name ?? 'Employee'),
                          subtitle: Text(
                            '${employee.position} • ${employee.employeeCode}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Delete Employee'),
                                      content: Text('Are you sure you want to delete ${user?.name ?? "this employee"}? This action cannot be undone.'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () async {
                                            Navigator.pop(ctx);
                                            try {
                                              await employeeProvider.deleteEmployee(employee.id, employee.userId);
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Employee deleted successfully')),
                                                );
                                              }
                                            } catch (e) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Failed to delete: $e')),
                                                );
                                              }
                                            }
                                          },
                                          child: const Text('Delete', style: TextStyle(color: AppTheme.errorColor)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              const Icon(Icons.chevron_right),
                            ],
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
}
