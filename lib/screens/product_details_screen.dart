import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../services/cart_service.dart';
import '../services/customer_session.dart';
import '../widgets/cart_icon_button.dart';
import '../widgets/currency_selector_button.dart';
import '../widgets/fit_one_line_text.dart';
import '../widgets/quantity_selector.dart';
import '../widgets/reliable_network_image.dart';
import 'cart_screen.dart';
import 'checkout_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Product product;

  const ProductDetailsScreen({super.key, required this.product});

  static const Color goldColor = Color(0xFFD4A02A);
  static const Color darkColor = Color(0xFF202020);
  static const Color bgColor = Color(0xFFF5F5F5);

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  late Future<Product> _futureProduct;
  final PageController _pageController = PageController();

  int _quantity = 1;
  int _imageIndex = 0;
  bool _busy = false;
  ProductVariant? _selectedVariant;
  final Map<int, List<String>> _variantGalleryCache = <int, List<String>>{};
  final Set<int> _variantGalleryLoading = <int>{};

  String tr(String ar, String en) => AppController.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _futureProduct = _loadDetails();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<Product> _loadDetails() async {
    try {
      return await ApiService.getProductDetails(productId: widget.product.id);
    } catch (_) {
      return widget.product;
    }
  }

  Product _selectedProduct(Product product) {
    return _selectedVariant == null
        ? product
        : product.copyWithSelectedVariant(_selectedVariant);
  }

  String _withCacheBust(String url, String key) {
    return url.trim();
  }

  String _imageKey(String value) {
    var clean = value.trim();
    if (clean.isEmpty) return '';

    clean = clean.replaceAll('\\', '/');

    // Some image API URLs use query values as the actual image identity.
    // If we remove ?file= or ?id=, multiple option images collapse into one
    // and the swipe gallery shows a single image only.
    final lowerBeforeQueryCleanup = clean.toLowerCase();
    final queryIsImageIdentity = lowerBeforeQueryCleanup.contains('/api/optimized_image.php?') ||
        lowerBeforeQueryCleanup.contains('/api/product_image.php?') ||
        lowerBeforeQueryCleanup.contains('/api/product_type_image.php?') ||
        lowerBeforeQueryCleanup.contains('/api/product_type_gallery_image.php?') ||
        lowerBeforeQueryCleanup.contains('/api/product_variant_image.php?') ||
        lowerBeforeQueryCleanup.contains('?file=') ||
        lowerBeforeQueryCleanup.contains('&file=') ||
        lowerBeforeQueryCleanup.contains('?id=') ||
        lowerBeforeQueryCleanup.contains('&id=');

    if (queryIsImageIdentity) {
      final uri = Uri.tryParse(clean);
      if (uri != null) {
        final entries = <MapEntry<String, String>>[];
        for (final entry in uri.queryParameters.entries) {
          final key = entry.key.toLowerCase();
          if (key == 'v' || key == 't' || key == 'ts' || key == 'cache' || key == 'cb') continue;
          entries.add(MapEntry(key, entry.value));
        }
        entries.sort((a, b) => a.key.compareTo(b.key));
        final query = entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').join('&');
        clean = uri.replace(query: query.isEmpty ? null : query).toString();
      }
    } else {
      final queryIndex = clean.indexOf('?');
      if (queryIndex >= 0) clean = clean.substring(0, queryIndex);
    }

    final dashboardIndex = clean.indexOf('/fce-dashboard/');
    if (dashboardIndex >= 0) {
      clean = clean.substring(dashboardIndex);
    }

    while (clean.contains('//')) {
      clean = clean.replaceAll('//', '/');
    }

    return clean.toLowerCase();
  }

  List<String> _uniqueImages(Iterable<String> values) {
    final seen = <String>{};
    final result = <String>[];

    for (final value in values) {
      final clean = value.trim();
      final key = _imageKey(clean);
      if (clean.isEmpty || key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      result.add(clean);
    }

    return result;
  }

  String _firstBaseImage(Product product) {
    if (product.imageUrl.trim().isNotEmpty) return product.imageUrl.trim();

    final mainImages = product.images.where((img) => img.isMain && img.imageUrl.trim().isNotEmpty);
    if (mainImages.isNotEmpty) return mainImages.first.imageUrl.trim();

    final anyImages = product.images.where((img) => img.imageUrl.trim().isNotEmpty);
    if (anyImages.isNotEmpty) return anyImages.first.imageUrl.trim();

    return '';
  }

  String _optionThumbnailUrl(ProductVariant? variant) {
    if (variant == null) return '';

    if (_variantGalleryCache.containsKey(variant.id)) {
      final cachedImages = _variantGalleryCache[variant.id] ?? const <String>[];
      return cachedImages.isNotEmpty ? cachedImages.first : '';
    }

    if (variant.imageUrl.trim().isNotEmpty) {
      return variant.imageUrl.trim();
    }

    for (final img in variant.images) {
      if (img.imageUrl.trim().isNotEmpty) return img.imageUrl.trim();
    }

    // Never borrow the original product image for an option with no image.
    return '';
  }

  List<String> _variantLocalImages(ProductVariant variant) {
    final urls = <String>[];

    if (variant.imageUrl.trim().isNotEmpty) {
      urls.add(variant.imageUrl.trim());
    }

    for (final img in variant.images) {
      if (img.imageUrl.trim().isNotEmpty) urls.add(img.imageUrl.trim());
    }

    return _uniqueImages(urls).take(5).toList();
  }

  List<String> _variantImagesFromDetailedProduct(Product product, int variantId) {
    final urls = <String>[];

    // Read media only from the matching option object. This remains safe even
    // against an older API that accidentally leaves product images at top level.
    for (final variant in product.variants) {
      if (variant.id != variantId) continue;
      if (variant.imageUrl.trim().isNotEmpty) urls.add(variant.imageUrl.trim());
      for (final img in variant.images) {
        if (img.imageUrl.trim().isNotEmpty) urls.add(img.imageUrl.trim());
      }
      break;
    }

    // New strict API responses mark the requested option explicitly. Use the
    // top-level media only under that explicit marker, never as an implicit fallback.
    if (product.selectedVariantId == variantId) {
      if (product.imageUrl.trim().isNotEmpty) urls.add(product.imageUrl.trim());
      for (final img in product.images) {
        if (img.imageUrl.trim().isNotEmpty) urls.add(img.imageUrl.trim());
      }
    }

    return _uniqueImages(urls).take(5).toList();
  }

  List<String> _imagesFor(Product product) {
    final selectedVariant = _selectedVariant;

    if (selectedVariant != null) {
      if (_variantGalleryCache.containsKey(selectedVariant.id)) {
        final cachedImages = _variantGalleryCache[selectedVariant.id] ?? const <String>[];
        return cachedImages.take(5).toList();
      }

      final localImages = _variantLocalImages(selectedVariant);
      if (localImages.isNotEmpty) return localImages;

      // Important: do not fall back to the original product gallery while an
      // option is selected. Option images must stay separated from product images.
      return const <String>[];
    }

    final urls = <String>[];

    if (product.imageUrl.trim().isNotEmpty) {
      urls.add(product.imageUrl.trim());
    }

    for (final img in product.images.take(4)) {
      if (img.imageUrl.trim().isNotEmpty) urls.add(img.imageUrl.trim());
    }

    return _uniqueImages(urls).take(5).toList();
  }

  String _unitPrice(Product product) {
    final selected = _selectedProduct(product);
    return AppController.formatSelectedPrice(
      usd: selected.priceUsd,
      aed: selected.priceAed,
      sdg: selected.priceSdg,
    );
  }

  String _originalUnitPrice(Product product) {
    final selected = _selectedProduct(product);
    return AppController.formatSelectedPrice(
      usd: selected.originalPriceUsd,
      aed: selected.originalPriceAed,
      sdg: selected.originalPriceSdg,
    );
  }

  String _totalPrice(Product product) {
    final selected = _selectedProduct(product);
    return AppController.formatSelectedPrice(
      usd: selected.priceUsd * _quantity,
      aed: selected.priceAed * _quantity,
      sdg: selected.priceSdg * _quantity,
    );
  }

  void _increase() {
    if (_quantity >= 99) return;
    setState(() => _quantity++);
  }

  void _decrease() {
    if (_quantity <= 1) return;
    setState(() => _quantity--);
  }

  Future<void> _loadVariantGallery(Product product, ProductVariant variant) async {
    if (variant.id <= 0) return;
    if (_variantGalleryCache.containsKey(variant.id)) return;
    if (_variantGalleryLoading.contains(variant.id)) return;

    _variantGalleryLoading.add(variant.id);

    try {
      final detailed = await ApiService.getProductDetails(
        productId: product.id,
        variantId: variant.id,
      );

      final remoteImages = _variantImagesFromDetailedProduct(detailed, variant.id);
      final localImages = _variantLocalImages(variant);
      final finalImages = _uniqueImages([...remoteImages, ...localImages]).take(5).toList();

      if (!mounted || _selectedVariant?.id != variant.id) return;

      setState(() {
        // Cache empty galleries too. Empty is a valid authoritative result and
        // must not trigger a fallback to product images on the next selection.
        _variantGalleryCache[variant.id] = finalImages;
        _imageIndex = 0;
      });
      _goToFirstImage();
    } catch (_) {
      final localImages = _variantLocalImages(variant);
      if (!mounted || _selectedVariant?.id != variant.id) return;
      setState(() {
        _variantGalleryCache[variant.id] = localImages;
        _imageIndex = 0;
      });
      _goToFirstImage();
    } finally {
      _variantGalleryLoading.remove(variant.id);
    }
  }

  void _goToFirstImage() {
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    }
  }

  void _selectOriginalProduct() {
    setState(() {
      _selectedVariant = null;
      _imageIndex = 0;
    });

    _goToFirstImage();
  }

  void _selectVariant(Product product, ProductVariant variant) {
    setState(() {
      _selectedVariant = variant;
      _imageIndex = 0;
    });

    _goToFirstImage();
    _loadVariantGallery(product, variant);
  }

  void _jumpImage(int delta, int totalImages) {
    if (totalImages <= 1) return;

    final nextIndex = (_imageIndex + delta).clamp(0, totalImages - 1).toInt();
    if (nextIndex == _imageIndex) return;

    setState(() => _imageIndex = nextIndex);

    if (_pageController.hasClients) {
      _pageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _addToCart(Product product) async {
    setState(() => _busy = true);
    await CartService.addProduct(_selectedProduct(product), _quantity);

    if (!mounted) return;
    setState(() => _busy = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('تمت الإضافة إلى السلة', 'Added to cart')),
        action: SnackBarAction(label: tr('عرض السلة', 'Cart'), onPressed: _openCart),
      ),
    );
  }

  Future<bool> _ensureLoggedIn() async {
    final customer = await CustomerSession.getCustomer();
    if (customer != null && customer.authToken.trim().isNotEmpty) return true;
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
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, color: ProductDetailsScreen.goldColor, size: 44),
                const SizedBox(height: 12),
                Text(
                  tr('يجب إنشاء حساب أو تسجيل الدخول قبل إكمال الطلب', 'Please login or create an account to continue'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: ProductDetailsScreen.darkColor, fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, 'login'),
                        child: FitOneLineText(tr('تسجيل الدخول', 'Login')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, 'register'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ProductDetailsScreen.goldColor,
                          foregroundColor: Colors.white,
                        ),
                        child: FitOneLineText(tr('إنشاء حساب', 'Create Account')),
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
      final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      return result == true;
    }

    if (action == 'register') {
      final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
      return result == true;
    }

    return false;
  }

  Future<void> _buyNow(Product product) async {
    final loggedIn = await _ensureLoggedIn();
    if (!loggedIn || !mounted) return;

    await CartService.addProduct(_selectedProduct(product), _quantity);
    final allItems = await CartService.getItems();

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(items: allItems, fromCart: true),
      ),
    ).then((_) => setState(() {}));
  }

  void _openCart() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())).then((_) => setState(() {}));
  }

  void _openImageZoom(List<String> images, int initialIndex) {
    if (images.isEmpty) return;

    showDialog(
      context: context,
      builder: (_) {
        final controller = PageController(initialPage: initialIndex);

        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Directionality(
            textDirection: AppController.direction,
            child: Stack(
              children: [
                PageView.builder(
                  controller: controller,
                  itemCount: images.length,
                  itemBuilder: (context, index) {
                    return InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: Center(
                        child: ReliableNetworkImage(
                          imageUrl: _withCacheBust(
                            images[index],
                            'zoom_${widget.product.id}_$index',
                          ),
                          fit: BoxFit.contain,
                          loadingColor: Colors.white,
                          fallback: const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white,
                            size: 80,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  top: 34,
                  left: 14,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 32),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _imageViewer(Product product) {
    final images = _imagesFor(product);
    final safeImageIndex = images.isEmpty ? 0 : _imageIndex.clamp(0, images.length - 1).toInt();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 22, offset: const Offset(0, 12)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: images.isEmpty
                ? const _FallbackProductImage()
                : Stack(
                    children: [
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: () => _openImageZoom(images, safeImageIndex),
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: images.length,
                            allowImplicitScrolling: true,
                            physics: const BouncingScrollPhysics(),
                            onPageChanged: (index) => setState(() => _imageIndex = index),
                            itemBuilder: (context, index) {
                              return Container(
                                color: const Color(0xFFF6F2EA),
                                child: ReliableNetworkImage(
                                  imageUrl: _withCacheBust(
                                    images[index],
                                    '${product.id}_$index',
                                  ),
                                  fit: BoxFit.contain,
                                  fallback: const _FallbackProductImage(),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      if (images.length > 1) ...[
                        Positioned(
                          left: 8,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: _ImageArrowButton(
                              icon: Icons.chevron_left_rounded,
                              onTap: () => _jumpImage(-1, images.length),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 8,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: _ImageArrowButton(
                              icon: Icons.chevron_right_rounded,
                              onTap: () => _jumpImage(1, images.length),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          if (images.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(images.length, (index) {
                  final active = index == safeImageIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 18 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: active ? ProductDetailsScreen.goldColor : Colors.black.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _variantsBar(Product product) {
    if (product.variants.isEmpty) return const SizedBox.shrink();

    const selectedGreen = Color(0xFF159947);

    Widget optionTile({
      required bool selected,
      required String imageUrl,
      required String title,
      required String category,
      required String price,
      required VoidCallback onTap,
    }) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 112,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? selectedGreen : Colors.black.withOpacity(0.08),
              width: selected ? 2.4 : 1,
            ),
            color: selected ? selectedGreen.withOpacity(0.08) : Colors.white,
            boxShadow: selected
                ? [BoxShadow(color: selectedGreen.withOpacity(0.18), blurRadius: 14, offset: const Offset(0, 6))]
                : null,
          ),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    color: const Color(0xFFF6F2EA),
                    child: imageUrl.trim().isNotEmpty
                        ? ReliableNetworkImage(
                            imageUrl: _withCacheBust(
                              imageUrl,
                              'option_${product.id}_${title.hashCode}',
                            ),
                            fit: BoxFit.contain,
                            width: double.infinity,
                            fallback: const _SmallImageFallback(),
                          )
                        : const _SmallImageFallback(),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              FitOneLineText(
                title,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
              ),
              if (category.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                FitOneLineText(
                  category,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: ProductDetailsScreen.darkColor.withOpacity(0.55),
                  ),
                ),
              ],
              const SizedBox(height: 2),
              FitOneLineText(
                price,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: ProductDetailsScreen.goldColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: AppController.isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            tr('اختر النوع / المواصفة', 'Choose option / specification'),
            style: const TextStyle(color: ProductDetailsScreen.darkColor, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Directionality(
            textDirection: AppController.direction,
            child: SizedBox(
              height: 124,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: product.variants.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return optionTile(
                      selected: _selectedVariant == null,
                      imageUrl: _firstBaseImage(product),
                      title: product.baseName(AppController.isArabic),
                      category: tr('المنتج الأساسي', 'Original product'),
                      price: AppController.formatSelectedPrice(
                        usd: product.priceUsd,
                        aed: product.priceAed,
                        sdg: product.priceSdg,
                      ),
                      onTap: _selectOriginalProduct,
                    );
                  }

                  final variant = product.variants[index - 1];
                  final optionProduct = product.copyWithSelectedVariant(variant);

                  return optionTile(
                    selected: _selectedVariant?.id == variant.id,
                    imageUrl: _optionThumbnailUrl(variant),
                    title: variant.name(AppController.isArabic),
                    category: variant.category(AppController.isArabic),
                    price: AppController.formatSelectedPrice(
                      usd: optionProduct.priceUsd,
                      aed: optionProduct.priceAed,
                      sdg: optionProduct.priceSdg,
                    ),
                    onTap: () => _selectVariant(product, variant),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppController.language,
      builder: (context, lang, child) {
        return ValueListenableBuilder<String>(
          valueListenable: AppController.currency,
          builder: (context, selectedCurrency, child) {
            return FutureBuilder<Product>(
              future: _futureProduct,
              builder: (context, snapshot) {
                final product = snapshot.data ?? widget.product;
                final selectedProduct = _selectedProduct(product);
                final name = selectedProduct.name(AppController.isArabic);
                final description = selectedProduct.description(AppController.isArabic);

                return Directionality(
                  textDirection: AppController.direction,
                  child: Scaffold(
                    backgroundColor: ProductDetailsScreen.bgColor,
                    appBar: AppBar(
                      backgroundColor: Colors.white,
                      surfaceTintColor: Colors.white,
                      elevation: 0,
                      centerTitle: true,
                      title: FitOneLineText(
                        tr('تفاصيل المنتج', 'Product Details'),
                        style: const TextStyle(
                          color: ProductDetailsScreen.darkColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      actions: [
                        CartIconButton(onTap: _openCart, iconColor: ProductDetailsScreen.darkColor),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Center(child: CurrencySelectorButton(compact: true)),
                        ),
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
                                  _imageViewer(product),
                                  _variantsBar(product),
                                  const SizedBox(height: 18),
                                  Container(
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
                                    child: Column(
                                      crossAxisAlignment: AppController.isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: AppController.isArabic ? TextAlign.right : TextAlign.left,
                                          style: const TextStyle(
                                            color: ProductDetailsScreen.darkColor,
                                            fontSize: 22,
                                            height: 1.25,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        if (selectedProduct.hasSelectedVariant) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            '${tr('المواصفة المختارة', 'Selected specification')}: ${selectedProduct.selectedVariantName(AppController.isArabic)}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            softWrap: false,
                                            textAlign: AppController.isArabic ? TextAlign.right : TextAlign.left,
                                            style: const TextStyle(
                                              color: ProductDetailsScreen.goldColor,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          if (selectedProduct.selectedVariantCategory(AppController.isArabic).trim().isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              '${tr('التصنيف', 'Category')}: ${selectedProduct.selectedVariantCategory(AppController.isArabic)}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              softWrap: false,
                                              textAlign: AppController.isArabic ? TextAlign.right : TextAlign.left,
                                              style: TextStyle(
                                                color: ProductDetailsScreen.darkColor.withOpacity(0.62),
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        ],
                                        const SizedBox(height: 14),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: AppController.isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    tr('سعر الوحدة', 'Unit price'),
                                                    style: TextStyle(color: ProductDetailsScreen.darkColor.withOpacity(0.55), fontWeight: FontWeight.w700),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  if (selectedProduct.hasActiveDiscount) ...[
                                                    Text(
                                                      _originalUnitPrice(product),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      textAlign: AppController.isArabic ? TextAlign.right : TextAlign.left,
                                                      style: TextStyle(
                                                        color: ProductDetailsScreen.darkColor.withOpacity(0.48),
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w800,
                                                        decoration: TextDecoration.lineThrough,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                  ],
                                                  FitOneLineText(
                                                    _unitPrice(product),
                                                    alignment: AppController.isArabic ? Alignment.centerRight : Alignment.centerLeft,
                                                    style: const TextStyle(
                                                      color: ProductDetailsScreen.darkColor,
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w900,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            QuantitySelector(quantity: _quantity, onMinus: _decrease, onPlus: _increase),
                                          ],
                                        ),
                                        const SizedBox(height: 14),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                          decoration: BoxDecoration(
                                            color: ProductDetailsScreen.goldColor.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(18),
                                          ),
                                          child: FitOneLineText(
                                            '${tr('الإجمالي', 'Total')}: ${_totalPrice(product)}',
                                            alignment: AppController.isArabic ? Alignment.centerRight : Alignment.centerLeft,
                                            style: const TextStyle(
                                              color: ProductDetailsScreen.darkColor,
                                              fontSize: 17,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 18),
                                        Text(
                                          description.trim().isNotEmpty
                                              ? description
                                              : tr('لا يوجد وصف متاح لهذا المنتج حالياً.', 'No description is available for this product.'),
                                          textAlign: AppController.isArabic ? TextAlign.right : TextAlign.left,
                                          style: TextStyle(
                                            color: ProductDetailsScreen.darkColor.withOpacity(0.68),
                                            height: 1.6,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: _busy ? null : () => _addToCart(product),
                                          icon: _busy
                                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                              : const Icon(Icons.add_shopping_cart_rounded),
                                          label: FitOneLineText(tr('إضافة إلى السلة', 'Add to cart')),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: _busy ? null : () => _buyNow(product),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: ProductDetailsScreen.goldColor,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                          ),
                                          icon: const Icon(Icons.payment_rounded),
                                          label: FitOneLineText(tr('إكمال الطلب', 'Checkout')),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (snapshot.connectionState == ConnectionState.waiting) ...[
                                    const SizedBox(height: 12),
                                    const LinearProgressIndicator(color: ProductDetailsScreen.goldColor),
                                  ],
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
      },
    );
  }
}

class _ImageArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ImageArrowButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.34),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

class _FallbackProductImage extends StatelessWidget {
  const _FallbackProductImage();

  @override
  Widget build(BuildContext context) {
    // Intentionally blank: a missing image must stay visibly empty.
    return const SizedBox.expand();
  }
}

class _SmallImageFallback extends StatelessWidget {
  const _SmallImageFallback();

  @override
  Widget build(BuildContext context) {
    // Intentionally blank: do not replace an absent option image with an icon
    // or with the original product image.
    return const SizedBox.expand();
  }
}
