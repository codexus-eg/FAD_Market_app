import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../app_controller.dart';

class InvoiceViewScreen extends StatefulWidget {
  final String invoiceUrl;

  const InvoiceViewScreen({super.key, required this.invoiceUrl});

  static const Color goldColor = Color(0xFFD4A02A);
  static const Color darkColor = Color(0xFF202020);

  @override
  State<InvoiceViewScreen> createState() => _InvoiceViewScreenState();
}

class _InvoiceViewScreenState extends State<InvoiceViewScreen> {
  bool _loading = true;
  String _error = '';
  Map<String, dynamic>? _invoice;

  String tr(String ar, String en) => AppController.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _loadInvoiceData();
  }

  Uri _invoiceDataUri() {
    final uri = Uri.parse(widget.invoiceUrl);
    final path = uri.path.replaceFirst(RegExp(r'/invoice\.php$'), '/invoice_data.php');
    return uri.replace(path: path);
  }

  Uri _downloadUri() {
    final uri = Uri.parse(widget.invoiceUrl);
    final params = Map<String, String>.from(uri.queryParameters);
    params['print'] = '1';
    return uri.replace(queryParameters: params);
  }

  Future<void> _loadInvoiceData() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = '';
      });
    }

    try {
      final response = await http.get(
        _invoiceDataUri(),
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'FAD-Market-App',
        },
      ).timeout(const Duration(seconds: 22));

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode < 200 || response.statusCode >= 300 || decoded is! Map || decoded['success'] != true) {
        throw Exception(decoded is Map ? (decoded['message'] ?? 'Invoice error') : 'Invoice error');
      }

      if (!mounted) return;
      setState(() {
        _invoice = Map<String, dynamic>.from(decoded['invoice'] as Map);
        _loading = false;
        _error = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = tr('تعذر تحميل بيانات الفاتورة. يرجى رفع باتش لوحة التحكم ثم المحاولة مرة أخرى.', 'Could not load invoice data. Upload the dashboard patch, then try again.');
      });
    }
  }

  Future<void> _downloadInvoice() async {
    final opened = await launchUrl(
      _downloadUri(),
      mode: LaunchMode.inAppBrowserView,
      webOnlyWindowName: '_blank',
    );

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('تعذر تحميل الفاتورة', 'Could not download invoice'))),
      );
    }
  }

  String _str(Map<String, dynamic>? map, String key) => '${map?[key] ?? ''}'.trim();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppController.direction,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F3F5),
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: InvoiceViewScreen.darkColor),
          title: Text(
            tr('الفاتورة', 'Invoice'),
            style: const TextStyle(
              color: InvoiceViewScreen.darkColor,
              fontWeight: FontWeight.w900,
            ),
          ),
          actions: [
            IconButton(
              onPressed: _downloadInvoice,
              tooltip: tr('تحميل الفاتورة', 'Download invoice'),
              icon: const Icon(Icons.download_rounded, color: InvoiceViewScreen.goldColor),
            ),
            IconButton(
              onPressed: _loadInvoiceData,
              tooltip: tr('تحديث', 'Refresh'),
              icon: const Icon(Icons.refresh_rounded, color: InvoiceViewScreen.darkColor),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: InvoiceViewScreen.goldColor))
            : _error.isNotEmpty
                ? _InvoiceError(error: _error, onRetry: _loadInvoiceData, tr: tr)
                : _InvoiceBody(invoice: _invoice ?? const {}, tr: tr),
      ),
    );
  }
}

class _InvoiceBody extends StatelessWidget {
  final Map<String, dynamic> invoice;
  final String Function(String ar, String en) tr;

  const _InvoiceBody({required this.invoice, required this.tr});

  Map<String, dynamic> _map(String key) {
    final value = invoice[key];
    return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  }

  Map<String, dynamic> get order => _map('order');
  Map<String, dynamic> get customer => _map('customer');
  Map<String, dynamic> get company => _map('company');
  List<Map<String, dynamic>> get items => ((invoice['items'] as List?) ?? const [])
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();

