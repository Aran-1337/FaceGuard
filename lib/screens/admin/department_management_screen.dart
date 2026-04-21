import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../models/department_model.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_button.dart';

class DepartmentManagementScreen extends StatefulWidget {
  const DepartmentManagementScreen({super.key});

  @override
  State<DepartmentManagementScreen> createState() =>
      _DepartmentManagementScreenState();
}

class _DepartmentManagementScreenState
    extends State<DepartmentManagementScreen> {
  final DatabaseService _dbService = DatabaseService();

  void _showAddDepartmentDialog({DepartmentModel? existing}) {
    final formKey = GlobalKey<FormState>();
    String? selectedDepartmentName = existing?.name;
    String description = existing?.description ?? '';
    String? selectedManagerId = existing?.managerId;
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
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
                        existing != null ? 'Edit Department' : 'Add Department',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Department Name Dropdown
                  if (existing == null) ...[
                    DropdownButtonFormField<String>(
                      value: selectedDepartmentName,
                      decoration: const InputDecoration(
                        labelText: 'Department Name',
                        border: OutlineInputBorder(),
                      ),
                      items: AppConstants.departments
                          .map(
                            (d) => DropdownMenuItem(value: d, child: Text(d)),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setModalState(() => selectedDepartmentName = v),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                  ] else ...[
                    // Show readonly text when editing
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.business,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            existing.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  CustomTextField(
                    label: 'Description (Optional)',
                    hint: 'Brief description of the department',
                    initialValue: description,
                    maxLines: 2,
                    onChanged: (v) => description = v,
                  ),

                  const SizedBox(height: 16),
                  Text(
                    'Assign Manager (1 per department)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Each manager can only manage one department',
                    style: TextStyle(fontSize: 12, color: AppTheme.greyColor),
                  ),
                  const SizedBox(height: 8),

                  // Manager Selection - Only show unassigned managers
                  StreamBuilder<List<UserModel>>(
                    stream: _dbService.getUsers(),
                    builder: (context, usersSnapshot) {
                      return StreamBuilder<List<DepartmentModel>>(
                        stream: _dbService.getDepartments(),
                        builder: (context, deptSnapshot) {
                          final allManagers = (usersSnapshot.data ?? [])
                              .where((u) => u.role == UserRole.manager)
                              .toList();
                          final existingDepts = deptSnapshot.data ?? [];

                          // Get managers already assigned to other departments
                          final assignedManagerIds = existingDepts
                              .where(
                                (d) =>
                                    d.managerId != null && d.id != existing?.id,
                              )
                              .map((d) => d.managerId!)
                              .toSet();

                          // Filter to show only unassigned managers + current manager
                          final availableManagers = allManagers
                              .where(
                                (m) =>
                                    !assignedManagerIds.contains(m.uid) ||
                                    m.uid == selectedManagerId,
                              )
                              .toList();

                          return DropdownButtonFormField<String>(
                            value: selectedManagerId,
                            decoration: const InputDecoration(
                              hintText: 'Select a manager',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('No Manager'),
                              ),
                              ...availableManagers.map(
                                (m) => DropdownMenuItem(
                                  value: m.uid,
                                  child: Row(
                                    children: [
                                      Text(m.name),
                                      if (m.uid == selectedManagerId)
                                        const Text(
                                          ' (Current)',
                                          style: TextStyle(
                                            color: AppTheme.greyColor,
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (v) =>
                                setModalState(() => selectedManagerId = v),
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 24),
                  GradientButton(
                    text: existing != null
                        ? 'Update Department'
                        : 'Create Department',
                    isLoading: isLoading,
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      if (existing == null && selectedDepartmentName == null)
                        return;

                      setModalState(() => isLoading = true);

                      try {
                        final department = DepartmentModel(
                          id: existing?.id ?? const Uuid().v4(),
                          name: existing?.name ?? selectedDepartmentName!,
                          description: description.isEmpty ? null : description,
                          managerId: selectedManagerId,
                          createdAt: existing?.createdAt ?? DateTime.now(),
                          isActive: true,
                        );

                        if (existing != null) {
                          await _dbService.updateDepartment(department);
                        } else {
                          await _dbService.createDepartment(department);
                        }

                        // Update manager's departmentId if assigned
                        if (selectedManagerId != null) {
                          await _dbService.assignManagerToDepartment(
                            selectedManagerId!,
                            department.id,
                          );
                        }

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Department ${existing != null ? 'updated' : 'created'} successfully!',
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Departments')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDepartmentDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Department'),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: StreamBuilder<List<DepartmentModel>>(
        stream: _dbService.getDepartments(),
        builder: (context, deptSnapshot) {
          if (!deptSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final departments = deptSnapshot.data!;

          if (departments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.business_outlined,
                    size: 64,
                    color: AppTheme.greyColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No departments yet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the button below to create one',
                    style: TextStyle(color: AppTheme.greyColor),
                  ),
                ],
              ),
            );
          }

          return StreamBuilder<List<UserModel>>(
            stream: _dbService.getUsers(),
            builder: (context, usersSnapshot) {
              final users = usersSnapshot.data ?? [];

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: departments.length,
                itemBuilder: (context, index) {
                  final dept = departments[index];
                  final manager = dept.managerId != null
                      ? users.firstWhere(
                          (u) => u.uid == dept.managerId,
                          orElse: () => UserModel(
                            uid: '',
                            email: '',
                            name: 'Unknown',
                            role: UserRole.manager,
                            createdAt: DateTime.now(),
                          ),
                        )
                      : null;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      onTap: () => _showAddDepartmentDialog(existing: dept),
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryColor,
                        child: Text(
                          dept.name[0],
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(dept.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (dept.description != null)
                            Text(
                              dept.description!,
                              style: TextStyle(
                                color: AppTheme.greyColor,
                                fontSize: 12,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.person,
                                size: 14,
                                color: manager != null
                                    ? AppTheme.successColor
                                    : AppTheme.greyColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                manager != null
                                    ? manager.name
                                    : 'No manager assigned',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: manager != null
                                      ? AppTheme.successColor
                                      : AppTheme.greyColor,
                                  fontWeight: manager != null
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: Switch(
                        value: dept.isActive,
                        onChanged: (v) =>
                            _dbService.toggleDepartmentStatus(dept.id, v),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
