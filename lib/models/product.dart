import 'dart:convert';

String _normalizeFadImageUrl(dynamic value) {
  var raw = '${value ?? ''}'.trim();
  if (raw.isEmpty || raw.toLowerCase() == 'null') return '';

  raw = raw.replaceAll('\\', '/').replaceAll('\\', '/');
  if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
  if (raw.startsWith('//')) return 'https:$raw';

  const publicNeedle = '/public_html/fce-dashboard/';
  final publicPos = raw.indexOf(publicNeedle);
  if (publicPos >= 0) {
    final path = raw.substring(publicPos + '/public_html'.length);
    return 'https://365hub.site$path';
  }

  final dashboardPos = raw.indexOf('/fce-dashboard/');
  if (dashboardPos >= 0) {
    return 'https://365hub.site${raw.substring(dashboardPos)}';
  }

  while (raw.startsWith('../')) {
    raw = raw.substring(3);
  }

  if (raw.startsWith('/fce-dashboard/')) {
    return 'https://365hub.site$raw';
  }

  if (raw.startsWith('/uploads/') || raw.startsWith('/api/') || raw.startsWith('/assets/')) {
    return 'https://365hub.site/fce-dashboard$raw';
  }

  if (raw.startsWith('uploads/') || raw.startsWith('api/') || raw.startsWith('assets/')) {
    return 'https://365hub.site/fce-dashboard/$raw';
  }

  if (raw.startsWith('/')) {
    return 'https://365hub.site$raw';
  }

  return 'https://365hub.site/fce-dashboard/$raw';
}

double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  final clean = '$value'.replaceAll(',', '').trim();
  return double.tryParse(clean) ?? 0;
}

bool _truthy(dynamic value) {
  final raw = '$value'.trim().toLowerCase();
  return raw == '1' || raw == 'true' || raw == 'yes' || raw == 'active' || raw == 'نشط';
}

String _imageIdentityKey(String value) {
  var clean = _normalizeFadImageUrl(value).trim();
  if (clean.isEmpty) return '';

  clean = clean.replaceAll('\\', '/').replaceAll('\\', '/');

  // Important: some dashboard image URLs are API endpoints where the query
  // identifies the real image, for example:
  // api/optimized_image.php?file=uploads/products/a.png
  // api/product_image.php?id=12
  // Removing the query makes all these different images look identical, so
  // the app keeps only the first image and the option gallery will not swipe.
  final lowerBeforeQueryCleanup = clean.toLowerCase();
  final queryIsImageIdentity = lowerBeforeQueryCleanup.contains('/api/optimized_image.php?') ||
      lowerBeforeQueryCleanup.contains('/api/product_image.php?') ||
      lowerBeforeQueryCleanup.contains('/api/product_type_image.php?') ||
      lowerBeforeQueryCleanup.contains('/api/product_type_gallery_image.php?') ||
      lowerBeforeQueryCleanup.contains('/api/product_variant_image.php?') ||
      lowerBeforeQueryCleanup.contains('?file=') ||
      lowerBeforeQueryCleanup.contains('&file=') ||
      lowerBeforeQueryCleanup.contains('?id=') ||
      lowerBeforeQueryCleanup.contains('&id=');

  if (queryIsImageIdentity) {
    final uri = Uri.tryParse(clean);
    if (uri != null) {
      final entries = <MapEntry<String, String>>[];
      for (final entry in uri.queryParameters.entries) {
        final key = entry.key.toLowerCase();
        // Drop cache-only parameters but keep identity parameters like file/id.
        if (key == 'v' || key == 't' || key == 'ts' || key == 'cache' || key == 'cb') continue;
        entries.add(MapEntry(key, entry.value));
      }
      entries.sort((a, b) => a.key.compareTo(b.key));
      final query = entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').join('&');
      clean = uri.replace(query: query.isEmpty ? null : query).toString();
    }
  } else {
    final queryIndex = clean.indexOf('?');
    if (queryIndex >= 0) clean = clean.substring(0, queryIndex);
  }

  final dashboardIndex = clean.indexOf('/fce-dashboard/');
  if (dashboardIndex >= 0) clean = clean.substring(dashboardIndex);

  while (clean.contains('//')) {
    clean = clean.replaceAll('//', '/');
  }

  return clean.toLowerCase();
}