  String _s(Map<String, dynamic> map, String key) => '${map[key] ?? ''}'.trim();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(height: 6, decoration: BoxDecoration(color: InvoiceViewScreen.goldColor, borderRadius: BorderRadius.circular(999))),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.start,
                  runSpacing: 12,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _s(company, 'name').isEmpty ? 'FAD CNC COMPANY EQUIPMENTS L.L.C' : _s(company, 'name'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: InvoiceViewScreen.darkColor),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _s(company, 'description').isEmpty ? tr('معدات وماكينات CNC - قطع غيار - تصاميم رقمية', 'CNC machines, spare parts and digital designs') : _s(company, 'description'),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(tr('فاتورة', 'Invoice'), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: InvoiceViewScreen.goldColor)),
                        const SizedBox(height: 4),
                        Text('${tr('رقم الفاتورة', 'Invoice No.')}: ${_s(order, 'invoice_number')}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text('${tr('رقم الطلب', 'Order No.')}: ${_s(order, 'order_number')}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text('${tr('التاريخ', 'Date')}: ${_s(order, 'created_at')}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _InfoBox(
                      title: tr('فاتورة إلى', 'Bill To'),
                      rows: [
                        MapEntry(tr('العميل', 'Customer'), _s(customer, 'full_name')),
                        MapEntry(tr('واتساب', 'WhatsApp'), _s(customer, 'whatsapp_phone')),
                        MapEntry(tr('الهاتف', 'Phone'), _s(customer, 'call_phone')),
                        MapEntry(tr('العنوان', 'Address'), _s(customer, 'address').isEmpty ? tr('بدون عنوان', 'No address') : _s(customer, 'address')),
                      ],
                    ),
                    _InfoBox(
                      title: tr('بيانات الدفع', 'Payment Details'),
                      rows: [
                        MapEntry(tr('طريقة الدفع', 'Payment Method'), _s(order, 'payment_method_label')),
                        MapEntry(tr('حالة الدفع', 'Payment Status'), _s(order, 'payment_status')),
                        MapEntry(tr('حالة الطلب', 'Order Status'), _s(order, 'order_status_label')),
                        if (_s(order, 'payment_reference').isNotEmpty) MapEntry(tr('الرقم المرجعي', 'Reference No.'), _s(order, 'payment_reference')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _ItemsTable(items: items, tr: tr),
                const SizedBox(height: 14),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: _TotalsBox(
                    subtotal: _s(order, 'subtotal_formatted'),
                    total: _s(order, 'total_formatted'),
                    tr: tr,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: InvoiceViewScreen.goldColor.withOpacity(0.55)),
                    color: InvoiceViewScreen.goldColor.withOpacity(0.05),
                  ),
                  child: Text(
                    _s(order, 'notes').isEmpty ? tr('تم إنشاء الفاتورة إلكترونياً. شكراً لتعاملكم معنا.', 'This invoice was generated electronically. Thank you for your business.') : _s(order, 'notes'),
                    style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black87, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String title;
  final List<MapEntry<String, String>> rows;

  const _InfoBox({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width > 760 ? 350 : MediaQuery.of(context).size.width - 60,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFFFCFCFD),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(color: InvoiceViewScreen.goldColor, fontWeight: FontWeight.w900)),
            const Divider(height: 18),
            ...rows.map((row) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 105, child: Text(row.key, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w800, fontSize: 12))),
                      Expanded(child: Text(row.value, style: const TextStyle(color: InvoiceViewScreen.darkColor, fontWeight: FontWeight.w900, fontSize: 12))),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _ItemsTable extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String Function(String ar, String en) tr;

  const _ItemsTable({required this.items, required this.tr});

  String _s(Map<String, dynamic> map, String key) => '${map[key] ?? ''}'.trim();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: InvoiceViewScreen.darkColor,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                SizedBox(width: 30, child: Text('#', style: _headerStyle)),
                Expanded(flex: 4, child: Text(tr('المنتج', 'Item'), style: _headerStyle)),
                Expanded(child: Text(tr('الكمية', 'Qty'), textAlign: TextAlign.center, style: _headerStyle)),
                Expanded(flex: 2, child: Text(tr('الإجمالي', 'Total'), textAlign: TextAlign.end, style: _headerStyle)),
              ],
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(tr('لا توجد منتجات في الفاتورة', 'No items in invoice'), style: const TextStyle(fontWeight: FontWeight.w800)),
            )
          else
            ...items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: index == 0 ? Colors.transparent : const Color(0xFFEEF1F5))),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 30, child: Text('${index + 1}', style: _cellStyle)),
                    Expanded(flex: 4, child: Text(_s(item, 'name'), style: _cellStyle)),
                    Expanded(child: Text(_s(item, 'quantity'), textAlign: TextAlign.center, style: _cellStyle)),
                    Expanded(flex: 2, child: Text(_s(item, 'line_total_formatted'), textAlign: TextAlign.end, style: _cellStyleBold)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  static const TextStyle _headerStyle = TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12);
  static const TextStyle _cellStyle = TextStyle(color: InvoiceViewScreen.darkColor, fontWeight: FontWeight.w700, fontSize: 12);
  static const TextStyle _cellStyleBold = TextStyle(color: InvoiceViewScreen.darkColor, fontWeight: FontWeight.w900, fontSize: 12);
}

class _TotalsBox extends StatelessWidget {
  final String subtotal;
  final String total;
  final String Function(String ar, String en) tr;

  const _TotalsBox({required this.subtotal, required this.total, required this.tr});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _row(tr('المجموع', 'Subtotal'), subtotal),
          Container(color: InvoiceViewScreen.darkColor, child: _row(tr('الإجمالي النهائي', 'Total'), total, dark: true)),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool dark = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: dark ? Colors.white : InvoiceViewScreen.darkColor, fontWeight: FontWeight.w900))),
          Text(value, style: TextStyle(color: dark ? Colors.white : InvoiceViewScreen.darkColor, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _InvoiceError extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  final String Function(String ar, String en) tr;

  const _InvoiceError({required this.error, required this.onRetry, required this.tr});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long_rounded, color: InvoiceViewScreen.goldColor, size: 54),
            const SizedBox(height: 12),
            Text(error, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(backgroundColor: InvoiceViewScreen.goldColor, foregroundColor: Colors.white),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(tr('إعادة المحاولة', 'Retry')),
            ),
          ],
        ),
      ),
    );
  }
}
