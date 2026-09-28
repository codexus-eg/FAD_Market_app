import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../models/customer.dart';
import 'maintenance_screen.dart';
import 'leader_task_distribution_screen.dart';
import 'employee_notifications_screen.dart';
import '../services/employee_session.dart';
import '../services/employee_api_service.dart';
import '../models/service_employee.dart';
import '../models/product.dart';
import '../models/product_type.dart';
import '../services/api_service.dart';
import '../services/cart_service.dart';
import '../services/customer_session.dart';
import '../services/ai_assistant_service.dart';
import '../widgets/cart_icon_button.dart';
import '../widgets/currency_selector_button.dart';
import '../widgets/fit_one_line_text.dart';
import '../widgets/product_card.dart';
import '../widgets/product_type_card.dart';
import 'cart_screen.dart';
import 'customer_chat_screen.dart';
import 'customer_settings_screen.dart';
import 'login_screen.dart';
import 'my_orders_screen.dart';
import 'offers_screen.dart';
import 'product_details_screen.dart';
import 'products_screen.dart';
import 'register_screen.dart';
import 'ai_maintenance_screen.dart';
import '../widgets/ai_floating_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const Color goldColor = Color(0xFFD4A02A);
  static const Color darkColor = Color(0xFF202020);
  static const Color bgColor = Color(0xFFF5F5F5);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<ProductType>> _futureTypes;
  late Future<List<Product>> _futureOffers;
  final TextEditingController _searchController = TextEditingController();
  Future<List<Product>>? _futureSearchProducts;
  String _searchQuery = '';
  Customer? _customer;
  ServiceEmployee? _employee;
  bool _loadingCustomer = true;
  bool _loadingEmployee = true;
  int _employeeTaskCount = 0;
  AiAppConfig _aiConfig = AiAppConfig.defaults();

  @override
  void initState() {
    super.initState();
    _futureTypes = ApiService.getProductTypes();
    _futureOffers = ApiService.getOffers();
    _loadCustomer();
    _loadEmployee();
    _loadAiConfig();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAiConfig() async {
    final config = await AiAssistantService.getAppConfig();
    if (!mounted) return;
    setState(() => _aiConfig = config);
  }

  Future<void> _loadCustomer() async {
    final savedCustomer = await CustomerSession.getCustomer();

    if (savedCustomer == null || savedCustomer.authToken.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _customer = null;
        _loadingCustomer = false;
      });
      return;
    }

    try {
      final deviceId = await CustomerSession.getOrCreateDeviceId();

      final freshCustomer = await ApiService.getCurrentCustomer(
        authToken: savedCustomer.authToken,
        deviceId: deviceId,
      );

      final customerToSave = freshCustomer.authToken.trim().isEmpty
          ? Customer(
              id: freshCustomer.id,
              fullName: freshCustomer.fullName,
              whatsappPhone: freshCustomer.whatsappPhone,
              callPhone: freshCustomer.callPhone,
              country: freshCustomer.country,
              stateCity: freshCustomer.stateCity,
              address: freshCustomer.address,
              mapUrl: freshCustomer.mapUrl,
              locationLat: freshCustomer.locationLat,
              locationLng: freshCustomer.locationLng,
              authToken: savedCustomer.authToken,
            )
          : freshCustomer;

      await CustomerSession.saveCustomer(customerToSave);

      if (!mounted) return;
      setState(() {
        _customer = customerToSave;
        _loadingCustomer = false;
      });
    } catch (e) {
      await CustomerSession.clearCustomer();

      if (!mounted) return;
      setState(() {
        _customer = null;
        _loadingCustomer = false;
      });
    }
  }


  Future<void> _loadEmployee() async {
    final savedEmployee = await EmployeeSession.getEmployee();

    if (savedEmployee == null || savedEmployee.authToken.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _employee = null;
        _loadingEmployee = false;
      });
      return;
    }

    try {
      final deviceId = await CustomerSession.getOrCreateDeviceId();

      final freshEmployee = await EmployeeApiService.employeeMe(
        authToken: savedEmployee.authToken,
        deviceId: deviceId,
      );

      await EmployeeSession.saveEmployee(freshEmployee);

      if (!mounted) return;
      int taskCount = 0;
      try {
        final data = await EmployeeApiService.getEmployeeNotifications(
          authToken: freshEmployee.authToken,
          deviceId: deviceId,
        );
        taskCount = int.tryParse('${data['unread_count'] ?? 0}') ?? 0;
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _employee = freshEmployee;
        _employeeTaskCount = taskCount;
        _loadingEmployee = false;
      });
    } catch (e) {
      await EmployeeSession.clearEmployee();

      if (!mounted) return;
      setState(() {
        _employee = null;
        _employeeTaskCount = 0;
        _loadingEmployee = false;
      });
    }
  }

  Future<void> _employeeLogout() async {
    await EmployeeSession.clearEmployee();
    if (!mounted) return;
    setState(() {
      _employee = null;
      _employeeTaskCount = 0;
      _loadingEmployee = false;
    });
  }

  void _openEmployeeNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const EmployeeNotificationsScreen(),
      ),
    ).then((_) {
      _loadEmployee();
    });
  }

  void _openLeaderDistribution() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LeaderTaskDistributionScreen(),
      ),
    );
  }

  void _reloadTypes() {
    setState(() {
      _futureTypes = ApiService.getProductTypes();
      _futureOffers = ApiService.getOffers();
      if (_searchQuery.trim().isNotEmpty) {
        _futureSearchProducts = _loadSearchProducts();
      }
    });
  }

  Future<void> _openLogin() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );

    if (result == true) {
      await _loadCustomer();
      await _loadEmployee();
    }
  }

  Future<void> _openRegister() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RegisterScreen(),
      ),
    );

    if (result == true) {
      await _loadCustomer();
    }
  }

  Future<void> _logout() async {
    await CustomerSession.clearCustomer();
    await _loadCustomer();
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

  void _openMyOrders() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MyOrdersScreen(),
      ),
    );
  }

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CustomerChatScreen(),
      ),
    );
  }

  Future<void> _openAiAssistant() async {
    final latestConfig = await AiAssistantService.getAppConfig();
    if (!mounted) return;
    setState(() => _aiConfig = latestConfig);

    if (!latestConfig.enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('المساعد الذكي غير متاح حالياً.', 'AI assistant is currently unavailable.'))),
      );
      return;
    }

    final loggedIn = await CustomerSession.isLoggedIn();
    if (!mounted) return;
    if (!loggedIn) {
      final action = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return Directionality(
            textDirection: AppController.direction,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: const [
                    BoxShadow(color: Color(0x33000000), blurRadius: 26, offset: Offset(0, 10)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF07192D),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/ai_assistant/fce_ai_frame_1.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      tr('أنشئ حساب أولاً', 'Create an account first'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: HomeScreen.darkColor),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr(
                        'مساعد FCE الذكي متاح للمستخدمين المسجلين فقط. أنشئ حساباً أو سجل الدخول للبدء.',
                        'FCE AI Assistant is available to registered users only. Create an account or sign in to continue.',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: HomeScreen.darkColor.withOpacity(.68), height: 1.45),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(sheetContext, 'register'),
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: Text(tr('إنشاء حساب', 'Create account')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: HomeScreen.goldColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(sheetContext, 'login'),
                        icon: const Icon(Icons.login_rounded),
                        label: Text(tr('تسجيل الدخول', 'Sign in')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: HomeScreen.darkColor,
                          side: const BorderSide(color: HomeScreen.darkColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
      if (!mounted) return;
      if (action == 'register') {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
        await _loadCustomer();
      } else if (action == 'login') {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
        await _loadCustomer();
      }
      if (!mounted) return;
      final nowLoggedIn = await CustomerSession.isLoggedIn();
      if (!mounted) return;
      if (nowLoggedIn) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AiMaintenanceScreen(appConfig: latestConfig)),
        );
      }
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiMaintenanceScreen(appConfig: latestConfig),
      ),
    );
  }

  Future<void> _openCustomerSettings() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CustomerSettingsScreen(),
      ),
    );

    if (result == true) {
      await _loadCustomer();
    }
  }

  void _openProducts(ProductType type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductsScreen(type: type),
      ),
    );
  }

  void _handleSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      if (_searchQuery.trim().isNotEmpty) {
        _futureSearchProducts ??= _loadSearchProducts();
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
  }

  Future<List<Product>> _loadSearchProducts() async {
    final types = await ApiService.getProductTypes();
    final lists = await Future.wait(
      types.map((type) async {
        try {
          return await ApiService.getProductsByType(typeCode: type.code);
        } catch (_) {
          return <Product>[];
        }
      }),
    );

    final byId = <int, Product>{};
    for (final list in lists) {
      for (final product in list) {
        if (product.id > 0) byId[product.id] = product;
      }
    }

    return byId.values.toList();
  }

  bool _matchesSearch(Product product, String query) {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return false;

    final words = cleanQuery
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .toList();

    final haystack = [
      product.nameAr,
      product.nameEn,
      product.descriptionAr,
      product.descriptionEn,
      product.productType,
      for (final variant in product.variants) ...[
        variant.nameAr,
        variant.nameEn,
        variant.categoryAr,
        variant.categoryEn,
        variant.descriptionAr,
        variant.descriptionEn,
      ],
    ].join(' ').toLowerCase();

    return words.every(haystack.contains);
  }

  void _openProductDetails(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailsScreen(product: product),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _addProductToCart(Product product) async {
    await CartService.addProduct(product, 1);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('تمت الإضافة إلى السلة', 'Added to cart')),
      ),
    );
  }

  int _productGridCount(double width) {
    if (width >= 1100) return 4;
    if (width >= 760) return 3;
    return 2;
  }

  double _productGridRatio(double width) {
    if (width <= 340) return 0.74;
    if (width <= 390) return 0.78;
    if (width >= 760) return 0.84;
    return 0.82;
  }

  Widget _buildSearchResultsSliver(double pageWidth) {
    final query = _searchQuery.trim();

    return FutureBuilder<List<Product>>(
      future: _futureSearchProducts,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(
                      color: HomeScreen.goldColor,
                    ),
                    const SizedBox(height: 12),
                    Text(AppController.t('loading')),
                  ],
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: _ErrorBox(onRetry: _reloadTypes),
            ),
          );
        }

        final products = (snapshot.data ?? const <Product>[])
            .where((product) => _matchesSearch(product, query))
            .toList();

        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
            child: Column(
              crossAxisAlignment: AppController.isArabic
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr('نتائج البحث', 'Search Results'),
                        textAlign: AppController.isArabic ? TextAlign.right : TextAlign.left,
                        style: const TextStyle(
                          color: HomeScreen.darkColor,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      '${products.length}',
                      style: TextStyle(
                        color: HomeScreen.darkColor.withOpacity(0.45),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (products.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.search_off_rounded,
                          color: HomeScreen.goldColor,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          tr('لا توجد منتجات مطابقة للبحث', 'No matching products found'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: HomeScreen.darkColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  GridView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _productGridCount(pageWidth),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: _productGridRatio(pageWidth),
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return ProductCard(
                        product: product,
                        onTap: () => _openProductDetails(product),
                        onAddToCart: () => _addProductToCart(product),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String tr(String ar, String en) {
    return AppController.isArabic ? ar : en;
  }

  int _gridCount(double width) {
    return 2;
  }

  double _gridRatio(double width) {
    if (width <= 340) return 0.78;
    if (width <= 390) return 0.82;
    if (width >= 760) return 0.92;
    return 0.86;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppController.language,
      builder: (context, lang, child) {
        return Directionality(
          textDirection: AppController.direction,
          child: Scaffold(
            backgroundColor: HomeScreen.bgColor,
            floatingActionButton: _aiConfig.enabled
                ? AiFloatingButton(
                    onTap: _openAiAssistant,
                    messages: AppController.isArabic
                        ? _aiConfig.teaserMessagesAr
                        : _aiConfig.teaserMessagesEn,
                    animationCycleMs: _aiConfig.animationCycleMs,
                    teaserIntervalMs: _aiConfig.teaserIntervalMs,
                  )
                : null,
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final pageWidth = constraints.maxWidth;
                  final maxContentWidth = pageWidth >= 900 ? 880.0 : pageWidth;

                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: maxContentWidth,
                      ),
                      child: RefreshIndicator(
                        color: HomeScreen.goldColor,
                        onRefresh: () async {
                          _reloadTypes();
                          await _futureTypes;
                          await _loadCustomer();
                          await _loadEmployee();
                          await _loadAiConfig();
                        },
                        child: CustomScrollView(
                          slivers: [
                            SliverToBoxAdapter(
                              child: _HeaderSection(
                                customer: _customer,
                                employee: _employee,
                                loadingCustomer: _loadingCustomer,
                                loadingEmployee: _loadingEmployee,
                                employeeTaskCount: _employeeTaskCount,
                                onCartTap: _openCart,
                                onLanguageTap: AppController.toggleLanguage,
                                onLoginTap: _openLogin,
                                onRegisterTap: _openRegister,
                                onLogoutTap: _logout,
                                onOrdersTap: _openMyOrders,
                                onChatTap: _openChat,
                                onSettingsTap: _openCustomerSettings,
                                onEmployeeLogoutTap: _employeeLogout,
                                onEmployeeNotificationsTap: _openEmployeeNotifications,
                                onLeaderDistributionTap: _openLeaderDistribution,
                                ),
                            ),
                            SliverToBoxAdapter(
                              child: FutureBuilder<List<Product>>(
                                future: _futureOffers,
                                builder: (context, offersSnapshot) {
                                  return _TopActions(
                                    hasOffers: (offersSnapshot.data ?? const <Product>[]).isNotEmpty,
                                    onOffersTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const OffersScreen()),
                                      ).then((_) => _reloadTypes());
                                    },
                                    onMaintenanceTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const MaintenanceScreen(),
                                        ),
                                      ).then((_) {
                                        _loadCustomer();
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: _SearchBox(
                                controller: _searchController,
                                hasText: _searchQuery.trim().isNotEmpty,
                                onChanged: _handleSearchChanged,
                                onClear: _clearSearch,
                              ),
                            ),
                            if (_searchQuery.trim().isNotEmpty)
                              _buildSearchResultsSliver(pageWidth)
                            else ...[
                              SliverToBoxAdapter(
                                child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  24,
                                  18,
                                  12,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        AppController.t('main_sections'),
                                        style: const TextStyle(
                                          color: HomeScreen.darkColor,
                                          fontSize: 21,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      AppController.t('dashboard_connected'),
                                      style: TextStyle(
                                        color: HomeScreen.darkColor
                                            .withOpacity(0.45),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            FutureBuilder<List<ProductType>>(
                              future: _futureTypes,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return SliverToBoxAdapter(
                                    child: Padding(
                                      padding: const EdgeInsets.all(30),
                                      child: Center(
                                        child: Column(
                                          children: [
                                            const CircularProgressIndicator(
                                              color: HomeScreen.goldColor,
                                            ),
                                            const SizedBox(height: 12),
                                            Text(AppController.t('loading')),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }

                                if (snapshot.hasError) {
                                  return SliverToBoxAdapter(
                                    child: Padding(
                                      padding: const EdgeInsets.all(18),
                                      child: _ErrorBox(onRetry: _reloadTypes),
                                    ),
                                  );
                                }

                                final types = snapshot.data ?? [];

                                if (types.isEmpty) {
                                  return SliverToBoxAdapter(
                                    child: Padding(
                                      padding: const EdgeInsets.all(18),
                                      child: Center(
                                        child: Text(AppController.t('no_data')),
                                      ),
                                    ),
                                  );
                                }

                                return SliverPadding(
                                  padding: const EdgeInsets.fromLTRB(
                                    18,
                                    4,
                                    18,
                                    28,
                                  ),
                                  sliver: SliverGrid(
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: _gridCount(pageWidth),
                                      mainAxisSpacing: 16,
                                      crossAxisSpacing: 16,
                                      childAspectRatio: _gridRatio(pageWidth),
                                    ),
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        final type = types[index];

                                        return ProductTypeCard(
                                          type: type,
                                          index: index,
                                          onTap: () {
                                            _openProducts(type);
                                          },
                                        );
                                      },
                                      childCount: types.length,
                                    ),
                                  ),
                                );
                              },
                            ),
                            ],
                          ],
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
  }

  void _showLoginRequired() {
    showModalBottomSheet(
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
                  color: HomeScreen.goldColor,
                  size: 42,
                ),
                const SizedBox(height: 12),
                Text(
                  tr(
                    'يجب تسجيل حساب أولاً لإكمال الطلب',
                    'Please login first to continue',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: HomeScreen.darkColor,
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
                          Navigator.pop(context);
                          _openLogin();
                        },
                        child: Text(tr('تسجيل الدخول', 'Login')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _openRegister();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: HomeScreen.goldColor,
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
  }
}

class _HeaderSection extends StatelessWidget {
  final Customer? customer;
  final ServiceEmployee? employee;
  final bool loadingCustomer;
  final bool loadingEmployee;
  final int employeeTaskCount;
  final VoidCallback onCartTap;
  final VoidCallback onLanguageTap;
  final VoidCallback onLoginTap;
  final VoidCallback onRegisterTap;
  final VoidCallback onLogoutTap;
  final VoidCallback onOrdersTap;
  final VoidCallback onChatTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onEmployeeLogoutTap;
  final VoidCallback onEmployeeNotificationsTap;
  final VoidCallback onLeaderDistributionTap;

  const _HeaderSection({
    required this.customer,
    required this.employee,
    required this.loadingCustomer,
    required this.loadingEmployee,
    required this.employeeTaskCount,
    required this.onCartTap,
    required this.onLanguageTap,
    required this.onLoginTap,
    required this.onRegisterTap,
    required this.onLogoutTap,
    required this.onOrdersTap,
    required this.onChatTap,
    required this.onSettingsTap,
    required this.onEmployeeLogoutTap,
    required this.onEmployeeNotificationsTap,
    required this.onLeaderDistributionTap,
  });

  String tr(String ar, String en) {
    return AppController.isArabic ? ar : en;
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = customer != null || employee != null;
    final activeName = employee?.fullName ?? customer?.fullName ?? '';

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF202020),
            Color(0xFF3A3A3A),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.16),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AppController.isArabic
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(19),
                    ),
                    child: Image.asset(
                      'assets/images/fce_logo.jpeg',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'FAD Market',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 14),
                  if (employee != null) ...[
                    _EmployeeBellButton(
                      count: employeeTaskCount,
                      onTap: onEmployeeNotificationsTap,
                    ),
                    const SizedBox(width: 5),
                  ],
                  CartIconButton(
                    onTap: onCartTap,
                  ),
                  const SizedBox(width: 5),
                  const CurrencySelectorButton(compact: true),
                  const SizedBox(width: 7),
                  _SmallHeaderButton(
                    title: AppController.t('language'),
                    onTap: onLanguageTap,
                    filled: false,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),
          if (loadingCustomer)
            const SizedBox(
              height: 3,
              child: LinearProgressIndicator(
                color: HomeScreen.goldColor,
                backgroundColor: Colors.white24,
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: Align(
                alignment: AppController.isArabic
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AppController.isArabic
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isLoggedIn) ...[
                        _SmallHeaderButton(
                          title: tr('تسجيل الدخول', 'Login'),
                          onTap: onLoginTap,
                          filled: true,
                        ),
                        const SizedBox(width: 8),
                        _SmallHeaderButton(
                          title: tr('إنشاء حساب', 'Create Account'),
                          onTap: onRegisterTap,
                          filled: false,
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 190),
                            child: FitOneLineText(
                              tr(
                                'أهلاً بك، $activeName',
                                'Hi, $activeName',
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (customer != null) ...[
                          _SmallHeaderButton(
                            title: tr('طلباتي', 'My Orders'),
                            onTap: onOrdersTap,
                            filled: true,
                          ),
                          const SizedBox(width: 8),
                          _SmallHeaderButton(
                            title: tr('الشات', 'Chat'),
                            onTap: onChatTap,
                            filled: false,
                          ),
                          const SizedBox(width: 8),
                          _SmallHeaderButton(
                            title: tr('الإعدادات', 'Settings'),
                            onTap: onSettingsTap,
                            filled: false,
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (employee != null && employee!.isLeader) ...[
                          _SmallHeaderButton(
                            title: tr('توزيع المهام', 'Distribute'),
                            onTap: onLeaderDistributionTap,
                            filled: true,
                          ),
                          const SizedBox(width: 8),
                        ],
                        _SmallHeaderButton(
                          title: tr('تسجيل الخروج', 'Logout'),
                          onTap: employee != null ? onEmployeeLogoutTap : onLogoutTap,
                          filled: false,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
          Align(
            alignment: AppController.isArabic
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: SizedBox(
              width: double.infinity,
              child: FitOneLineText(
                AppController.t('welcome'),
                alignment: AppController.isArabic
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                textAlign: AppController.isArabic ? TextAlign.right : TextAlign.left,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AppController.isArabic
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: Text(
              AppController.t('subtitle'),
              style: TextStyle(
                color: Colors.white.withOpacity(0.72),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _EmployeeBellButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _EmployeeBellButton({
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: const SizedBox(
              width: 42,
              height: 38,
              child: Icon(
                Icons.notifications_active_rounded,
                color: HomeScreen.goldColor,
                size: 21,
              ),
            ),
          ),
        ),
        if (count > 0)
          Positioned(
            top: -5,
            right: -5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SmallHeaderButton extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final bool filled;

  const _SmallHeaderButton({
    required this.title,
    required this.onTap,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? HomeScreen.goldColor : Colors.white.withOpacity(0.12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 8,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 105),
            child: FitOneLineText(
              title,
              style: TextStyle(
                color: filled ? Colors.white : HomeScreen.goldColor,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopActions extends StatelessWidget {
  final VoidCallback onOffersTap;
  final VoidCallback onMaintenanceTap;
  final bool hasOffers;

  const _TopActions({
    required this.onOffersTap,
    required this.onMaintenanceTap,
    required this.hasOffers,
  });

  String tr(String ar, String en) {
    return AppController.isArabic ? ar : en;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      child: Row(
        children: [
          Expanded(
            child: _ActionCard(
              title: tr('العروض', 'Offers'),
              subtitle: tr('أحدث الأسعار والخصومات', 'Latest deals'),
              icon: Icons.local_offer_outlined,
              showHotBadge: hasOffers,
              onTap: onOffersTap,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ActionCard(
              title: tr('طلب صيانة', 'Maintenance'),
              subtitle: tr('أرسل طلب صيانة الآن', 'Request service now'),
              icon: Icons.build_circle_outlined,
              onTap: onMaintenanceTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool showHotBadge;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.showHotBadge = false,
  });

  String tr(String ar, String en) {
    return AppController.isArabic ? ar : en;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 94,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.black.withOpacity(0.04)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: HomeScreen.goldColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(icon, color: HomeScreen.goldColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: AppController.isArabic
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          FitOneLineText(
                            title,
                            alignment: AppController.isArabic
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            textAlign: AppController.isArabic ? TextAlign.right : TextAlign.left,
                            style: const TextStyle(
                              color: HomeScreen.darkColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          FitOneLineText(
                            subtitle,
                            alignment: AppController.isArabic
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            textAlign: AppController.isArabic ? TextAlign.right : TextAlign.left,
                            style: TextStyle(
                              color: HomeScreen.darkColor.withOpacity(0.50),
                              fontWeight: FontWeight.w600,
                              fontSize: 11.5,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (showHotBadge)
                  Positioned(
                    top: -6,
                    right: AppController.isArabic ? null : -4,
                    left: AppController.isArabic ? -4 : null,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.88, end: 1.0),
                      duration: const Duration(milliseconds: 650),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              tr('استفد من العروض', 'Hot offers'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        );
                      },
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

class _SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool hasText;

  const _SearchBox({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.hasText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: AppController.t('search_hint'),
          prefixIcon: const Icon(Icons.search),
          suffixIcon: hasText
              ? IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 17,
          ),
        ),
      ),
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
