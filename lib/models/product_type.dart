class ProductType {
  final int id;
  final String code;
  final String nameAr;
  final String nameEn;
  final String status;
  final int sortOrder;
  final int productsCount;
  final String imageUrl;

  ProductType({
    required this.id,
    required this.code,
    required this.nameAr,
    required this.nameEn,
    required this.status,
    required this.sortOrder,
    required this.productsCount,
    required this.imageUrl,
  });

  factory ProductType.fromJson(Map<String, dynamic> json) {
    return ProductType(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      code: '${json['code'] ?? ''}',
      nameAr: '${json['name_ar'] ?? ''}',
      nameEn: '${json['name_en'] ?? ''}',
      status: '${json['status'] ?? ''}',
      sortOrder: int.tryParse('${json['sort_order'] ?? 0}') ?? 0,
      productsCount: int.tryParse('${json['products_count'] ?? 0}') ?? 0,
      imageUrl: '${json['image_url'] ?? ''}',
    );
  }

  String name(bool isArabic) {
    if (isArabic) {
      return nameAr.trim().isNotEmpty ? nameAr : nameEn;
    }

    return nameEn.trim().isNotEmpty ? nameEn : nameAr;
  }
}
