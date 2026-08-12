import 'service_branch.dart';

class ServiceRole {
  final int id;
  final String code;
  final String nameAr;
  final String nameEn;

  const ServiceRole({
    required this.id,
    required this.code,
    required this.nameAr,
    required this.nameEn,
  });

  factory ServiceRole.fromJson(Map<String, dynamic> json) {
    return ServiceRole(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      code: '${json['code'] ?? ''}',
      nameAr: '${json['name_ar'] ?? ''}',
      nameEn: '${json['name_en'] ?? ''}',
    );
  }

  String name(bool isArabic) {
    if (isArabic) return nameAr.isNotEmpty ? nameAr : nameEn;
    return nameEn.isNotEmpty ? nameEn : nameAr;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name_ar': nameAr,
      'name_en': nameEn,
    };
  }
}

class ServiceEmployee {
  final int id;
  final String employeeNo;
  final String fullName;
  final String phone;
  final String authToken;
  final ServiceBranch branch;
  final List<ServiceRole> roles;
  final bool isLeader;

  const ServiceEmployee({
    required this.id,
    required this.employeeNo,
    required this.fullName,
    required this.phone,
    required this.authToken,
    required this.branch,
    required this.roles,
    required this.isLeader,
  });

  factory ServiceEmployee.fromJson(Map<String, dynamic> json) {
    final rawRoles = json['roles'];
    final roles = rawRoles is List
        ? rawRoles
            .map((item) => ServiceRole.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : <ServiceRole>[];

    return ServiceEmployee(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      employeeNo: '${json['employee_no'] ?? ''}',
      fullName: '${json['full_name'] ?? ''}',
      phone: '${json['phone'] ?? ''}',
      authToken: '${json['auth_token'] ?? ''}',
      branch: ServiceBranch.fromJson(
        Map<String, dynamic>.from(json['branch'] ?? {}),
      ),
      roles: roles,
      isLeader: json['is_leader'] == true ||
          '${json['is_leader']}' == '1' ||
          '${json['is_leader']}'.toLowerCase() == 'true',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_no': employeeNo,
      'full_name': fullName,
      'phone': phone,
      'auth_token': authToken,
      'branch': {
        'id': branch.id,
        'code': branch.code,
        'name_ar': branch.nameAr,
        'name_en': branch.nameEn,
      },
      'roles': roles.map((role) => role.toJson()).toList(),
      'is_leader': isLeader,
    };
  }
}
