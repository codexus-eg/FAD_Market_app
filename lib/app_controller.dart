import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_translations.dart';

class AppController {
  static final ValueNotifier<String> language = ValueNotifier<String>('ar');
  static final ValueNotifier<String> currency = ValueNotifier<String>('USD');

  static const String _currencyKey = 'fce_selected_currency';

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCurrency = prefs.getString(_currencyKey);

    if (savedCurrency == 'USD' ||
        savedCurrency == 'AED' ||
        savedCurrency == 'SDG') {
      currency.value = savedCurrency!;
    }
  }

  static bool get isArabic => language.value == 'ar';

  static TextDirection get direction {
    return isArabic ? TextDirection.rtl : TextDirection.ltr;
  }

  static void toggleLanguage() {
    language.value = isArabic ? 'en' : 'ar';
  }

  static Future<void> setCurrency(String value) async {
    if (value != 'USD' && value != 'AED' && value != 'SDG') {
      return;
    }

    currency.value = value;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyKey, value);
  }

  static String _withThousandsSeparator(String value) {
    final parts = value.split('.');
    final sign = parts.first.startsWith('-') ? '-' : '';
    final whole = parts.first.replaceFirst('-', '');

    final buffer = StringBuffer();
    for (int i = 0; i < whole.length; i++) {
      final remaining = whole.length - i;
      buffer.write(whole[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }

    if (parts.length > 1) {
      return '$sign${buffer.toString()}.${parts.sublist(1).join('.')}';
    }

    return '$sign${buffer.toString()}';
  }

  static String formatAmount(double value, {int decimals = 2}) {
    return _withThousandsSeparator(value.toStringAsFixed(decimals));
  }

  static String formatSelectedPrice({
    required double usd,
    required double aed,
    required double sdg,
  }) {
    final selected = currency.value;

    if (selected == 'AED') {
      if (aed <= 0) {
        return isArabic ? 'السعر عند الطلب' : 'Price on request';
      }

      return '${formatAmount(aed, decimals: 2)} AED';
    }

    if (selected == 'SDG') {
      if (sdg <= 0) {
        return isArabic ? 'السعر عند الطلب' : 'Price on request';
      }

      return '${formatAmount(sdg, decimals: 0)} SDG';
    }

    if (usd <= 0) {
      return isArabic ? 'السعر عند الطلب' : 'Price on request';
    }

    return '${formatAmount(usd, decimals: 2)} USD';
  }

  static String t(String key) {
    return AppTranslations.text(key, language.value);
  }
}
