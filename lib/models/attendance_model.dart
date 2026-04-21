import 'package:cloud_firestore/cloud_firestore.dart';

enum AttendanceStatus { present, absent, late, excused }

class AttendanceModel {
  final String id;
  final String employeeId;
  final DateTime date;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final AttendanceStatus status;
  final String? photoUrl;
  final GeoPoint? location;
  final GeoPoint? checkOutLocation;
  final bool isApproved;
  final String? notes;
  final List<Map<String, dynamic>> attempts;

  AttendanceModel({
    required this.id,
    required this.employeeId,
    required this.date,
    this.checkIn,
    this.checkOut,
    required this.status,
    this.photoUrl,
    this.location,
    this.checkOutLocation,
    this.isApproved = false,
    this.notes,
    this.attempts = const [],
  });

  factory AttendanceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AttendanceModel(
      id: doc.id,
      employeeId: data['employeeId'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      checkIn: (data['checkIn'] as Timestamp?)?.toDate(),
      checkOut: (data['checkOut'] as Timestamp?)?.toDate(),
      status: AttendanceStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => AttendanceStatus.absent,
      ),
      photoUrl: data['photoUrl'],
      location: data['location'] as GeoPoint?,
      checkOutLocation: data['checkOutLocation'] as GeoPoint?,
      isApproved: data['isApproved'] ?? false,
      notes: data['notes'],
      attempts: List<Map<String, dynamic>>.from(data['attempts'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'employeeId': employeeId,
      'date': Timestamp.fromDate(date),
      'checkIn': checkIn != null ? Timestamp.fromDate(checkIn!) : null,
      'checkOut': checkOut != null ? Timestamp.fromDate(checkOut!) : null,
      'status': status.name,
      'photoUrl': photoUrl,
      'location': location,
      'checkOutLocation': checkOutLocation,
      'isApproved': isApproved,
      'notes': notes,
      'attempts': attempts,
    };
  }

  AttendanceModel copyWith({
    String? id,
    String? employeeId,
    DateTime? date,
    DateTime? checkIn,
    DateTime? checkOut,
    AttendanceStatus? status,
    String? photoUrl,
    GeoPoint? location,
    GeoPoint? checkOutLocation,
    bool? isApproved,
    String? notes,
    List<Map<String, dynamic>>? attempts,
  }) {
    return AttendanceModel(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      date: date ?? this.date,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      status: status ?? this.status,
      photoUrl: photoUrl ?? this.photoUrl,
      location: location ?? this.location,
      checkOutLocation: checkOutLocation ?? this.checkOutLocation,
      isApproved: isApproved ?? this.isApproved,
      notes: notes ?? this.notes,
      attempts: attempts ?? this.attempts,
    );
  }

  // Helper getters
  bool get hasCheckedIn => checkIn != null;
  bool get hasCheckedOut => checkOut != null;

  Duration? get workDuration {
    if (checkIn != null && checkOut != null) {
      return checkOut!.difference(checkIn!);
    }
    return null;
  }

  String get formattedWorkDuration {
    final duration = workDuration;
    if (duration == null) return '--:--';
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }
}
