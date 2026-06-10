import 'package:cloud_firestore/cloud_firestore.dart';

enum LeaveType { annual, sick, emergency, unpaid, other }

enum LeaveStatus { pending, approved, rejected }

class LeaveRequestModel {
  final String id;
  final String employeeId;
  final String employeeName;
  final String managerId;
  final LeaveType type;
  final DateTime fromDate;
  final DateTime toDate;
  final String reason;
  final LeaveStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final String? managerNote;

  LeaveRequestModel({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.managerId,
    required this.type,
    required this.fromDate,
    required this.toDate,
    required this.reason,
    this.status = LeaveStatus.pending,
    required this.createdAt,
    this.respondedAt,
    this.managerNote,
  });

  int get daysCount => toDate.difference(fromDate).inDays + 1;

  String get typeLabel {
    switch (type) {
      case LeaveType.annual:
        return 'Annual Leave';
      case LeaveType.sick:
        return 'Sick Leave';
      case LeaveType.emergency:
        return 'Emergency Leave';
      case LeaveType.unpaid:
        return 'Unpaid Leave';
      case LeaveType.other:
        return 'Other';
    }
  }

  String get statusLabel {
    switch (status) {
      case LeaveStatus.pending:
        return 'Pending';
      case LeaveStatus.approved:
        return 'Approved';
      case LeaveStatus.rejected:
        return 'Rejected';
    }
  }

  factory LeaveRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LeaveRequestModel(
      id: doc.id,
      employeeId: data['employeeId'] ?? '',
      employeeName: data['employeeName'] ?? '',
      managerId: data['managerId'] ?? '',
      type: LeaveType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => LeaveType.other,
      ),
      fromDate: (data['fromDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      toDate: (data['toDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reason: data['reason'] ?? '',
      status: LeaveStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => LeaveStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (data['respondedAt'] as Timestamp?)?.toDate(),
      managerNote: data['managerNote'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'employeeId': employeeId,
      'employeeName': employeeName,
      'managerId': managerId,
      'type': type.name,
      'fromDate': Timestamp.fromDate(fromDate),
      'toDate': Timestamp.fromDate(toDate),
      'reason': reason,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'respondedAt': respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
      'managerNote': managerNote,
    };
  }

  LeaveRequestModel copyWith({
    String? id,
    String? employeeId,
    String? employeeName,
    String? managerId,
    LeaveType? type,
    DateTime? fromDate,
    DateTime? toDate,
    String? reason,
    LeaveStatus? status,
    DateTime? createdAt,
    DateTime? respondedAt,
    String? managerNote,
  }) {
    return LeaveRequestModel(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      managerId: managerId ?? this.managerId,
      type: type ?? this.type,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
      managerNote: managerNote ?? this.managerNote,
    );
  }
}
