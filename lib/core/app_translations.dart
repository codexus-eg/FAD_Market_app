class AppTranslations {
  static const Map<String, Map<String, String>> _data = {
    'ar': {
      'home': 'الرئيسية',
      'welcome': 'مرحبًا بكم',
      'subtitle': 'ماكينات، قطع غيار، منتجات، تصاميم وخدمات صيانة',
      'search_hint': 'ابحث عن ماكينة، قطعة غيار أو تصميم...',
      'main_sections': 'الأقسام الرئيسية',
      'products': 'منتجات',
      'maintenance': 'طلب صيانة',
      'offers': 'العروض',
      'support': 'الدعم',
      'loading': 'جارٍ التحميل...',
      'retry': 'إعادة المحاولة',
      'no_data': 'لا توجد بيانات حالياً',
      'language': 'English',
      'connection_error': 'تعذر الاتصال بالخادم',
      'dashboard_connected': 'متصل بلوحة التحكم',
    },
    'en': {
      'home': 'Home',
      'welcome': 'Welcome',
      'subtitle':
          'Machines, spare parts, CNC products, designs and maintenance',
      'search_hint': 'Search for machine, spare part or design...',
      'main_sections': 'Main Sections',
      'products': 'Products',
      'maintenance': 'Maintenance Request',
      'offers': 'Offers',
      'support': 'Support',
      'loading': 'Loading...',
      'retry': 'Retry',
      'no_data': 'No data available',
      'language': 'العربية',
      'connection_error': 'Could not connect to server',
      'dashboard_connected': 'Connected to dashboard',
    },
  };

  static String text(String key, String lang) {
    return _data[lang]?[key] ?? _data['en']?[key] ?? key;
  }
}
