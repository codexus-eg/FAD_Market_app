class PaymentMethodConfig {
  final String code;
  final String type;
  final String currency;
  final String titleAr;
  final String titleEn;
  final String subtitleAr;
  final String subtitleEn;
  final String accountAr;
  final String accountEn;
  final String buttonAr;
  final String buttonEn;
  final bool enabled;
  final bool requiresReference;

  const PaymentMethodConfig({
    required this.code,
    required this.type,
    required this.currency,
    required this.titleAr,
    required this.titleEn,
    required this.subtitleAr,
    required this.subtitleEn,
    required this.accountAr,
    required this.accountEn,
    required this.buttonAr,
    required this.buttonEn,
    required this.enabled,
    required this.requiresReference,
  });

  factory PaymentMethodConfig.fromJson(Map<String, dynamic> json) {
    return PaymentMethodConfig(
      code: '${json['code'] ?? ''}'.trim(),
      type: '${json['type'] ?? ''}'.trim(),
      currency: '${json['currency'] ?? 'USD'}'.trim().toUpperCase(),
      titleAr: '${json['title_ar'] ?? ''}'.trim(),
      titleEn: '${json['title_en'] ?? ''}'.trim(),
      subtitleAr: '${json['subtitle_ar'] ?? ''}'.trim(),
      subtitleEn: '${json['subtitle_en'] ?? ''}'.trim(),
      accountAr: '${json['account_ar'] ?? ''}'.trim(),
      accountEn: '${json['account_en'] ?? ''}'.trim(),
      buttonAr: '${json['button_ar'] ?? ''}'.trim(),
      buttonEn: '${json['button_en'] ?? ''}'.trim(),
      enabled: json['enabled'] == true || '${json['enabled']}' == '1',
      requiresReference: json['requires_reference'] == true || '${json['requires_reference']}' == '1',
    );
  }

  String title(bool isArabic) {
    final value = isArabic ? titleAr : titleEn;
    if (value.isNotEmpty) return value;
    return isArabic ? titleEn : titleAr;
  }

  String subtitle(bool isArabic) {
    final value = isArabic ? subtitleAr : subtitleEn;
    if (value.isNotEmpty) return value;
    return isArabic ? subtitleEn : subtitleAr;
  }

  String account(bool isArabic) {
    final value = isArabic ? accountAr : accountEn;
    if (value.isNotEmpty) return value;
    return isArabic ? accountEn : accountAr;
  }

  String button(bool isArabic) {
    final value = isArabic ? buttonAr : buttonEn;
    if (value.isNotEmpty) return value;
    return isArabic ? buttonEn : buttonAr;
  }

  bool get isManualReference {
    return type == 'manual_reference' || requiresReference || code == 'bank_khartoum';
  }

  bool get isHostedCheckout {
    return type == 'hosted_checkout';
  }
}
