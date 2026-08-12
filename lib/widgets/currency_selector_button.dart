import 'package:flutter/material.dart';

import '../app_controller.dart';
import 'fit_one_line_text.dart';

class CurrencySelectorButton extends StatelessWidget {
  const CurrencySelectorButton({
    super.key,
    this.compact = false,
  });

  final bool compact;

  static const Color goldColor = Color(0xFFD4A02A);
  static const Color darkColor = Color(0xFF202020);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppController.currency,
      builder: (context, selectedCurrency, child) {
        return PopupMenuButton<String>(
          tooltip: AppController.isArabic ? 'اختيار العملة' : 'Select currency',
          onSelected: (value) {
            AppController.setCurrency(value);
          },
          itemBuilder: (context) {
            return [
              PopupMenuItem<String>(
                value: 'USD',
                child: _CurrencyMenuItem(
                  code: 'USD',
                  title: AppController.isArabic ? 'دولار' : 'US Dollar',
                  selected: selectedCurrency == 'USD',
                ),
              ),
              PopupMenuItem<String>(
                value: 'AED',
                child: _CurrencyMenuItem(
                  code: 'AED',
                  title: AppController.isArabic ? 'درهم إماراتي' : 'UAE Dirham',
                  selected: selectedCurrency == 'AED',
                ),
              ),
              PopupMenuItem<String>(
                value: 'SDG',
                child: _CurrencyMenuItem(
                  code: 'SDG',
                  title: AppController.isArabic ? 'جنيه سوداني' : 'Sudanese Pound',
                  selected: selectedCurrency == 'SDG',
                ),
              ),
            ];
          },
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 12,
              vertical: compact ? 8 : 9,
            ),
            decoration: BoxDecoration(
              color: goldColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.payments_outlined,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 5),
                Text(
                  selectedCurrency,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white,
                  size: 17,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CurrencyMenuItem extends StatelessWidget {
  final String code;
  final String title;
  final bool selected;

  const _CurrencyMenuItem({
    required this.code,
    required this.title,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppController.direction,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? CurrencySelectorButton.goldColor
                  : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              code,
              style: TextStyle(
                color: selected ? Colors.white : CurrencySelectorButton.darkColor,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FitOneLineText(
              title,
              alignment: AppController.isArabic
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              textAlign: AppController.isArabic ? TextAlign.right : TextAlign.left,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (selected)
            const Icon(
              Icons.check_circle,
              color: CurrencySelectorButton.goldColor,
              size: 18,
            ),
        ],
      ),
    );
  }
}
