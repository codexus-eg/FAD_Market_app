import 'package:flutter/material.dart';

import '../app_controller.dart';

class OrderSuccessScreen extends StatelessWidget {
  final String orderNumber;
  final String totalText;

  // Supports both old checkout_screen and new checkout_screen.
  final String? paymentMethodTitle;
  final String? title;
  final String? message;

  const OrderSuccessScreen({
    super.key,
    required this.orderNumber,
    required this.totalText,
    this.paymentMethodTitle,
    this.title,
    this.message,
  });

  static const Color goldColor = Color(0xFFD4A02A);
  static const Color darkColor = Color(0xFF202020);
  static const Color bgColor = Color(0xFFF5F5F5);

  String tr(String ar, String en) {
    return AppController.isArabic ? ar : en;
  }

  String get screenTitle {
    if (title != null && title!.trim().isNotEmpty) {
      return title!;
    }

    return tr('تم إنشاء الطلب بنجاح', 'Order created successfully');
  }

  String get screenMessage {
    if (message != null && message!.trim().isNotEmpty) {
      return message!;
    }

    if (paymentMethodTitle != null && paymentMethodTitle!.trim().isNotEmpty) {
      return '${tr('طريقة الدفع', 'Payment')}: $paymentMethodTitle';
    }

    return tr(
      'تم إرسال الطلب بنجاح.',
      'Your order has been submitted successfully.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppController.direction,
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(22),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: goldColor,
                    size: 76,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    screenTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: darkColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    screenMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: darkColor.withOpacity(0.65),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${tr('رقم الطلب', 'Order number')}: $orderNumber',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: darkColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${tr('الإجمالي', 'Total')}: $totalText',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: goldColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.popUntil(context, (route) => route.isFirst);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: goldColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(
                        tr('الرجوع للرئيسية', 'Back to Home'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
