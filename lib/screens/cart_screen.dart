import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../models/cart_item.dart';
import '../services/cart_service.dart';
import '../services/customer_session.dart';
import '../widgets/currency_selector_button.dart';
import '../widgets/quantity_selector.dart';
import '../widgets/reliable_network_image.dart';
import 'checkout_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  static const Color goldColor = Color(0xFFD4A02A);
  static const Color darkColor = Color(0xFF202020);
  static const Color bgColor = Color(0xFFF5F5F5);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<CartItem> _items = [];
  bool _loading = true;

  String tr(String ar, String en) {
    return AppController.isArabic ? ar : en;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await CartService.getItems();

    if (!mounted) return;

    setState(() {
      _items = items;
      _loading = false;
    });
  }

  double _selectedLineTotal(CartItem item) {
    final currency = AppController.currency.value;

    if (currency == 'AED') {
      return item.product.priceAed * item.quantity;
    }

    if (currency == 'SDG') {
      return item.product.priceSdg * item.quantity;
    }

    return item.product.priceUsd * item.quantity;
  }

  double get _total {
    double total = 0;

    for (final item in _items) {
      total += _selectedLineTotal(item);
    }

    return total;
  }

  String get _totalText {
    final currency = AppController.currency.value;

    if (currency == 'SDG') {
      return '${_total.toStringAsFixed(0)} SDG';
    }

    return '${_total.toStringAsFixed(2)} $currency';
  }

  Future<void> _setQuantity(CartItem item, int quantity) async {
    await CartService.setQuantityByKey(item.product.cartKey, quantity);
    await _load();
  }

  Future<void> _remove(CartItem item) async {
    await CartService.removeProductByKey(item.product.cartKey);
    await _load();
  }

  Future<void> _clear() async {
    await CartService.clear();
    await _load();
  }

  Future<bool> _ensureLoggedIn() async {
    final customer = await CustomerSession.getCustomer();

    if (customer != null && customer.authToken.trim().isNotEmpty) {
      return true;
    }

    if (!mounted) return false;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Directionality(
          textDirection: AppController.direction,
          child: Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline,
                  color: CartScreen.goldColor,
                  size: 44,
                ),
                const SizedBox(height: 12),
                Text(
                  tr(
                    'يجب إنشاء حساب أو تسجيل الدخول قبل الدفع',
                    'Please login or create an account before checkout',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: CartScreen.darkColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context, 'login');
                        },
                        child: Text(tr('تسجيل الدخول', 'Login')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context, 'register');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CartScreen.goldColor,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(tr('إنشاء حساب', 'Create Account')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) return false;

    if (action == 'login') {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
      );

      return result == true;
    }

    if (action == 'register') {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const RegisterScreen(),
        ),
      );

      return result == true;
    }

    return false;
  }

  Future<void> _goCheckout() async {
    if (_items.isEmpty) return;

    final loggedIn = await _ensureLoggedIn();

    if (!loggedIn || !mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          items: _items,
          fromCart: true,
        ),
      ),
    );

    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppController.language,
      builder: (context, lang, child) {
        return ValueListenableBuilder<String>(
          valueListenable: AppController.currency,
          builder: (context, selectedCurrency, child) {
            return Directionality(
              textDirection: AppController.direction,
              child: Scaffold(
                backgroundColor: CartScreen.bgColor,
                appBar: AppBar(
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.white,
                  elevation: 0,
                  centerTitle: true,
                  title: Text(
                    tr('السلة', 'Cart'),
                    style: const TextStyle(
                      color: CartScreen.darkColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  actions: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Center(
                        child: CurrencySelectorButton(compact: true),
                      ),
                    ),
                    if (_items.isNotEmpty)
                      IconButton(
                        onPressed: _clear,
                        icon: const Icon(Icons.delete_outline),
                      ),
                  ],
                ),
                body: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: CartScreen.goldColor,
                        ),
                      )
                    : _items.isEmpty
                        ? _EmptyCartMessage(
                            title: tr('السلة فارغة حالياً', 'Your cart is empty'),
                          )
                        : SafeArea(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final maxWidth = constraints.maxWidth >= 820
                                    ? 760.0
                                    : constraints.maxWidth;

                                return Center(
                                  child: ConstrainedBox(
                                    constraints:
                                        BoxConstraints(maxWidth: maxWidth),
                                    child: Column(
                                      children: [
                                        Expanded(
                                          child: ListView.separated(
                                            padding: const EdgeInsets.all(18),
                                            itemCount: _items.length,
                                            separatorBuilder: (_, __) {
                                              return const SizedBox(height: 12);
                                            },
                                            itemBuilder: (context, index) {
                                              final item = _items[index];
                                              return _CartItemCard(
                                                item: item,
                                                onMinus: () {
                                                  _setQuantity(
                                                    item,
                                                    item.quantity - 1,
                                                  );
                                                },
                                                onPlus: () {
                                                  _setQuantity(
                                                    item,
                                                    item.quantity + 1,
                                                  );
                                                },
                                                onRemove: () {
                                                  _remove(item);
                                                },
                                              );
                                            },
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.all(18),
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.vertical(
                                              top: Radius.circular(28),
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      tr('الإجمالي', 'Total'),
                                                      style: const TextStyle(
                                                        color: CartScreen
                                                            .darkColor,
                                                        fontSize: 17,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                      ),
                                                    ),
                                                  ),
                                                  Text(
                                                    _totalText,
                                                    style: const TextStyle(
                                                      color:
                                                          CartScreen.goldColor,
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 14),
                                              SizedBox(
                                                width: double.infinity,
                                                height: 52,
                                                child: ElevatedButton.icon(
                                                  onPressed: _goCheckout,
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        CartScreen.goldColor,
                                                    foregroundColor:
                                                        Colors.white,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        18,
                                                      ),
                                                    ),
                                                  ),
                                                  icon: const Icon(
                                                    Icons.payment_rounded,
                                                  ),
                                                  label: Text(
                                                    tr(
                                                      'المتابعة إلى الدفع',
                                                      'Checkout',
                                                    ),
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w900,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
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
      },
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final CartItem item;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onRemove;

  const _CartItemCard({
    required this.item,
    required this.onMinus,
    required this.onPlus,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final product = item.product;
    final name = product.name(AppController.isArabic);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 92,
              height: 62,
              child: product.imageUrl.trim().isNotEmpty
                  ? ReliableNetworkImage(
                      imageUrl: product.imageUrl,
                      fit: BoxFit.contain,
                      width: 92,
                      height: 62,
                      fallback: const _CartImageFallback(),
                    )
                  : const _CartImageFallback(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: AppController.isArabic
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  textAlign:
                      AppController.isArabic ? TextAlign.right : TextAlign.left,
                  style: const TextStyle(
                    color: CartScreen.darkColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (product.hasSelectedVariant) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${AppController.isArabic ? 'المواصفة' : 'Specification'}: ${product.selectedVariantName(AppController.isArabic)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    textAlign:
                        AppController.isArabic ? TextAlign.right : TextAlign.left,
                    style: TextStyle(
                      color: CartScreen.goldColor.withOpacity(0.85),
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  AppController.formatSelectedPrice(
                    usd: product.priceUsd,
                    aed: product.priceAed,
                    sdg: product.priceSdg,
                  ),
                  style: TextStyle(
                    color: CartScreen.darkColor.withOpacity(0.6),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    QuantitySelector(
                      quantity: item.quantity,
                      onMinus: onMinus,
                      onPlus: onPlus,
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: onRemove,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCartMessage extends StatelessWidget {
  final String title;

  const _EmptyCartMessage({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.shopping_cart_outlined,
              color: CartScreen.goldColor,
              size: 64,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                color: CartScreen.darkColor,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartImageFallback extends StatelessWidget {
  const _CartImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F2EA),
      child: Center(
        child: Icon(
          Icons.precision_manufacturing_rounded,
          color: CartScreen.goldColor.withOpacity(0.55),
        ),
      ),
    );
  }
}
