import 'package:cloud_firestore/cloud_firestore.dart';

enum PunishmentType { warning, fine, suspension }

class PunishmentModel {
  final String id;
  final String employeeId;
  final PunishmentType type;
  final String reason;
  final double? fineAmount;
  final DateTime issuedAt;
  final String issuedBy;
  final int? suspensionDays;
  final bool isActive;

  PunishmentModel({
    required this.id,
    required this.employeeId,
    required this.type,
    required this.reason,
    this.fineAmount,
    required this.issuedAt,
    required this.issuedBy,
    this.suspensionDays,
    this.isActive = true,
  });

  factory PunishmentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PunishmentModel(
      id: doc.id,
      employeeId: data['employeeId'] ?? '',
      type: PunishmentType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => PunishmentType.warning,
      ),
      reason: data['reason'] ?? '',
      fineAmount: (data['fineAmount'] as num?)?.toDouble(),
      issuedAt: (data['issuedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      issuedBy: data['issuedBy'] ?? '',
      suspensionDays: data['suspensionDays'] as int?,
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'employeeId': employeeId,
      'type': type.name,
      'reason': reason,
      'fineAmount': fineAmount,
      'issuedAt': Timestamp.fromDate(issuedAt),
      'issuedBy': issuedBy,
      'suspensionDays': suspensionDays,
      'isActive': isActive,
    };
  }

  PunishmentModel copyWith({
    String? id,
    String? employeeId,
    PunishmentType? type,
    String? reason,
    double? fineAmount,
    DateTime? issuedAt,
    String? issuedBy,
    int? suspensionDays,
    bool? isActive,
  }) {
    return PunishmentModel(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      type: type ?? this.type,
      reason: reason ?? this.reason,
      fineAmount: fineAmount ?? this.fineAmount,
      issuedAt: issuedAt ?? this.issuedAt,
      issuedBy: issuedBy ?? this.issuedBy,
      suspensionDays: suspensionDays ?? this.suspensionDays,
      isActive: isActive ?? this.isActive,
    );
  }

  String get typeLabel {
    switch (type) {
      case PunishmentType.warning:
        return 'Warning';
      case PunishmentType.fine:
        return 'Fine';
      case PunishmentType.suspension:
        return 'Suspension';
    }
  }
}
