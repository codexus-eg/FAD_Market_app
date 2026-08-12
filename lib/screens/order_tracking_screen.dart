import 'package:flutter/material.dart';

import '../app_controller.dart';

class OrderTrackingScreen extends StatelessWidget {
  final Map<String, dynamic> order;

  const OrderTrackingScreen({
    super.key,
    required this.order,
  });

  static const Color goldColor = Color(0xFFD4A02A);
  static const Color darkColor = Color(0xFF202020);
  static const Color bgColor = Color(0xFFF5F5F5);
  static const Color blueColor = Color(0xFF1976D2);

  String tr(String ar, String en) => AppController.isArabic ? ar : en;

  String _value(String key) {
    final value = order[key];
    if (value == null) return '';
    return '$value'.trim();
  }

  String _totalText() {
    final currency = _value('currency');
    final total = double.tryParse(_value('total')) ?? 0;

    if (currency == 'SDG') {
      return '${total.toStringAsFixed(0)} SDG';
    }

    return '${total.toStringAsFixed(2)} $currency';
  }

  int _activeIndex() {
    final status = '${_value('order_status')} ${_value('status')} ${_value('workflow_status')}'.toLowerCase();
    final payment = '${_value('payment_status')} ${_value('bank_status')}'.toLowerCase();
    final delivery = '${_value('delivery_status')}'.toLowerCase();

    if (status.contains('cancel') || status.contains('reject')) return -2;
    if (status.contains('complete') || status.contains('delivered') || delivery.contains('complete')) return 4;
    if (status.contains('delivery') || status.contains('shipping') || status.contains('shipped') || status.contains('handover') || delivery.contains('delivery')) return 3;
    if (status.contains('confirm') || status.contains('process') || status.contains('prepar')) return 2;
    if (payment.contains('confirm') || payment.contains('paid') || status.contains('paid') || status.contains('payment_confirm')) return 1;

    return 0;
  }

  List<_TrackStep> _steps() {
    final active = _activeIndex();

    final labels = [
      _TrackStepText(
        ar: 'استلام الطلب',
        en: 'Order received',
      ),
      _TrackStepText(
        ar: 'تأكيد الدفع',
        en: 'Payment confirmed',
      ),
      _TrackStepText(
        ar: 'تأكيد الطلب',
        en: 'Order confirmed',
      ),
      _TrackStepText(
        ar: 'تسليم الطلب للتوصيل',
        en: 'Handed to delivery',
      ),
      _TrackStepText(
        ar: 'مكتمل',
        en: 'Completed',
      ),
    ];

    return List.generate(labels.length, (index) {
      return _TrackStep(
        title: tr(labels[index].ar, labels[index].en),
        done: active >= index,
        current: active == index,
      );
    });
  }

  List<Map<String, dynamic>> _items() {
    final rawItems = order['items'];

    if (rawItems is List) {
      return rawItems.map((item) {
        return Map<String, dynamic>.from(item as Map);
      }).toList();
    }

    return <Map<String, dynamic>>[];
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeIndex();
    final isStopped = active == -2;
    final reference = _value('payment_reference');
    final steps = _steps();
    final items = _items();

    return Directionality(
      textDirection: AppController.direction,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: Text(
            tr('متابعة الطلب', 'Order Tracking'),
            style: const TextStyle(
              color: darkColor,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: AppController.isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${tr('رقم الطلب', 'Order No.')}: ${_value('order_number')}',
                      textAlign: AppController.isArabic ? TextAlign.right : TextAlign.left,
                      style: const TextStyle(
                        color: darkColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _totalText(),
                      style: const TextStyle(
                        color: goldColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (reference.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${tr('الرقم المرجعي', 'Reference')}: $reference',
                        textAlign: AppController.isArabic ? TextAlign.right : TextAlign.left,
                        style: TextStyle(
                          color: darkColor.withOpacity(0.68),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      '${tr('التاريخ', 'Date')}: ${_value('created_at')}',
                      textAlign: AppController.isArabic ? TextAlign.right : TextAlign.left,
                      style: TextStyle(
                        color: darkColor.withOpacity(0.48),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: AppController.isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('مسار الطلب', 'Order progress'),
                      style: const TextStyle(
                        color: darkColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (isStopped)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.09),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          tr('هذا الطلب ملغي أو مرفوض', 'This order is cancelled or rejected'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      )
                    else
                      ...List.generate(steps.length, (index) {
                        return _TrackRow(
                          step: steps[index],
                          isLast: index == steps.length - 1,
                          nextDone: index < steps.length - 1 && steps[index + 1].done,
                        );
                      }),
                  ],
                ),
              ),
              if (items.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: AppController.isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('تفاصيل المنتجات', 'Products details'),
                        style: const TextStyle(
                          color: darkColor,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...items.map((item) {
                        final name = AppController.isArabic
                            ? '${item['product_name_ar'] ?? ''}'
                            : '${item['product_name_en'] ?? item['product_name_ar'] ?? ''}';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '${item['quantity'] ?? 1} × $name',
                            textAlign: AppController.isArabic ? TextAlign.right : TextAlign.left,
                            style: TextStyle(
                              color: darkColor.withOpacity(0.82),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackStepText {
  final String ar;
  final String en;

  const _TrackStepText({
    required this.ar,
    required this.en,
  });
}

class _TrackStep {
  final String title;
  final bool done;
  final bool current;

  const _TrackStep({
    required this.title,
    required this.done,
    required this.current,
  });
}

class _TrackRow extends StatelessWidget {
  final _TrackStep step;
  final bool isLast;
  final bool nextDone;

  const _TrackRow({
    required this.step,
    required this.isLast,
    required this.nextDone,
  });

  static const Color darkColor = Color(0xFF202020);
  static const Color blueColor = Color(0xFF1976D2);

  @override
  Widget build(BuildContext context) {
    final pointColor = step.done ? blueColor : Colors.grey.shade300;
    final textColor = step.done ? darkColor : darkColor.withOpacity(0.45);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      textDirection: AppController.direction,
      children: [
        Column(
          children: [
            Container(
              width: step.current ? 18 : 15,
              height: step.current ? 18 : 15,
              decoration: BoxDecoration(
                color: pointColor,
                shape: BoxShape.circle,
                boxShadow: step.current
                    ? [
                        BoxShadow(
                          color: blueColor.withOpacity(0.28),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
            ),
            if (!isLast)
              SizedBox(
                width: 2,
                height: 42,
                child: CustomPaint(
                  painter: _TrackLinePainter(done: nextDone),
                ),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: step.current ? 0 : 1),
            child: Text(
              step.title,
              textAlign: AppController.isArabic ? TextAlign.right : TextAlign.left,
              style: TextStyle(
                color: textColor,
                fontSize: step.current ? 16 : 15,
                fontWeight: step.done ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TrackLinePainter extends CustomPainter {
  final bool done;

  const _TrackLinePainter({
    required this.done,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = done ? const Color(0xFF1976D2) : Colors.grey.shade300
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    if (done) {
      canvas.drawLine(
        Offset(size.width / 2, 0),
        Offset(size.width / 2, size.height),
        paint,
      );
      return;
    }

    double y = 0;
    while (y < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, y + 5),
        paint,
      );
      y += 10;
    }
  }

  @override
  bool shouldRepaint(covariant _TrackLinePainter oldDelegate) {
    return oldDelegate.done != done;
  }
}
