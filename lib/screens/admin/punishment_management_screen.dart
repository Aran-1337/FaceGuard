import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../config/theme.dart';
import '../../models/punishment_model.dart';
import '../../services/database_service.dart';
import '../../widgets/common/custom_button.dart';

class PunishmentManagementScreen extends StatefulWidget {
  const PunishmentManagementScreen({super.key});

  @override
  State<PunishmentManagementScreen> createState() =>
      _PunishmentManagementScreenState();
}

class _PunishmentManagementScreenState
    extends State<PunishmentManagementScreen> {
  final DatabaseService _dbService = DatabaseService();
  String _typeFilter = 'all';

  void _showAddPunishmentDialog() {
    String employeeId = '', reason = '';
    PunishmentType type = PunishmentType.warning;
    double? fineAmount;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Punishment',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            TextField(
              decoration: InputDecoration(labelText: 'Employee ID'),
              onChanged: (v) => employeeId = v,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PunishmentType>(
              value: type,
              decoration: InputDecoration(labelText: 'Type'),
              items: PunishmentType.values
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(t.name.toUpperCase()),
                    ),
                  )
                  .toList(),
              onChanged: (v) => type = v!,
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(labelText: 'Reason'),
              maxLines: 2,
              onChanged: (v) => reason = v,
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(labelText: 'Fine Amount (optional)'),
              keyboardType: TextInputType.number,
              onChanged: (v) => fineAmount = double.tryParse(v),
            ),
            const SizedBox(height: 24),
            GradientButton(
              text: 'Add Punishment',
              onPressed: () async {
                if (employeeId.isEmpty || reason.isEmpty) return;
                final punishment = PunishmentModel(
                  id: const Uuid().v4(),
                  employeeId: employeeId,
                  type: type,
                  reason: reason,
                  fineAmount: fineAmount,
                  issuedAt: DateTime.now(),
                  issuedBy: 'admin',
                );
                await _dbService.createPunishment(punishment);
                if (mounted) Navigator.pop(context);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Punishment Management')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPunishmentDialog,
        child: Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Warnings', 'warning'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Fines', 'fine'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Suspensions', 'suspension'),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<PunishmentModel>>(
              stream: _dbService.getAllPunishments(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return Center(child: CircularProgressIndicator());
                var punishments = snapshot.data!
                    .where(
                      (p) => _typeFilter == 'all' || p.type.name == _typeFilter,
                    )
                    .toList();
                if (punishments.isEmpty)
                  return Center(child: Text('No punishments found'));
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: punishments.length,
                  itemBuilder: (context, index) {
                    final p = punishments[index];
                    Color typeColor = p.type == PunishmentType.warning
                        ? AppTheme.warningColor
                        : p.type == PunishmentType.fine
                        ? AppTheme.errorColor
                        : Colors.purple;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: typeColor.withValues(alpha: 0.1),
                          child: Icon(
                            p.type == PunishmentType.warning
                                ? Icons.warning
                                : Icons.money_off,
                            color: typeColor,
                          ),
                        ),
                        title: Text(p.typeLabel),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.reason),
                            Text(
                              'Issued: ${DateFormat('MMM d, yyyy').format(p.issuedAt)}',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        trailing: p.isActive
                            ? IconButton(
                                icon: Icon(Icons.check_circle_outline),
                                onPressed: () =>
                                    _dbService.deactivatePunishment(p.id),
                              )
                            : Chip(label: Text('Resolved')),
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
    final isSelected = _typeFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _typeFilter = value),
      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
    );
  }
}
