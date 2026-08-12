import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/customer.dart';

class CustomerSession {
  static const String _customerKey = 'fce_customer_data';
  static const String _deviceKey = 'fce_device_id';

  static Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();

    final savedDeviceId = prefs.getString(_deviceKey);

    if (savedDeviceId != null && savedDeviceId.isNotEmpty) {
      return savedDeviceId;
    }

    final random = Random();
    final deviceId =
        'fce_${DateTime.now().millisecondsSinceEpoch}_${random.nextInt(999999)}';

    await prefs.setString(_deviceKey, deviceId);

    return deviceId;
  }

  static Future<void> saveCustomer(Customer customer) async {
    final prefs = await SharedPreferences.getInstance();

    var data = customer.toJson();

    if (customer.authToken.trim().isEmpty) {
      final oldData = prefs.getString(_customerKey);
      if (oldData != null && oldData.isNotEmpty) {
        try {
          final decoded = jsonDecode(oldData);
          final oldToken = '${decoded['auth_token'] ?? decoded['token'] ?? ''}'.trim();
          if (oldToken.isNotEmpty) {
            data = Map<String, dynamic>.from(data)..['auth_token'] = oldToken;
          }
        } catch (_) {}
      }
    }

    await prefs.setString(
      _customerKey,
      jsonEncode(data),
    );
  }

  static Future<Customer?> getCustomer() async {
    final prefs = await SharedPreferences.getInstance();

    final data = prefs.getString(_customerKey);

    if (data == null || data.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(data);
      return Customer.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      await clearCustomer();
      return null;
    }
  }

  static Future<bool> isLoggedIn() async {
    final customer = await getCustomer();

    return customer != null &&
        customer.id > 0 &&
        customer.authToken.trim().isNotEmpty;
  }

  static Future<void> clearCustomer() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_customerKey);
  }
}
