import 'package:cloud_firestore/cloud_firestore.dart';

class EmployeeModel {
  final String id;
  final String userId;
  final String employeeCode;
  final String position;
  final String? jobLevel;
  final double baseSalary;
  final DateTime joinDate;
  final List<String> faceEmbeddings;
  final List<String> trainingPhotoUrls;
  final String? managerId;
  final String? department;
  // Personal info (editable by employee)
  final String? phone;
  final String? address;
  final String? bankName;
  final String? bankAccountNumber;
  final String? bankAccountHolder;

  EmployeeModel({
    required this.id,
    required this.userId,
    required this.employeeCode,
    required this.position,
    this.jobLevel,
    required this.baseSalary,
    required this.joinDate,
    this.faceEmbeddings = const [],
    this.trainingPhotoUrls = const [],
    this.managerId,
    this.department,
    this.phone,
    this.address,
    this.bankName,
    this.bankAccountNumber,
    this.bankAccountHolder,
  });

  factory EmployeeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EmployeeModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      employeeCode: data['employeeCode'] ?? '',
      position: data['position'] ?? '',
      jobLevel: data['jobLevel'],
      baseSalary: (data['baseSalary'] ?? 0).toDouble(),
      joinDate: (data['joinDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      faceEmbeddings: List<String>.from(data['faceEmbeddings'] ?? []),
      trainingPhotoUrls: List<String>.from(data['trainingPhotoUrls'] ?? []),
      managerId: data['managerId'],
      department: data['department'],
      phone: data['phone'],
      address: data['address'],
      bankName: data['bankName'],
      bankAccountNumber: data['bankAccountNumber'],
      bankAccountHolder: data['bankAccountHolder'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'employeeCode': employeeCode,
      'position': position,
      'jobLevel': jobLevel,
      'baseSalary': baseSalary,
      'joinDate': Timestamp.fromDate(joinDate),
      'faceEmbeddings': faceEmbeddings,
      'trainingPhotoUrls': trainingPhotoUrls,
      'managerId': managerId,
      'department': department,
      'phone': phone,
      'address': address,
      'bankName': bankName,
      'bankAccountNumber': bankAccountNumber,
      'bankAccountHolder': bankAccountHolder,
    };
  }

  EmployeeModel copyWith({
    String? id,
    String? userId,
    String? employeeCode,
    String? position,
    String? jobLevel,
    double? baseSalary,
    DateTime? joinDate,
    List<String>? faceEmbeddings,
    List<String>? trainingPhotoUrls,
    String? managerId,
    String? department,
    String? phone,
    String? address,
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountHolder,
  }) {
    return EmployeeModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      employeeCode: employeeCode ?? this.employeeCode,
      position: position ?? this.position,
      jobLevel: jobLevel ?? this.jobLevel,
      baseSalary: baseSalary ?? this.baseSalary,
      joinDate: joinDate ?? this.joinDate,
      faceEmbeddings: faceEmbeddings ?? this.faceEmbeddings,
      trainingPhotoUrls: trainingPhotoUrls ?? this.trainingPhotoUrls,
      managerId: managerId ?? this.managerId,
      department: department ?? this.department,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      bankName: bankName ?? this.bankName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankAccountHolder: bankAccountHolder ?? this.bankAccountHolder,
    );
  }
}