dynamic _decodePossibleJson(dynamic value) {
  if (value is! String) return value;

  final text = value.trim();
  if (text.isEmpty) return value;

  final looksLikeJson = text.startsWith('[') || text.startsWith('{');
  if (!looksLikeJson) return value;

  try {
    return jsonDecode(text);
  } catch (_) {
    return value;
  }
}

List<ProductImage> _parseProductImages(dynamic raw) {
  final decoded = _decodePossibleJson(raw);
  final parsed = <ProductImage>[];

  void addImage(dynamic item, int index) {
    final decodedItem = _decodePossibleJson(item);

    if (decodedItem is Map) {
      final map = Map<String, dynamic>.from(decodedItem);
      final img = ProductImage.fromJson(map);
      if (img.imageUrl.trim().isNotEmpty) parsed.add(img);
      return;
    }

    final url = _normalizeFadImageUrl(decodedItem).trim();
    if (url.isEmpty) return;

    parsed.add(ProductImage(
      id: 0,
      imageUrl: url,
      sortOrder: index,
      isMain: index == 0,
    ));
  }

  if (decoded is List) {
    for (var i = 0; i < decoded.length; i++) {
      addImage(decoded[i], i);
    }
  } else if (decoded is Map) {
    final map = Map<String, dynamic>.from(decoded);
    final nested = map['images'] ??
        map['gallery_images'] ??
        map['option_images'] ??
        map['variant_images'] ??
        map['product_variant_images'] ??
        map['product_images'] ??
        map['gallery'] ??
        map['data'];

    if (nested != null && nested != decoded) {
      parsed.addAll(_parseProductImages(nested));
    } else {
      addImage(map, 0);
    }
  } else {
    addImage(decoded, 0);
  }

  return parsed.where((img) => img.imageUrl.trim().isNotEmpty).toList();
}

List<ProductImage> _mergeProductImages(Iterable<dynamic> sources) {
  final seen = <String>{};
  final result = <ProductImage>[];

  for (final source in sources) {
    for (final img in _parseProductImages(source)) {
      final key = _imageIdentityKey(img.imageUrl);
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      result.add(img);
    }
  }

  result.sort((a, b) {
    final sortCompare = a.sortOrder.compareTo(b.sortOrder);
    if (sortCompare != 0) return sortCompare;
    return a.id.compareTo(b.id);
  });

  return result;
}

class ProductImage {
  final int id;
  final String imageUrl;
  final int sortOrder;
  final bool isMain;

  const ProductImage({
    required this.id,
    required this.imageUrl,
    required this.sortOrder,
    required this.isMain,
  });

  factory ProductImage.fromJson(Map<String, dynamic> json) {
    return ProductImage(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      imageUrl: _normalizeFadImageUrl(json['image_url'] ?? json['url'] ?? json['image'] ?? json['src'] ?? json['photo_url'] ?? json['image_path'] ?? json['file_url'] ?? ''),
      sortOrder: int.tryParse('${json['sort_order'] ?? 0}') ?? 0,
      isMain: json['is_main'] == true || '${json['is_main']}' == '1',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'image_url': imageUrl,
      'sort_order': sortOrder,
      'is_main': isMain,
    };
  }
}

class ProductVariant {
  final int id;
  final int productId;
  final String nameAr;
  final String nameEn;
  final String categoryAr;
  final String categoryEn;
  final String descriptionAr;
  final String descriptionEn;
  final double priceUsd;
  final double priceAed;
  final double priceSdg;
  final String imageUrl;
  final List<ProductImage> images;
  final int sortOrder;

