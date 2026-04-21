import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/salary_model.dart';
import '../../services/database_service.dart';

class SalaryManagementScreen extends StatefulWidget {
  const SalaryManagementScreen({super.key});

  @override
  State<SalaryManagementScreen> createState() => _SalaryManagementScreenState();
}

class _SalaryManagementScreenState extends State<SalaryManagementScreen> {
  final DatabaseService _dbService = DatabaseService();
  DateTime _selectedMonth = DateTime.now();
  String _statusFilter = 'all';

  void _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) setState(() => _selectedMonth = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Salary Management')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickMonth,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 12),
                        Text(DateFormat('MMMM yyyy').format(_selectedMonth)),
                        Spacer(),
                        Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'all'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Pending', 'pending'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Paid', 'paid'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Delayed', 'delayed'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<SalaryModel>>(
              stream: _dbService.getSalariesByMonth(_selectedMonth),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return Center(child: CircularProgressIndicator());
                var salaries = snapshot.data!
                    .where(
                      (s) =>
                          _statusFilter == 'all' ||
                          s.status.name == _statusFilter,
                    )
                    .toList();
                if (salaries.isEmpty)
                  return Center(
                    child: Text('No salary records for this month'),
                  );
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: salaries.length,
                  itemBuilder: (context, index) {
                    final salary = salaries[index];
                    Color statusColor = salary.status == SalaryStatus.paid
                        ? AppTheme.successColor
                        : salary.status == SalaryStatus.pending
                        ? AppTheme.warningColor
                        : AppTheme.errorColor;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: statusColor.withValues(alpha: 0.1),
                          child: Icon(
                            salary.status == SalaryStatus.paid
                                ? Icons.check
                                : Icons.pending,
                            color: statusColor,
                          ),
                        ),
                        title: Text(
                          'Employee: ${salary.employeeId.substring(0, 8)}...',
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Base: \$${salary.amount.toStringAsFixed(2)}'),
                            Text(
                              'Net: \$${salary.netAmount.toStringAsFixed(2)}',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        trailing: salary.status != SalaryStatus.paid
                            ? ElevatedButton(
                                onPressed: () =>
                                    _dbService.markSalaryAsPaid(salary.id),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.successColor,
                                ),
                                child: Text('Pay'),
                              )
                            : Chip(
                                label: Text('PAID'),
                                backgroundColor: AppTheme.successColor
                                    .withValues(alpha: 0.1),
                              ),
                        isThreeLine: true,
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
    final isSelected = _statusFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _statusFilter = value),
      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
    );
  }
}
