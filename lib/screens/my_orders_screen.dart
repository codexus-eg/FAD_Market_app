import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../app_controller.dart';
import '../services/customer_session.dart';
import 'order_tracking_screen.dart';
import 'invoice_view_screen.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  static const Color goldColor = Color(0xFFD4A02A);
  static const Color darkColor = Color(0xFF202020);
  static const Color bgColor = Color(0xFFF5F5F5);

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  static const String _ordersUrl =
      'https://365hub.site/fce-dashboard/api/my_orders.php';

  static const String _invoiceUrl =
      'https://365hub.site/fce-dashboard/api/invoice.php';

  static const String _approveMaintenanceUrl =
      'https://365hub.site/fce-dashboard/api/maintenance_approve.php';

  late Future<_MyOrdersPayload> _futurePayload;
  String _lastError = '';
  bool _approvingMaintenance = false;

  @override
  void initState() {
    super.initState();
    _futurePayload = _loadPayload();
  }

  Future<_MyOrdersPayload> _loadPayload() async {
    _lastError = '';

    final customer = await CustomerSession.getCustomer();

    if (customer == null || customer.authToken.trim().isEmpty) {
      throw Exception(
        AppController.isArabic
            ? 'الرجاء تسجيل الدخول أولاً'
            : 'Please login first',
      );
    }

    final deviceId = await CustomerSession.getOrCreateDeviceId();

    final response = await http.post(
      Uri.parse(_ordersUrl),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode({
        'auth_token': customer.authToken,
        'device_id': deviceId,
      }),
    );

    final decoded = jsonDecode(response.body);

    if (decoded['success'] != true) {
      final message = '${decoded['message'] ?? 'Could not load orders'}';
      throw Exception(message);
    }

    final List orderData = decoded['data'] ?? [];
    final List maintenanceData = decoded['maintenance_requests'] ?? [];

    return _MyOrdersPayload(
      orders: orderData.map((item) {
        return Map<String, dynamic>.from(item);
      }).toList(),
      maintenanceRequests: maintenanceData.map((item) {
        return Map<String, dynamic>.from(item);
      }).toList(),
    );
  }

  void _reload() {
    setState(() {
      _futurePayload = _loadPayload();
    });
  }

  String tr(String ar, String en) {
    return AppController.isArabic ? ar : en;
  }

  Color _statusColor(String status) {
    if (status == 'confirmed' ||
        status == 'payment_confirmed' ||
        status == 'order_confirmed' ||
        status == 'handed_to_delivery' ||
        status == 'completed') {
      return Colors.green;
    }
    if (status == 'cancelled') return Colors.grey;
    if (status == 'rejected' || status == 'payment_rejected') return Colors.red;
    if (status == 'bank_review' || status == 'pending' || status == 'new') return Colors.orange;

    return MyOrdersScreen.goldColor;
  }

  String _totalText(Map<String, dynamic> order) {
    final currency = '${order['currency'] ?? ''}';
    final total = double.tryParse('${order['total'] ?? 0}') ?? 0;

    if (currency == 'SDG') {
      return '${total.toStringAsFixed(0)} SDG';
    }

    return '${total.toStringAsFixed(2)} $currency';
  }

  String _cleanError(Object error) {
    final text = '$error'.replaceFirst('Exception: ', '').trim();

    if (text == 'Unauthorized') {
      return tr(
        'انتهت الجلسة، يرجى تسجيل الدخول مرة أخرى',
        'Session expired, please login again',
      );
    }

    if (text.isEmpty) {
      return tr(
        'تعذر تحميل الطلبات',
        'Could not load orders',
      );
    }

    return text;
  }

  Future<void> _openInvoice(Map<String, dynamic> order) async {
    final customer = await CustomerSession.getCustomer();

    if (customer == null || customer.authToken.trim().isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'انتهت الجلسة، يرجى تسجيل الدخول مرة أخرى',
              'Session expired, please login again',
            ),
          ),
        ),
      );
      return;
    }

    final deviceId = await CustomerSession.getOrCreateDeviceId();
    final orderId = int.tryParse('${order['id'] ?? 0}') ?? 0;

    if (orderId <= 0) return;

    final uri = Uri.parse(_invoiceUrl).replace(
      queryParameters: {
        'order_id': '$orderId',
        'auth_token': customer.authToken,
        'device_id': deviceId,
        'lang': AppController.language.value,
      },
    );

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceViewScreen(invoiceUrl: uri.toString()),
      ),
    );
  }


  bool _canDownloadDigital(Map<String, dynamic> item) {
    final value = '${item['can_download'] ?? ''}'.trim().toLowerCase();
    return value == '1' || value == 'true' || value == 'yes';
  }

  Future<void> _openDigitalDownload(Map<String, dynamic> item) async {
    final url = '${item['download_url'] ?? ''}'.trim();
    if (url.isEmpty) return;

    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('تعذر فتح ملف التحميل', 'Could not open download file'),
          ),
        ),
      );
    }
  }

  Widget _digitalDownloadButton(Map<String, dynamic> item) {
    if (!_canDownloadDigital(item)) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        width: double.infinity,
        height: 40,
        child: ElevatedButton.icon(
          onPressed: () => _openDigitalDownload(item),
          icon: const Icon(Icons.download_rounded, size: 18),
          label: Text(
            tr('تحميل الملف', 'Download file'),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: MyOrdersScreen.goldColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _approveMaintenance(Map<String, dynamic> request) async {
    final requestId = int.tryParse('${request['id'] ?? 0}') ?? 0;

    if (requestId <= 0 || _approvingMaintenance) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: AppController.direction,
          child: AlertDialog(
            title: Text(
              tr('تأكيد اكتمال الصيانة', 'Confirm maintenance completed'),
            ),
            content: Text(
              tr(
                'اضغط موافق فقط بعد وصول فني الصيانة واكتمال عملية الصيانة.',
                'Press OK only after the technician completes the maintenance.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(tr('إلغاء', 'Cancel')),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(tr('موافق', 'Approve')),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;

    final customer = await CustomerSession.getCustomer();

    if (customer == null || customer.authToken.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'انتهت الجلسة، يرجى تسجيل الدخول مرة أخرى',
              'Session expired, please login again',
            ),
          ),
        ),
      );
      return;
    }

    setState(() {
      _approvingMaintenance = true;
    });

    try {
      final deviceId = await CustomerSession.getOrCreateDeviceId();

      final response = await http.post(
        Uri.parse(_approveMaintenanceUrl),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          'auth_token': customer.authToken,
          'device_id': deviceId,
          'request_id': requestId,
        }),
      );

      final decoded = jsonDecode(response.body);

      if (decoded['success'] != true) {
        throw Exception(decoded['message'] ?? 'Approve failed');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('تم اعتماد الصيانة', 'Maintenance approved')),
        ),
      );

      setState(() {
        _approvingMaintenance = false;
        _futurePayload = _loadPayload();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _approvingMaintenance = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'تعذر اعتماد الصيانة',
              'Could not approve maintenance',
            ),
          ),
        ),
      );
    }
  }

  Widget _invoiceButton(Map<String, dynamic> order) {
    return SizedBox(
      width: double.infinity,
      height: 42,
      child: OutlinedButton.icon(
        onPressed: () => _openInvoice(order),
        icon: const Icon(
          Icons.picture_as_pdf_rounded,
          size: 18,
        ),
        label: Text(
          tr('فتح / تحميل الفاتورة', 'Open / Download invoice'),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: MyOrdersScreen.goldColor,
          side: const BorderSide(
            color: MyOrdersScreen.goldColor,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  Widget _trackingButton(Map<String, dynamic> order) {
    return SizedBox(
      width: double.infinity,
      height: 42,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderTrackingScreen(order: Map<String, dynamic>.from(order)),
            ),
          );
        },
        icon: const Icon(
          Icons.route_rounded,
          size: 18,
        ),
        label: Text(
          tr('متابعة الطلب', 'Track order'),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1976D2),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  Widget _orderCard(Map<String, dynamic> order) {
    final status = '${order['order_status'] ?? ''}';
    final message = '${order['customer_message'] ?? ''}';
    final reference = '${order['payment_reference'] ?? ''}';

    final rawItems = order['items'];
    final items = rawItems is List
        ? List<Map<String, dynamic>>.from(
            rawItems.map((item) => Map<String, dynamic>.from(item)),
          )
        : <Map<String, dynamic>>[];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment:
            AppController.isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${tr('رقم الطلب', 'Order')}: ${order['order_number'] ?? ''}',
                  textAlign: AppController.isArabic ? TextAlign.right : TextAlign.left,
                  style: const TextStyle(
                    color: MyOrdersScreen.darkColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _StatusChip(
                color: _statusColor(status),
                text: message,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _totalText(order),
            style: const TextStyle(
              color: MyOrdersScreen.goldColor,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (reference.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '${tr('الرقم المرجعي', 'Reference')}: $reference',
              style: TextStyle(
                color: MyOrdersScreen.darkColor.withOpacity(0.65),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 10),
          ...items.map((item) {
            final name = AppController.isArabic
                ? '${item['product_name_ar'] ?? ''}'
                : '${item['product_name_en'] ?? item['product_name_ar'] ?? ''}';

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: AppController.isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item['quantity']} × $name',
                    textAlign: AppController.isArabic ? TextAlign.right : TextAlign.left,
                  ),
                  _digitalDownloadButton(item),
                ],
              ),
            );
          }),
          const SizedBox(height: 6),
          Text(
            '${tr('التاريخ', 'Date')}: ${order['created_at'] ?? ''}',
            style: TextStyle(
              color: MyOrdersScreen.darkColor.withOpacity(0.45),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _invoiceButton(order),
          const SizedBox(height: 8),
          _trackingButton(order),
        ],
      ),
    );
  }

  Widget _maintenanceCard(Map<String, dynamic> request) {
    final status = '${request['status'] ?? ''}';
    final isCompleted = status == 'completed';
    final warrantyStatus = '${request['warranty_status'] ?? ''}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: MyOrdersScreen.goldColor.withOpacity(0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            AppController.isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${tr('طلب صيانة', 'Maintenance')}: ${request['request_number'] ?? ''}',
                  textAlign: AppController.isArabic ? TextAlign.right : TextAlign.left,
                  style: const TextStyle(
                    color: MyOrdersScreen.darkColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _StatusChip(
                color: _statusColor(status),
                text: isCompleted ? tr('تم', 'Done') : tr('قيد الانتظار', 'Waiting'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${tr('الفرع', 'Branch')}: ${request['branch'] ?? ''}',
            style: const TextStyle(
              color: MyOrdersScreen.goldColor,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text('${tr('اسم الماكينة', 'Machine')}: ${request['machine_name'] ?? ''}'),
          Text(
            '${tr('الضمان', 'Warranty')}: ${warrantyStatus == 'inside' ? tr('داخل الضمان', 'Inside warranty') : tr('خارج الضمان', 'Outside warranty')}',
          ),
          if ('${request['invoice_number'] ?? ''}'.trim().isNotEmpty)
            Text('${tr('رقم الفاتورة', 'Invoice No.')}: ${request['invoice_number']}'),
          Text('${tr('عدد الماكينات', 'Machines count')}: ${request['machines_count'] ?? 1}'),
          Text('${tr('العنوان', 'Address')}: ${request['address'] ?? ''}'),
          const SizedBox(height: 6),
          Text(
            '${tr('تاريخ الطلب', 'Request date')}: ${request['created_at'] ?? ''}',
            style: TextStyle(
              color: MyOrdersScreen.darkColor.withOpacity(0.45),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (!isCompleted) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                onPressed: _approvingMaintenance
                    ? null
                    : () => _approveMaintenance(request),
                icon: _approvingMaintenance
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.verified_rounded, size: 18),
                label: Text(
                  tr('تأكيد اكتمال الصيانة', 'Approve after maintenance'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MyOrdersScreen.goldColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppController.language,
      builder: (context, lang, child) {
        return Directionality(
          textDirection: AppController.direction,
          child: Scaffold(
            backgroundColor: MyOrdersScreen.bgColor,
            appBar: AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              title: Text(
                tr('طلباتي', 'My Orders'),
                style: const TextStyle(
                  color: MyOrdersScreen.darkColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            body: SafeArea(
              child: RefreshIndicator(
                color: MyOrdersScreen.goldColor,
                onRefresh: () async {
                  _reload();
                  await _futurePayload;
                },
                child: FutureBuilder<_MyOrdersPayload>(
                  future: _futurePayload,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: MyOrdersScreen.goldColor,
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      _lastError = _cleanError(snapshot.error!);

                      return ListView(
                        padding: const EdgeInsets.all(18),
                        children: [
                          const SizedBox(height: 80),
                          const Icon(
                            Icons.receipt_long_outlined,
                            size: 58,
                            color: MyOrdersScreen.goldColor,
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: Text(
                              tr('تعذر تحميل الطلبات', 'Could not load orders'),
                              style: const TextStyle(
                                color: MyOrdersScreen.darkColor,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              _lastError,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: MyOrdersScreen.darkColor.withOpacity(0.65),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Center(
                            child: ElevatedButton(
                              onPressed: _reload,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: MyOrdersScreen.goldColor,
                                foregroundColor: Colors.white,
                              ),
                              child: Text(tr('إعادة المحاولة', 'Retry')),
                            ),
                          ),
                        ],
                      );
                    }

                    final payload = snapshot.data ?? _MyOrdersPayload.empty();
                    final hasAny = payload.orders.isNotEmpty ||
                        payload.maintenanceRequests.isNotEmpty;

                    if (!hasAny) {
                      return ListView(
                        padding: const EdgeInsets.all(18),
                        children: [
                          const SizedBox(height: 80),
                          const Icon(
                            Icons.shopping_bag_outlined,
                            size: 60,
                            color: MyOrdersScreen.goldColor,
                          ),
                          const SizedBox(height: 14),
                          Center(
                            child: Text(
                              tr('لا توجد طلبات حتى الآن', 'No orders yet'),
                              style: const TextStyle(
                                color: MyOrdersScreen.darkColor,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return ListView(
                      padding: const EdgeInsets.all(18),
                      children: [
                        if (payload.maintenanceRequests.isNotEmpty) ...[
                          _SectionTitle(
                            title: tr('طلبات الصيانة', 'Maintenance requests'),
                          ),
                          const SizedBox(height: 10),
                          ...payload.maintenanceRequests.map((request) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _maintenanceCard(request),
                            );
                          }),
                        ],
                        if (payload.orders.isNotEmpty) ...[
                          _SectionTitle(
                            title: tr('طلبات الشراء', 'Purchase orders'),
                          ),
                          const SizedBox(height: 10),
                          ...payload.orders.map((order) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _orderCard(order),
                            );
                          }),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MyOrdersPayload {
  final List<Map<String, dynamic>> orders;
  final List<Map<String, dynamic>> maintenanceRequests;

  _MyOrdersPayload({
    required this.orders,
    required this.maintenanceRequests,
  });

  factory _MyOrdersPayload.empty() {
    return _MyOrdersPayload(
      orders: const [],
      maintenanceRequests: const [],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final Color color;
  final String text;

  const _StatusChip({
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      textAlign: AppController.isArabic ? TextAlign.right : TextAlign.left,
      style: const TextStyle(
        color: MyOrdersScreen.darkColor,
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}