  const ProductVariant({
    required this.id,
    required this.productId,
    required this.nameAr,
    required this.nameEn,
    this.categoryAr = '',
    this.categoryEn = '',
    required this.descriptionAr,
    required this.descriptionEn,
    required this.priceUsd,
    required this.priceAed,
    required this.priceSdg,
    required this.imageUrl,
    this.images = const [],
    required this.sortOrder,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    final parsedImages = _mergeProductImages([
      json['images'],
      json['gallery_images'],
      json['option_images'],
      json['variant_images'],
      json['product_variant_images'],
      json['additional_images'],
      json['extra_images'],
      json['gallery'],
      json['photos'],
      json['image_urls'],
    ]);

    return ProductVariant(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      productId: int.tryParse('${json['product_id'] ?? 0}') ?? 0,
      nameAr: '${json['name_ar'] ?? json['variant_name_ar'] ?? ''}',
      nameEn: '${json['name_en'] ?? json['variant_name_en'] ?? ''}',
      categoryAr: '${json['variant_category_ar'] ?? json['category_ar'] ?? json['type_ar'] ?? ''}',
      categoryEn: '${json['variant_category_en'] ?? json['category_en'] ?? json['type_en'] ?? ''}',
      descriptionAr: '${json['description_ar'] ?? json['variant_description_ar'] ?? ''}',
      descriptionEn: '${json['description_en'] ?? json['variant_description_en'] ?? ''}',
      priceUsd: _toDouble(json['price_usd'] ?? json['usd'] ?? 0),
      priceAed: _toDouble(json['price_aed'] ?? 0),
      priceSdg: _toDouble(json['price_sdg'] ?? 0),
      imageUrl: _normalizeFadImageUrl(json['image_url'] ?? json['variant_image_url'] ?? json['variant_image'] ?? json['option_image'] ?? json['thumbnail_url'] ?? json['thumb_url'] ?? json['image'] ?? json['image_path'] ?? json['photo'] ?? json['photo_url'] ?? json['file_url'] ?? ''),
      images: parsedImages,
      sortOrder: int.tryParse('${json['sort_order'] ?? 0}') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'name_ar': nameAr,
      'name_en': nameEn,
      'variant_category_ar': categoryAr,
      'variant_category_en': categoryEn,
      'description_ar': descriptionAr,
      'description_en': descriptionEn,
      'price_usd': priceUsd,
      'price_aed': priceAed,
      'price_sdg': priceSdg,
      'image_url': imageUrl,
      'images': images.map((item) => item.toJson()).toList(),
      'sort_order': sortOrder,
    };
  }

  String name(bool isArabic) {
    if (isArabic) return nameAr.trim().isNotEmpty ? nameAr : nameEn;
    return nameEn.trim().isNotEmpty ? nameEn : nameAr;
  }

  String category(bool isArabic) {
    if (isArabic) return categoryAr.trim().isNotEmpty ? categoryAr : categoryEn;
    return categoryEn.trim().isNotEmpty ? categoryEn : categoryAr;
  }

  String description(bool isArabic) {
    if (isArabic) return descriptionAr.trim().isNotEmpty ? descriptionAr : descriptionEn;
    return descriptionEn.trim().isNotEmpty ? descriptionEn : descriptionAr;
  }
}

class Product {
  final int id;
  final String productType;
  final String nameAr;
  final String nameEn;
  final String descriptionAr;
  final String descriptionEn;
  final double priceUsd;
  final double priceAed;
  final double priceSdg;
  final double originalPriceUsd;
  final double originalPriceAed;
  final double originalPriceSdg;
  final bool offerActive;
  final double offerPercent;
  final String imageUrl;
  final List<ProductImage> images;
  final List<ProductVariant> variants;
  final int selectedVariantId;
  final String selectedVariantNameAr;
  final String selectedVariantNameEn;
  final String selectedVariantDescriptionAr;
  final String selectedVariantDescriptionEn;
  final String selectedVariantCategoryAr;
  final String selectedVariantCategoryEn;

  Product({
    required this.id,
    required this.productType,
    required this.nameAr,
    required this.nameEn,
    required this.descriptionAr,
    required this.descriptionEn,
    required this.priceUsd,
    required this.priceAed,
    required this.priceSdg,
    double? originalPriceUsd,
    double? originalPriceAed,
    double? originalPriceSdg,
    this.offerActive = false,
    this.offerPercent = 0,
    required this.imageUrl,
    this.images = const [],
    this.variants = const [],
    this.selectedVariantId = 0,
    this.selectedVariantNameAr = '',
    this.selectedVariantNameEn = '',
    this.selectedVariantDescriptionAr = '',
    this.selectedVariantDescriptionEn = '',
    this.selectedVariantCategoryAr = '',
    this.selectedVariantCategoryEn = '',
  })  : originalPriceUsd = originalPriceUsd ?? priceUsd,
        originalPriceAed = originalPriceAed ?? priceAed,
        originalPriceSdg = originalPriceSdg ?? priceSdg;

