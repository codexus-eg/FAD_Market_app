import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../services/cart_service.dart';
import '../widgets/cart_icon_button.dart';
import '../widgets/currency_selector_button.dart';
import '../widgets/fit_one_line_text.dart';
import '../widgets/product_card.dart';
import 'cart_screen.dart';
import 'product_details_screen.dart';

class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key});

  static const Color goldColor = Color(0xFFD4A02A);
  static const Color darkColor = Color(0xFF202020);
  static const Color bgColor = Color(0xFFF5F5F5);

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  late Future<List<Product>> _futureOffers;

  @override
  void initState() {
    super.initState();
    _futureOffers = ApiService.getOffers();
  }

  void _reload() {
    setState(() {
      _futureOffers = ApiService.getOffers();
    });
  }

  void _openCart() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())).then((_) => setState(() {}));
  }

  String tr(String ar, String en) => AppController.isArabic ? ar : en;

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
                backgroundColor: OffersScreen.bgColor,
                appBar: AppBar(
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.white,
                  elevation: 0,
                  centerTitle: true,
                  title: FitOneLineText(
                    tr('العروض', 'Offers'),
                    style: const TextStyle(color: OffersScreen.darkColor, fontWeight: FontWeight.w900, fontSize: 19),
                  ),
                  actions: [
                    CartIconButton(onTap: _openCart, iconColor: OffersScreen.darkColor),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Center(child: CurrencySelectorButton(compact: true)),
                    ),
                    TextButton(onPressed: AppController.toggleLanguage, child: Text(AppController.t('language'))),
                  ],
                ),
                body: SafeArea(
                  child: RefreshIndicator(
                    color: OffersScreen.goldColor,
                    onRefresh: () async {
                      _reload();
                      await _futureOffers;
                    },
                    child: FutureBuilder<List<Product>>(
                      future: _futureOffers,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return ListView(
                            children: [
                              const SizedBox(height: 120),
                              const Center(child: CircularProgressIndicator(color: OffersScreen.goldColor)),
                              const SizedBox(height: 14),
                              Center(child: Text(AppController.t('loading'))),
                            ],
                          );
                        }

                        if (snapshot.hasError) {
                          return ListView(
                            padding: const EdgeInsets.all(18),
                            children: [
                              const SizedBox(height: 70),
                              _OffersMessage(
                                icon: Icons.wifi_off_rounded,
                                title: tr('تعذر تحميل العروض', 'Could not load offers'),
                                subtitle: tr('اسحب الشاشة لتحديث العروض مرة أخرى', 'Pull down to refresh offers'),
                              ),
                            ],
                          );
                        }

                        final offers = snapshot.data ?? [];
                        if (offers.isEmpty) {
                          return ListView(
                            padding: const EdgeInsets.all(18),
                            children: [
                              const SizedBox(height: 70),
                              _OffersMessage(
                                icon: Icons.local_offer_outlined,
                                title: tr('لا توجد عروض حالياً', 'No offers right now'),
                                subtitle: tr('عند إضافة عروض جديدة ستظهر هنا تلقائياً', 'New offers will appear here automatically'),
                              ),
                            ],
                          );
                        }

                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final pageWidth = constraints.maxWidth;
                            final maxContentWidth = pageWidth >= 900 ? 880.0 : pageWidth;

                            return Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: maxContentWidth),
                                child: CustomScrollView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  slivers: [
                                    SliverToBoxAdapter(child: _AnimatedOffersBanner(count: offers.length)),
                                    SliverPadding(
                                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                                      sliver: SliverGrid(
                                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          mainAxisSpacing: 16,
                                          crossAxisSpacing: 16,
                                          childAspectRatio: 0.80,
                                        ),
                                        delegate: SliverChildBuilderDelegate(
                                          (context, index) {
                                            final product = offers[index];
                                            return ProductCard(
                                              product: product,
                                              onAddToCart: () async {
                                                await CartService.addProduct(product, 1);
                                                if (!mounted) return;
                                                setState(() {});
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text(tr('تمت الإضافة إلى السلة', 'Added to cart'))),
                                                );
                                              },
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(builder: (_) => ProductDetailsScreen(product: product)),
                                                ).then((_) => setState(() {}));
                                              },
                                            );
                                          },
                                          childCount: offers.length,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
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

class _AnimatedOffersBanner extends StatelessWidget {
  final int count;
  const _AnimatedOffersBanner({required this.count});

  String tr(String ar, String en) => AppController.isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.92, end: 1.0),
      duration: const Duration(milliseconds: 650),
      curve: Curves.elasticOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Container(
            margin: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF202020), Color(0xFF3A3A3A)]),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.13), blurRadius: 24, offset: const Offset(0, 12))],
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(color: OffersScreen.goldColor.withOpacity(0.18), borderRadius: BorderRadius.circular(20)),
                  child: const Icon(Icons.local_fire_department_rounded, color: OffersScreen.goldColor, size: 30),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: AppController.isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      FitOneLineText(
                        tr('استفد من العروض 🔥', 'Catch the offers 🔥'),
                        alignment: AppController.isArabic ? Alignment.centerRight : Alignment.centerLeft,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                      ),
                      const SizedBox(height: 5),
                      FitOneLineText(
                        tr('عدد المنتجات المخفضة الآن: $count', '$count products on sale now'),
                        alignment: AppController.isArabic ? Alignment.centerRight : Alignment.centerLeft,
                        style: TextStyle(color: Colors.white.withOpacity(0.70), fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OffersMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _OffersMessage({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
      child: Column(
        children: [
          Icon(icon, color: OffersScreen.goldColor, size: 56),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(color: OffersScreen.darkColor, fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: OffersScreen.darkColor.withOpacity(0.58), height: 1.45, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
