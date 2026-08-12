import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_controller.dart';
import '../models/cart_item.dart';
import '../models/customer.dart';
import '../models/payment_method.dart';
import '../services/api_service.dart';
import '../services/cart_service.dart';
import '../services/customer_session.dart';
import '../widgets/fit_one_line_text.dart';
import 'login_screen.dart';
import 'order_success_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final List<CartItem> items;
  final bool fromCart;

  const CheckoutScreen({
    super.key,
    required this.items,
    required this.fromCart,
  });

  static const Color goldColor = Color(0xFFD4A02A);
  static const Color darkColor = Color(0xFF202020);
  static const Color bgColor = Color(0xFFF5F5F5);

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final TextEditingController _notesController = TextEditingController();
  final List<TextEditingController> _referenceControllers = [TextEditingController()];

  String _paymentMethod = 'bank_khartoum';
  bool _submitting = false;
  bool _loadingPaymentMethods = true;
  Customer? _customer;
  List<PaymentMethodConfig> _paymentMethods = const [];

  String tr(String ar, String en) => AppController.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    AppController.setCurrency('SDG');
    _loadCustomer();
    _loadPaymentMethods();
  }

  @override
  void dispose() {
    _notesController.dispose();
    for (final c in _referenceControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCustomer() async {
    final customer = await CustomerSession.getCustomer();
    if (!mounted) return;
    setState(() => _customer = customer);
  }

  Future<void> _loadPaymentMethods() async {
    final methods = await ApiService.getPaymentMethods();
    if (!mounted) return;

    final selected = methods.isEmpty
        ? ''
        : (methods.any((m) => m.code == _paymentMethod) ? _paymentMethod : methods.first.code);

    setState(() {
      _paymentMethods = methods;
      _paymentMethod = selected;
      _loadingPaymentMethods = false;
    });

    final method = _selectedMethod;
    if (method != null) {
      AppController.setCurrency(method.currency);
    }
  }

  PaymentMethodConfig? get _selectedMethod {
    for (final method in _paymentMethods) {
      if (method.code == _paymentMethod) return method;
    }
    return _paymentMethods.isEmpty ? null : _paymentMethods.first;
  }

  List<String> get _references => _referenceControllers
      .map((c) => c.text.trim())
      .where((v) => v.isNotEmpty)
      .toList();

  bool get _hasDuplicateRefs {
    final normalized = _references.map((e) => e.toLowerCase()).toList();
    return normalized.toSet().length != normalized.length;
  }

  double _selectedLineTotal(CartItem item) {
    final currency = _currency;
    if (currency == 'SDG') return item.product.priceSdg * item.quantity;
    if (currency == 'AED') return item.product.priceAed * item.quantity;
    return item.product.priceUsd * item.quantity;
  }

  double get _total {
    double total = 0;
    for (final item in widget.items) {
      total += _selectedLineTotal(item);
    }
    return total;
  }

  String get _currency {
    final method = _selectedMethod;
    if (method == null) return 'USD';
    final currency = method.currency.toUpperCase();
    if (currency == 'AED' || currency == 'SDG' || currency == 'USD') return currency;
    return 'USD';
  }

  String get _totalText {
    if (_currency == 'SDG') return '${AppController.formatAmount(_total, decimals: 0)} SDG';
    return '${AppController.formatAmount(_total, decimals: 2)} $_currency';
  }

  void _selectPayment(String value) {
    setState(() => _paymentMethod = value);
    final method = _selectedMethod;
    if (method != null) {
      AppController.setCurrency(method.currency);
    }
  }

  void _addReference() {
    if (_referenceControllers.length >= 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('الحد الأقصى 20 رقم مرجعي', 'Maximum 20 reference numbers'))),
      );
      return;
    }
    setState(() => _referenceControllers.add(TextEditingController()));
  }

  void _removeReference(int index) {
    if (_referenceControllers.length == 1) {
      _referenceControllers.first.clear();
      setState(() {});
      return;
    }
    final c = _referenceControllers.removeAt(index);
    c.dispose();
    setState(() {});
  }

  Future<Customer?> _customerOrLogin() async {
    var customer = await CustomerSession.getCustomer();

    if (customer != null && customer.authToken.trim().isNotEmpty) {
      if (mounted) setState(() => _customer = customer);
      return customer;
    }

    if (!mounted) return null;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );

    if (result == true) {
      customer = await CustomerSession.getCustomer();
      if (mounted) setState(() => _customer = customer);
      return customer;
    }

    return null;
  }

  Future<Map<String, dynamic>?> _createBaseOrder({
    required String paymentMethod,
    String paymentReference = '',
  }) async {
    final customer = await _customerOrLogin();
    if (customer == null || customer.authToken.trim().isEmpty) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('انتهت الجلسة، يرجى تسجيل الدخول مرة أخرى', 'Session expired, please login again'))),
      );
      return null;
    }

    final deviceId = await CustomerSession.getOrCreateDeviceId();

    return ApiService.createOrder(
      authToken: customer.authToken,
      deviceId: deviceId,
      paymentMethod: paymentMethod,
      paymentReference: paymentReference,
      currency: _currency,
      notes: _notesController.text.trim(),
      items: widget.items,
    );
  }

  Future<void> _submitBankOrder() async {
    final refs = _references;
    final method = _selectedMethod;

    if (method == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('لا توجد وسيلة دفع مفعلة حالياً', 'No payment method is currently enabled'))),
      );
      return;
    }

    if (refs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('أدخل رقماً مرجعياً واحداً على الأقل', 'Enter at least one reference number'))),
      );
      return;
    }

    if (_hasDuplicateRefs) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('يوجد رقم مرجعي مكرر داخل الطلب', 'Duplicate reference inside this order'))),
      );
      return;
    }

    await _submitManualOrder(
      paymentMethod: method?.code ?? 'bank_khartoum',
      paymentReference: refs.join(','),
      successTitle: tr('الطلب قيد المراجعة', 'Order under review'),
      successMessage: tr('تم إرسال طلبك للمراجعة بعد إدخال الأرقام المرجعية.', 'Your order was sent for review after entering the reference numbers.'),
    );
  }

  Future<void> _submitManualOrder({
    required String paymentMethod,
    required String paymentReference,
    required String successTitle,
    required String successMessage,
  }) async {
    setState(() => _submitting = true);

    try {
      final order = await _createBaseOrder(
        paymentMethod: paymentMethod,
        paymentReference: paymentReference,
      );

      if (order == null) {
        if (mounted) setState(() => _submitting = false);
        return;
      }

      if (widget.fromCart) await CartService.clear();
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderSuccessScreen(
            orderNumber: '${order['order_number'] ?? ''}',
            totalText: _totalText,
            title: successTitle,
            message: successMessage,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final err = '$e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            err.contains('Duplicate reference')
                ? tr('يوجد رقم عملية مكرر أو مستخدم سابقاً', 'One reference is duplicated or already used')
                : tr('تعذر إنشاء الطلب، حاول مرة أخرى', 'Could not create order, please try again'),
          ),
        ),
      );
    }
  }

  Future<void> _submitHostedPayment() async {
    final method = _selectedMethod;
    if (method == null) return;

    setState(() => _submitting = true);

    try {
      final customer = await _customerOrLogin();
      if (customer == null || customer.authToken.trim().isEmpty) {
        if (!mounted) return;
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('انتهت الجلسة، يرجى تسجيل الدخول مرة أخرى', 'Session expired, please login again'))),
        );
        return;
      }

      final deviceId = await CustomerSession.getOrCreateDeviceId();

      final order = await _createBaseOrder(
        paymentMethod: method.code,
      );

      if (order == null) {
        if (mounted) setState(() => _submitting = false);
        return;
      }

      final orderId = '${order['id'] ?? order['order_id'] ?? ''}';
      final orderNumber = '${order['order_number'] ?? ''}';

      final payment = await ApiService.startPayment(
        authToken: customer.authToken,
        deviceId: deviceId,
        paymentMethod: method.code,
        orderId: orderId,
        orderNumber: orderNumber,
        amount: _total,
        currency: _currency,
      );

      final checkoutUrl = '${payment['checkout_url'] ?? payment['payment_url'] ?? ''}'.trim();

      if (checkoutUrl.isEmpty) {
        throw Exception('Payment link is not ready');
      }

      final uri = Uri.parse(checkoutUrl);
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!opened) {
        throw Exception('Could not open payment page');
      }

      if (widget.fromCart) await CartService.clear();
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderSuccessScreen(
            orderNumber: orderNumber,
            totalText: _totalText,
            title: tr('تم إنشاء الطلب', 'Order created'),
            message: tr('أكمل الدفع من صفحة الدفع، وسيتم تحديث حالة الطلب تلقائيًا بعد نجاح العملية.', 'Complete the payment page. The order status will update automatically after successful payment.'),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('بوابة الدفع غير جاهزة من لوحة التحكم', 'Payment gateway is not ready from dashboard'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppController.language,
      builder: (context, lang, child) {
        final method = _selectedMethod;
        final manual = method?.isManualReference ?? true;

        return Directionality(
          textDirection: AppController.direction,
          child: Scaffold(
            backgroundColor: CheckoutScreen.bgColor,
            appBar: AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              title: FitOneLineText(
                tr('الدفع وتأكيد الطلب', 'Checkout'),
                style: const TextStyle(color: CheckoutScreen.darkColor, fontWeight: FontWeight.w900, fontSize: 18),
              ),
              actions: [
                TextButton(
                  onPressed: AppController.toggleLanguage,
                  child: FitOneLineText(AppController.t('language')),
                ),
              ],
            ),
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth = constraints.maxWidth >= 820 ? 760.0 : constraints.maxWidth;
                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: ListView(
                        padding: const EdgeInsets.all(18),
                        children: [
                          _SectionCard(
                            title: tr('بيانات العميل', 'Customer details'),
                            child: _customer == null
                                ? Text(tr('جارٍ تحميل بيانات العميل...', 'Loading customer details...'))
                                : _CustomerDetails(customer: _customer!),
                          ),
                          const SizedBox(height: 14),
                          _SectionCard(
                            title: tr('ملخص الطلب', 'Order summary'),
                            child: Column(
                              children: [
                                ...widget.items.map((item) => _CheckoutItemRow(item: item, currency: _currency)),
                                const Divider(),
                                Row(
                                  children: [
                                    Expanded(child: Text(tr('الإجمالي', 'Total'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
                                    Text(_totalText, style: const TextStyle(color: CheckoutScreen.goldColor, fontSize: 18, fontWeight: FontWeight.w900)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          _SectionCard(
                            title: tr('طريقة الدفع', 'Payment method'),
                            child: _loadingPaymentMethods
                                ? const Center(child: CircularProgressIndicator(color: CheckoutScreen.goldColor))
                                : _paymentMethods.isEmpty
                                    ? Text(
                                        tr('لا توجد وسيلة دفع مفعلة حالياً من لوحة التحكم', 'No payment method is currently enabled from dashboard'),
                                        style: const TextStyle(color: CheckoutScreen.darkColor, fontWeight: FontWeight.w800),
                                      )
                                    : Column(
                                        children: _paymentMethods.map((paymentMethod) {
                                          return _PaymentOption(
                                            value: paymentMethod.code,
                                            groupValue: _paymentMethod,
                                            title: paymentMethod.title(AppController.isArabic),
                                            subtitle: paymentMethod.subtitle(AppController.isArabic),
                                            onChanged: _selectPayment,
                                          );
                                        }).toList(),
                                      ),
                          ),
                          const SizedBox(height: 14),
                          if (method != null)
                            manual
                                ? _BankKhartoumPaymentBox(
                                    method: method,
                                    referenceControllers: _referenceControllers,
                                    onAddReference: _addReference,
                                    onRemoveReference: _removeReference,
                                    onPay: _submitting ? null : _submitBankOrder,
                                    submitting: _submitting,
                                  )
                                : _HostedPaymentBox(
                                    method: method,
                                    totalText: _totalText,
                                    onPay: _submitting ? null : _submitHostedPayment,
                                    submitting: _submitting,
                                  ),
                          const SizedBox(height: 14),
                          _SectionCard(
                            title: tr('ملاحظات', 'Notes'),
                            child: TextField(
                              controller: _notesController,
                              maxLines: 4,
                              decoration: InputDecoration(
                                hintText: tr('أدخل أي ملاحظة عن الطلب أو التوصيل...', 'Write any order or delivery notes...'),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BankKhartoumPaymentBox extends StatelessWidget {
  final PaymentMethodConfig method;
  final List<TextEditingController> referenceControllers;
  final VoidCallback onAddReference;
  final void Function(int index) onRemoveReference;
  final VoidCallback? onPay;
  final bool submitting;

  const _BankKhartoumPaymentBox({
    required this.method,
    required this.referenceControllers,
    required this.onAddReference,
    required this.onRemoveReference,
    required this.onPay,
    required this.submitting,
  });

  String tr(String ar, String en) => AppController.isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final account = method.account(AppController.isArabic);
    return _SectionCard(
      title: method.title(AppController.isArabic),
      child: Column(
        crossAxisAlignment: AppController.isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (account.isNotEmpty)
            Text(account, style: const TextStyle(color: CheckoutScreen.darkColor, fontSize: 16, fontWeight: FontWeight.w900)),
          if (account.isNotEmpty) const SizedBox(height: 12),
          ...List.generate(referenceControllers.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: referenceControllers[index],
                      decoration: InputDecoration(
                        labelText: tr('الرقم المرجعي للعملية ${index + 1}', 'Transaction reference ${index + 1}'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => onRemoveReference(index),
                    icon: Icon(referenceControllers.length == 1 ? Icons.clear_rounded : Icons.delete_outline_rounded, color: Colors.redAccent),
                  ),
                ],
              ),
            );
          }),
          Align(
            alignment: AppController.isArabic ? Alignment.centerRight : Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: referenceControllers.length >= 20 ? null : onAddReference,
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: Text(tr('إضافة رقم مرجعي آخر', 'Add another reference'), style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
          Text(
            tr('يمكن إضافة حتى 20 رقم مرجعي لنفس الطلب.', 'You can add up to 20 reference numbers for one order.'),
            textAlign: AppController.isArabic ? TextAlign.right : TextAlign.left,
            style: TextStyle(color: CheckoutScreen.darkColor.withOpacity(0.60), fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Text(
            tr('تحذير: سيتم التعامل قانونيًا عند إدخال رقم عملية مكرر أو غير صالح.', 'Warning: Legal action may be taken for duplicate or invalid transaction references.'),
            textAlign: AppController.isArabic ? TextAlign.right : TextAlign.left,
            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: onPay,
              style: ElevatedButton.styleFrom(
                backgroundColor: CheckoutScreen.goldColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              icon: submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.payment_rounded),
              label: Text(submitting ? tr('جارٍ الدفع...', 'Paying...') : method.button(AppController.isArabic), style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

class _HostedPaymentBox extends StatelessWidget {
  final PaymentMethodConfig method;
  final String totalText;
  final VoidCallback? onPay;
  final bool submitting;

  const _HostedPaymentBox({
    required this.method,
    required this.totalText,
    required this.onPay,
    required this.submitting,
  });

  String tr(String ar, String en) => AppController.isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: method.title(AppController.isArabic),
      child: Column(
        crossAxisAlignment: AppController.isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            method.subtitle(AppController.isArabic).isNotEmpty
                ? method.subtitle(AppController.isArabic)
                : tr('سيتم فتح صفحة الدفع الآمنة لإكمال العملية.', 'A secure payment page will open to complete the payment.'),
            textAlign: AppController.isArabic ? TextAlign.right : TextAlign.left,
            style: TextStyle(color: CheckoutScreen.darkColor.withOpacity(0.65), fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F0DE),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              totalText,
              textAlign: TextAlign.center,
              style: const TextStyle(color: CheckoutScreen.darkColor, fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: onPay,
              style: ElevatedButton.styleFrom(backgroundColor: CheckoutScreen.goldColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
              icon: submitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.credit_card_rounded),
              label: Text(submitting ? tr('جارٍ التحويل...', 'Redirecting...') : method.button(AppController.isArabic), style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerDetails extends StatelessWidget {
  final Customer customer;
  const _CustomerDetails({required this.customer});
  String tr(String ar, String en) => AppController.isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: AppController.isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(customer.fullName, style: const TextStyle(color: CheckoutScreen.darkColor, fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 6),
        Text('${tr('واتساب', 'WhatsApp')}: ${customer.whatsappPhone}'),
        Text('${tr('اتصال', 'Call')}: ${customer.callPhone}'),
        Text('${customer.country} - ${customer.stateCity}'),
        if (customer.address.trim().isNotEmpty) Text(customer.address),
      ],
    );
  }
}

class _CheckoutItemRow extends StatelessWidget {
  final CartItem item;
  final String currency;
  const _CheckoutItemRow({required this.item, required this.currency});
  String tr(String ar, String en) => AppController.isArabic ? ar : en;

  String _totalText(ProductPrice p, int quantity) {
    if (currency == 'SDG') return '${AppController.formatAmount(p.sdg * quantity, decimals: 0)} SDG';
    if (currency == 'AED') return '${AppController.formatAmount(p.aed * quantity, decimals: 2)} AED';
    return '${AppController.formatAmount(p.usd * quantity, decimals: 2)} USD';
  }

  @override
  Widget build(BuildContext context) {
    final p = item.product;
    final total = _totalText(ProductPrice(p.priceUsd, p.priceAed, p.priceSdg), item.quantity);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: AppController.isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
          Text(p.name(AppController.isArabic), maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false, textAlign: AppController.isArabic ? TextAlign.right : TextAlign.left, style: const TextStyle(color: CheckoutScreen.darkColor, fontWeight: FontWeight.w900)),
          if (p.hasSelectedVariant)
            Text('${tr('المواصفة', 'Specification')}: ${p.selectedVariantName(AppController.isArabic)}', maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false, textAlign: AppController.isArabic ? TextAlign.right : TextAlign.left, style: const TextStyle(color: CheckoutScreen.goldColor, fontWeight: FontWeight.w900, fontSize: 12)),
          Text('${tr('الكمية', 'Qty')}: ${item.quantity}', style: TextStyle(color: CheckoutScreen.darkColor.withOpacity(0.6))),
        ])),
        const SizedBox(width: 10),
        Text(total, style: const TextStyle(color: CheckoutScreen.goldColor, fontWeight: FontWeight.w900)),
      ]),
    );
  }
}

class ProductPrice {
  final double usd;
  final double aed;
  final double sdg;

  const ProductPrice(this.usd, this.aed, this.sdg);
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26)),
      child: Column(crossAxisAlignment: AppController.isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: CheckoutScreen.darkColor, fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  final String value;
  final String groupValue;
  final String title;
  final String subtitle;
  final ValueChanged<String> onChanged;
  const _PaymentOption({required this.value, required this.groupValue, required this.title, required this.subtitle, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return RadioListTile<String>(
      value: value,
      groupValue: groupValue,
      activeColor: CheckoutScreen.goldColor,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: subtitle.trim().isEmpty ? null : Text(subtitle),
      contentPadding: EdgeInsets.zero,
    );
  }
}
