import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../models/product_type.dart';
import 'fit_one_line_text.dart';
import 'reliable_network_image.dart';

class ProductTypeCard extends StatelessWidget {
  final ProductType type;
  final int index;
  final VoidCallback? onTap;

  const ProductTypeCard({
    super.key,
    required this.type,
    required this.index,
    this.onTap,
  });

  static const Color goldColor = Color(0xFFD4A02A);
  static const Color darkColor = Color(0xFF202020);

  IconData get fallbackIcon {
    switch (type.code) {
      case 'machine':
        return Icons.precision_manufacturing_rounded;
      case 'spare_part':
        return Icons.settings_suggest_rounded;
      case 'cnc_product':
        return Icons.inventory_2_rounded;
      case 'digital_design':
        return Icons.design_services_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  List<Color> get cardColors {
    final colors = [
      [const Color(0xFF202020), const Color(0xFF3A3A3A)],
      [const Color(0xFFD4A02A), const Color(0xFF9A6B13)],
      [const Color(0xFF313131), const Color(0xFF575757)],
      [const Color(0xFFB8860B), const Color(0xFF2A2A2A)],
    ];

    return colors[index % colors.length];
  }

  String get imageWithCacheBust {
    return type.imageUrl.trim();
  }

  @override
  Widget build(BuildContext context) {
    final name = type.name(AppController.isArabic);
    final imageUrl = imageWithCacheBust;

    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: Colors.black.withOpacity(0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: cardColors,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: -45,
                      right: -45,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.09),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -35,
                      left: -35,
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.07),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.94),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: imageUrl.isNotEmpty
                                ? ReliableNetworkImage(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.contain,
                                    fallback: _FallbackIcon(icon: fallbackIcon),
                                  )
                                : _FallbackIcon(icon: fallbackIcon),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: AppController.isArabic
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 23,
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
                        fontSize: 15.5,
                        height: 1.18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AppController.isArabic
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: goldColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: FitOneLineText(
                        '${type.productsCount} ${AppController.t('products')}',
                        style: const TextStyle(
                          color: darkColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
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
  }
}

class _FallbackIcon extends StatelessWidget {
  final IconData icon;

  const _FallbackIcon({
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        icon,
        color: ProductTypeCard.goldColor.withOpacity(0.65),
        size: 58,
      ),
    );
  }
}
