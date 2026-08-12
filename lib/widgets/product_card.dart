import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../models/product.dart';
import 'fit_one_line_text.dart';
import 'reliable_network_image.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    required this.onAddToCart,
  });

  static const Color goldColor = Color(0xFFD4A02A);
  static const Color darkColor = Color(0xFF202020);

  String get imageWithCacheBust {
    return product.imageUrl.trim();
  }

  String get priceText {
    return AppController.formatSelectedPrice(
      usd: product.priceUsd,
      aed: product.priceAed,
      sdg: product.priceSdg,
    );
  }

  String get originalPriceText {
    return AppController.formatSelectedPrice(
      usd: product.originalPriceUsd,
      aed: product.originalPriceAed,
      sdg: product.originalPriceSdg,
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = product.name(AppController.isArabic);
    final imageUrl = imageWithCacheBust;

    return ValueListenableBuilder<String>(
      valueListenable: AppController.currency,
      builder: (context, selectedCurrency, child) {
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.black.withOpacity(0.05),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.055),
                  blurRadius: 18,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          color: const Color(0xFFF6F2EA),
                          child: imageUrl.isNotEmpty
                              ? ReliableNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.contain,
                                  fallback: const _ProductFallbackIcon(),
                                )
                              : const _ProductFallbackIcon(),
                        ),
                      ),
                      if (product.hasActiveDiscount)
                        Positioned(
                          top: 8,
                          right: AppController.isArabic ? 8 : null,
                          left: AppController.isArabic ? null : 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              product.offerPercent > 0
                                  ? '-${product.offerPercent.toStringAsFixed(0)}%'
                                  : (AppController.isArabic ? 'عرض' : 'Offer'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 8,
                        left: AppController.isArabic ? 8 : null,
                        right: AppController.isArabic ? null : 8,
                        child: Material(
                          color: goldColor,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            onTap: onAddToCart,
                            borderRadius: BorderRadius.circular(16),
                            child: const SizedBox(
                              width: 38,
                              height: 38,
                              child: Icon(
                                Icons.add_shopping_cart_rounded,
                                color: Colors.white,
                                size: 21,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                    child: Column(
                      crossAxisAlignment: AppController.isArabic
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 20,
                          child: FitOneLineText(
                            name,
                            textAlign: AppController.isArabic
                                ? TextAlign.right
                                : TextAlign.left,
                            alignment: AppController.isArabic
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            style: const TextStyle(
                              color: darkColor,
                              fontSize: 13.8,
                              height: 1.2,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            Expanded(
                              child: Align(
                                alignment: AppController.isArabic
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: goldColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: product.hasActiveDiscount
                                      ? Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              originalPriceText,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: darkColor.withOpacity(0.48),
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                                decoration: TextDecoration.lineThrough,
                                              ),
                                            ),
                                            FitOneLineText(
                                              priceText,
                                              style: const TextStyle(
                                                color: darkColor,
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ],
                                        )
                                      : FitOneLineText(
                                          priceText,
                                          style: const TextStyle(
                                            color: darkColor,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: goldColor,
                            ),
                          ],
                        ),
                      ],
                    ),
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

class _ProductFallbackIcon extends StatelessWidget {
  const _ProductFallbackIcon();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.precision_manufacturing_rounded,
        color: ProductCard.goldColor.withOpacity(0.55),
        size: 56,
      ),
    );
  }
}