  factory Product.fromJson(Map<String, dynamic> json) {
    final productImages = _mergeProductImages([
      json['images'],
      json['product_images'],
      json['gallery_images'],
      json['additional_images'],
      json['extra_images'],
      json['gallery'],
      json['photos'],
      json['image_urls'],
    ]);
    final rawVariants = json['variants'] ?? json['product_variants'] ?? json['options'];

    final baseUsd = _toDouble(json['original_price_usd'] ?? json['price_usd'] ?? json['price'] ?? 0);
    final baseAed = _toDouble(json['original_price_aed'] ?? json['price_aed'] ?? 0);
    final baseSdg = _toDouble(json['original_price_sdg'] ?? json['price_sdg'] ?? 0);

    final percent = _toDouble(json['offer_percent'] ?? json['discount_percent'] ?? 0);
    final active = _truthy(json['offer_active'] ?? json['is_offer'] ?? json['has_offer']) || percent > 0;

    var saleUsd = _toDouble(json['sale_price_usd'] ?? json['offer_price_usd'] ?? json['sale_usd'] ?? 0);
    var saleAed = _toDouble(json['sale_price_aed'] ?? json['offer_price_aed'] ?? json['sale_aed'] ?? 0);
    var saleSdg = _toDouble(json['sale_price_sdg'] ?? json['offer_price_sdg'] ?? json['sale_sdg'] ?? 0);

    if (active && percent > 0) {
      if (saleUsd <= 0 && baseUsd > 0) saleUsd = baseUsd * (1 - (percent / 100));
      if (saleAed <= 0 && baseAed > 0) saleAed = baseAed * (1 - (percent / 100));
      if (saleSdg <= 0 && baseSdg > 0) saleSdg = baseSdg * (1 - (percent / 100));
    }

    return Product(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      productType: '${json['product_type'] ?? ''}',
      nameAr: '${json['name_ar'] ?? ''}',
      nameEn: '${json['name_en'] ?? ''}',
      descriptionAr: '${json['description_ar'] ?? ''}',
      descriptionEn: '${json['description_en'] ?? ''}',
      priceUsd: active && saleUsd > 0 ? saleUsd : baseUsd,
      priceAed: active && saleAed > 0 ? saleAed : baseAed,
      priceSdg: active && saleSdg > 0 ? saleSdg : baseSdg,
      originalPriceUsd: baseUsd,
      originalPriceAed: baseAed,
      originalPriceSdg: baseSdg,
      offerActive: active,
      offerPercent: percent,
      imageUrl: _normalizeFadImageUrl(json['image_url'] ?? json['main_image'] ?? json['image'] ?? json['image_path'] ?? json['photo'] ?? json['photo_url'] ?? json['file_url'] ?? ''),
      images: productImages,
      variants: rawVariants is List
          ? rawVariants
              .map((item) => ProductVariant.fromJson(Map<String, dynamic>.from(item)))
              .where((variant) => variant.id > 0)
              .toList()
          : const [],
      selectedVariantId: int.tryParse('${json['selected_variant_id'] ?? 0}') ?? 0,
      selectedVariantNameAr: '${json['selected_variant_name_ar'] ?? ''}',
      selectedVariantNameEn: '${json['selected_variant_name_en'] ?? ''}',
      selectedVariantDescriptionAr: '${json['selected_variant_description_ar'] ?? ''}',
      selectedVariantDescriptionEn: '${json['selected_variant_description_en'] ?? ''}',
      selectedVariantCategoryAr: '${json['selected_variant_category_ar'] ?? ''}',
      selectedVariantCategoryEn: '${json['selected_variant_category_en'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_type': productType,
      'name_ar': nameAr,
      'name_en': nameEn,
      'description_ar': descriptionAr,
      'description_en': descriptionEn,
      'price_usd': priceUsd,
      'price_aed': priceAed,
      'price_sdg': priceSdg,
      'original_price_usd': originalPriceUsd,
      'original_price_aed': originalPriceAed,
      'original_price_sdg': originalPriceSdg,
      'offer_active': offerActive ? 1 : 0,
      'offer_percent': offerPercent,
      'image_url': imageUrl,
      'images': images.map((item) => item.toJson()).toList(),
      'variants': variants.map((item) => item.toJson()).toList(),
      'selected_variant_id': selectedVariantId,
      'selected_variant_name_ar': selectedVariantNameAr,
      'selected_variant_name_en': selectedVariantNameEn,
      'selected_variant_description_ar': selectedVariantDescriptionAr,
      'selected_variant_description_en': selectedVariantDescriptionEn,
      'selected_variant_category_ar': selectedVariantCategoryAr,
      'selected_variant_category_en': selectedVariantCategoryEn,
    };
  }

  String get cartKey => '${id}_$selectedVariantId';

  bool get hasSelectedVariant => selectedVariantId > 0;

