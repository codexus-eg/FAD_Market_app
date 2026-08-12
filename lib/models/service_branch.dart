class ServiceBranch {
  final int id;
  final String code;
  final String nameAr;
  final String nameEn;

  const ServiceBranch({
    required this.id,
    required this.code,
    required this.nameAr,
    required this.nameEn,
  });

  factory ServiceBranch.fromJson(Map<String, dynamic> json) {
    return ServiceBranch(
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
}
