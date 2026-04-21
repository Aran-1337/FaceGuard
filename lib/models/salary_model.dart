import 'package:cloud_firestore/cloud_firestore.dart';

enum SalaryStatus { pending, paid, delayed }

class SalaryModel {
  final String id;
  final String employeeId;
  final double amount;
  final double deductions;
  final double bonus;
  final DateTime month;
  final SalaryStatus status;
  final DateTime? paidAt;
  final String? notes;

  SalaryModel({
    required this.id,
    required this.employeeId,
    required this.amount,
    this.deductions = 0,
    this.bonus = 0,
    required this.month,
    required this.status,
    this.paidAt,
    this.notes,
  });

  double get netAmount => amount - deductions + bonus;

  factory SalaryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SalaryModel(
      id: doc.id,
      employeeId: data['employeeId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      deductions: (data['deductions'] ?? 0).toDouble(),
      bonus: (data['bonus'] ?? 0).toDouble(),
      month: (data['month'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: SalaryStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => SalaryStatus.pending,
      ),
      paidAt: (data['paidAt'] as Timestamp?)?.toDate(),
      notes: data['notes'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'employeeId': employeeId,
      'amount': amount,
      'deductions': deductions,
      'bonus': bonus,
      'month': Timestamp.fromDate(month),
      'status': status.name,
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      'notes': notes,
    };
  }

  SalaryModel copyWith({
    String? id,
    String? employeeId,
    double? amount,
    double? deductions,
    double? bonus,
    DateTime? month,
    SalaryStatus? status,
    DateTime? paidAt,
    String? notes,
  }) {
    return SalaryModel(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      amount: amount ?? this.amount,
      deductions: deductions ?? this.deductions,
      bonus: bonus ?? this.bonus,
      month: month ?? this.month,
      status: status ?? this.status,
      paidAt: paidAt ?? this.paidAt,
      notes: notes ?? this.notes,
    );
  }

  String get monthName {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[month.month - 1]} ${month.year}';
  }
}