  bool get hasActiveDiscount => offerActive && originalPriceUsd > 0 && priceUsd > 0 && priceUsd < (originalPriceUsd - 0.001);

  String selectedVariantName(bool isArabic) {
    if (isArabic) return selectedVariantNameAr.trim().isNotEmpty ? selectedVariantNameAr : selectedVariantNameEn;
    return selectedVariantNameEn.trim().isNotEmpty ? selectedVariantNameEn : selectedVariantNameAr;
  }

  String selectedVariantCategory(bool isArabic) {
    if (isArabic) return selectedVariantCategoryAr.trim().isNotEmpty ? selectedVariantCategoryAr : selectedVariantCategoryEn;
    return selectedVariantCategoryEn.trim().isNotEmpty ? selectedVariantCategoryEn : selectedVariantCategoryAr;
  }

  String name(bool isArabic) {
    if (hasSelectedVariant) {
      final selected = selectedVariantName(isArabic);
      if (selected.trim().isNotEmpty) return selected;
    }
    if (isArabic) return nameAr.trim().isNotEmpty ? nameAr : nameEn;
    return nameEn.trim().isNotEmpty ? nameEn : nameAr;
  }

  String baseName(bool isArabic) {
    if (isArabic) return nameAr.trim().isNotEmpty ? nameAr : nameEn;
    return nameEn.trim().isNotEmpty ? nameEn : nameAr;
  }

  String description(bool isArabic) {
    if (hasSelectedVariant) {
      final selected = isArabic
          ? (selectedVariantDescriptionAr.trim().isNotEmpty ? selectedVariantDescriptionAr : selectedVariantDescriptionEn)
          : (selectedVariantDescriptionEn.trim().isNotEmpty ? selectedVariantDescriptionEn : selectedVariantDescriptionAr);
      if (selected.trim().isNotEmpty) return selected;
    }
    if (isArabic) return descriptionAr.trim().isNotEmpty ? descriptionAr : descriptionEn;
    return descriptionEn.trim().isNotEmpty ? descriptionEn : descriptionAr;
  }

  double _convertedVariantPrice({required double variantUsd, required double baseUsd, required double baseOther}) {
    if (variantUsd <= 0) return baseOther;
    if (baseUsd > 0 && baseOther > 0) return variantUsd * (baseOther / baseUsd);
    return 0;
  }

  double _discounted(double value) {
    if (!offerActive || offerPercent <= 0 || value <= 0) return value;
    return value * (1 - (offerPercent / 100));
  }

  Product copyWithSelectedVariant(ProductVariant? variant) {
    if (variant == null) return this;

    final variantOriginalUsd = variant.priceUsd > 0 ? variant.priceUsd : originalPriceUsd;
    final variantOriginalAed = variant.priceAed > 0
        ? variant.priceAed
        : _convertedVariantPrice(variantUsd: variantOriginalUsd, baseUsd: originalPriceUsd, baseOther: originalPriceAed);
    final variantOriginalSdg = variant.priceSdg > 0
        ? variant.priceSdg
        : _convertedVariantPrice(variantUsd: variantOriginalUsd, baseUsd: originalPriceUsd, baseOther: originalPriceSdg);

    return Product(
      id: id,
      productType: productType,
      nameAr: nameAr,
      nameEn: nameEn,
      descriptionAr: descriptionAr,
      descriptionEn: descriptionEn,
      // A product offer must apply only to the main selected product.
      // Variants/options have their own price and should not inherit the parent product discount.
      priceUsd: variantOriginalUsd,
      priceAed: variantOriginalAed,
      priceSdg: variantOriginalSdg,
      originalPriceUsd: variantOriginalUsd,
      originalPriceAed: variantOriginalAed,
      originalPriceSdg: variantOriginalSdg,
      offerActive: false,
      offerPercent: 0,
      // A selected option owns its media completely. Empty option media must
      // remain empty and must never inherit the original product gallery.
      imageUrl: variant.imageUrl,
      images: variant.images,
      variants: variants,
      selectedVariantId: variant.id,
      selectedVariantNameAr: variant.nameAr,
      selectedVariantNameEn: variant.nameEn,
      selectedVariantDescriptionAr: variant.descriptionAr,
      selectedVariantDescriptionEn: variant.descriptionEn,
      selectedVariantCategoryAr: variant.categoryAr,
      selectedVariantCategoryEn: variant.categoryEn,
    );
  }
}
