import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../models/product.dart';
import '../models/product_type.dart';
import '../services/api_service.dart';
import '../services/cart_service.dart';
import '../widgets/cart_icon_button.dart';
import '../widgets/currency_selector_button.dart';
import '../widgets/product_card.dart';
import 'cart_screen.dart';
import 'product_details_screen.dart';

class ProductsScreen extends StatefulWidget {
  final ProductType type;

  const ProductsScreen({
    super.key,
    required this.type,
  });

  static const Color goldColor = Color(0xFFD4A02A);
  static const Color darkColor = Color(0xFF202020);
  static const Color bgColor = Color(0xFFF5F5F5);

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  late Future<List<Product>> _futureProducts;

  @override
  void initState() {
    super.initState();
    _futureProducts = ApiService.getProductsByType(
      typeCode: widget.type.code,
    );
  }

  void _reload() {
    setState(() {
      _futureProducts = ApiService.getProductsByType(
        typeCode: widget.type.code,
      );
    });
  }

  void _openCart() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CartScreen(),
      ),
    ).then((_) {
      setState(() {});
    });
  }

  int _gridCount(double width) {
    if (width >= 1100) return 4;
    if (width >= 760) return 3;
    return 2;
  }

  double _gridRatio(double width) {
    if (width <= 340) return 0.74;
    if (width <= 390) return 0.78;
    if (width >= 760) return 0.84;
    return 0.82;
  }

  String tr(String ar, String en) {
    return AppController.isArabic ? ar : en;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppController.language,
      builder: (context, lang, child) {
        return ValueListenableBuilder<String>(
          valueListenable: AppController.currency,
          builder: (context, selectedCurrency, child) {
            final title = widget.type.name(AppController.isArabic);

            return Directionality(
              textDirection: AppController.direction,
              child: Scaffold(
                backgroundColor: ProductsScreen.bgColor,
                appBar: AppBar(
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.white,
                  elevation: 0,
                  centerTitle: true,
                  title: Text(
                    title,
                    style: const TextStyle(
                      color: ProductsScreen.darkColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  actions: [
                    CartIconButton(
                      onTap: _openCart,
                      iconColor: ProductsScreen.darkColor,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Center(
                        child: CurrencySelectorButton(compact: true),
                      ),
                    ),
                    TextButton(
                      onPressed: AppController.toggleLanguage,
                      child: Text(AppController.t('language')),
                    ),
                  ],
                ),
                body: SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final pageWidth = constraints.maxWidth;
                      final maxContentWidth =
                          pageWidth >= 900 ? 880.0 : pageWidth;

                      return Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: maxContentWidth,
                          ),
                          child: RefreshIndicator(
                            color: ProductsScreen.goldColor,
                            onRefresh: () async {
                              _reload();
                              await _futureProducts;
                            },
                            child: FutureBuilder<List<Product>>(
                              future: _futureProducts,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return ListView(
                                    children: [
                                      const SizedBox(height: 130),
                                      const Center(
                                        child: CircularProgressIndicator(
                                          color: ProductsScreen.goldColor,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      Center(
                                        child: Text(AppController.t('loading')),
                                      ),
                                    ],
                                  );
                                }

                                if (snapshot.hasError) {
                                  return ListView(
                                    padding: const EdgeInsets.all(18),
                                    children: [
                                      const SizedBox(height: 60),
                                      _ErrorBox(onRetry: _reload),
                                    ],
                                  );
                                }

                                final products = snapshot.data ?? [];

                                if (products.isEmpty) {
                                  return ListView(
                                    padding: const EdgeInsets.all(18),
                                    children: [
                                      const SizedBox(height: 60),
                                      Container(
                                        padding: const EdgeInsets.all(24),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(24),
                                        ),
                                        child: Column(
                                          children: [
                                            const Icon(
                                              Icons.inventory_2_outlined,
                                              color: ProductsScreen.goldColor,
                                              size: 52,
                                            ),
                                            const SizedBox(height: 14),
                                            Text(
                                              tr(
                                                'لا توجد منتجات في هذا القسم حالياً',
                                                'No products in this type yet',
                                              ),
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                color: ProductsScreen.darkColor,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }

                                return GridView.builder(
                                  padding: const EdgeInsets.all(18),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: _gridCount(pageWidth),
                                    mainAxisSpacing: 16,
                                    crossAxisSpacing: 16,
                                    childAspectRatio: _gridRatio(pageWidth),
                                  ),
                                  itemCount: products.length,
                                  itemBuilder: (context, index) {
                                    final product = products[index];

                                    return ProductCard(
                                      product: product,
                                      onAddToCart: () async {
                                        await CartService.addProduct(product, 1);
                                        if (!mounted) return;
                                        setState(() {});
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              tr('تمت الإضافة إلى السلة', 'Added to cart'),
                                            ),
                                          ),
                                        );
                                      },
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                ProductDetailsScreen(
                                              product: product,
                                            ),
                                          ),
                                        ).then((_) {
                                          setState(() {});
                                        });
                                      },
                                    );
                                  },
                                );
                              },
                            ),
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

class _ErrorBox extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorBox({
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 45,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 12),
          Text(
            AppController.t('connection_error'),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: onRetry,
            child: Text(AppController.t('retry')),
          ),
        ],
      ),
    );
  }
}
