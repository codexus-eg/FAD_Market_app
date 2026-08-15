import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/cart_item.dart';
import '../models/customer.dart';
import '../models/product.dart';
import '../models/product_type.dart';
import '../models/payment_method.dart';

class ApiService {
  static const String baseUrl = 'https://365hub.site/fce-dashboard/api';

  static Future<List<ProductType>> getProductTypes() async {
    final cacheBust = DateTime.now().millisecondsSinceEpoch;

    final uri = Uri.parse('$baseUrl/product_types.php?v=$cacheBust');

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Server error: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);

    if (decoded['success'] != true) {
      throw Exception(decoded['message'] ?? 'API error');
    }

    final List data = decoded['data'] ?? [];

    return data.map((item) {
      return ProductType.fromJson(Map<String, dynamic>.from(item));
    }).toList();
  }

  static Future<List<Product>> getProductsByType({
    required String typeCode,
  }) async {
    final cacheBust = DateTime.now().millisecondsSinceEpoch;

    final uri = Uri.parse(
      '$baseUrl/products_by_type.php?type=${Uri.encodeComponent(typeCode)}&v=$cacheBust',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Server error: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);

    if (decoded['success'] != true) {
      throw Exception(decoded['message'] ?? 'API error');
    }

    final List data = decoded['data'] ?? [];

    return data.map((item) {
      return Product.fromJson(Map<String, dynamic>.from(item));
    }).toList();
  }




  static Future<List<Product>> getOffers() async {
    final cacheBust = DateTime.now().millisecondsSinceEpoch;
    final uri = Uri.parse('$baseUrl/offers.php?v=$cacheBust');

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Server error: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);

    if (decoded['success'] != true) {
      throw Exception(decoded['message'] ?? 'API error');
    }

    final List data = decoded['data'] ?? [];

    return data.map((item) {
      return Product.fromJson(Map<String, dynamic>.from(item));
    }).toList();
  }

  static Future<Product> getProductDetails({
    required int productId,
    int? variantId,
  }) async {
    final cacheBust = DateTime.now().millisecondsSinceEpoch;
    final query = <String, String>{
      'id': '$productId',
      'v': '$cacheBust',
    };
    if (variantId != null && variantId > 0) {
      query['variant_id'] = '$variantId';
    }

    final uri = Uri.parse('$baseUrl/product_details.php').replace(queryParameters: query);

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Server error: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);

    if (decoded['success'] != true) {
      throw Exception(decoded['message'] ?? 'API error');
    }

    final rawData = decoded['data'] ?? decoded['product'] ?? {};
    final Map<String, dynamic> data = rawData is Map
        ? Map<String, dynamic>.from(rawData)
        : <String, dynamic>{};

    // Support both response shapes:
    // {success:true, data:{...product..., images:[], variants:[]}}
    // {success:true, product:{...}, images:[], variants:[]}
    if (data.containsKey('product') && data['product'] is Map) {
      final productData = Map<String, dynamic>.from(data['product']);
      if (data['images'] != null) productData['images'] = data['images'];
      if (data['variants'] != null) productData['variants'] = data['variants'];
      return Product.fromJson(productData);
    }

    if (decoded['images'] != null && data['images'] == null) {
      data['images'] = decoded['images'];
    }
    if (decoded['variants'] != null && data['variants'] == null) {
      data['variants'] = decoded['variants'];
    }

    return Product.fromJson(data);
  }

  static Future<List<PaymentMethodConfig>> getPaymentMethods() async {
    final cacheBust = DateTime.now().millisecondsSinceEpoch;
    final uri = Uri.parse('$baseUrl/payment_methods.php?v=$cacheBust');

    try {
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        return const <PaymentMethodConfig>[];
      }

      final decoded = jsonDecode(response.body);

      if (decoded['success'] != true) {
        return const <PaymentMethodConfig>[];
      }

      final List data = decoded['data'] ?? decoded['methods'] ?? [];

      final methods = data
          .map((item) => PaymentMethodConfig.fromJson(Map<String, dynamic>.from(item)))
          .where((method) => method.enabled && method.code.isNotEmpty)
          .toList();

      return methods;
    } catch (_) {
      return const <PaymentMethodConfig>[];
    }
  }

  static Future<Map<String, dynamic>> startPayment({
    required String authToken,
    required String deviceId,
    required String paymentMethod,
    required String orderId,
    required String orderNumber,
    required double amount,
    required String currency,
  }) async {
    final uri = Uri.parse('$baseUrl/payment_start.php');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode({
        'auth_token': authToken,
        'device_id': deviceId,
        'payment_method': paymentMethod,
        'order_id': orderId,
        'order_number': orderNumber,
        'amount': amount,
        'currency': currency,
      }),
    );

    final decoded = jsonDecode(response.body);

    if (decoded['success'] != true) {
      throw Exception(decoded['message'] ?? 'Payment failed');
    }

    return Map<String, dynamic>.from(decoded);
  }


  static Future<Map<String, dynamic>> createOrder({
    required String authToken,
    required String deviceId,
    required String paymentMethod,
    required String notes,
    required List<CartItem> items,
    String paymentReference = '',
    String currency = '',
  }) async {
    final uri = Uri.parse('$baseUrl/create_order.php');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode({
        'auth_token': authToken,
        'device_id': deviceId,
        'payment_method': paymentMethod,
        'payment_reference': paymentReference,
        'currency': currency,
        'notes': notes,
        'items': items.map((item) {
          return {
            'product_id': item.product.id,
            'variant_id': item.product.selectedVariantId,
            'variant_name_ar': item.product.selectedVariantNameAr,
            'variant_name_en': item.product.selectedVariantNameEn,
            'unit_price_usd': item.product.priceUsd,
            'unit_price_aed': item.product.priceAed,
            'unit_price_sdg': item.product.priceSdg,
            'quantity': item.quantity,
          };
        }).toList(),
      }),
    );

    final decoded = jsonDecode(response.body);

    if (decoded['success'] != true) {
      throw Exception(decoded['message'] ?? 'Order failed');
    }

    return Map<String, dynamic>.from(decoded['order'] ?? {});
  }

  static Future<List<Map<String, dynamic>>> getMyOrders({
    required String authToken,
    required String deviceId,
    required String otpVerificationToken,
  }) async {
    final uri = Uri.parse('$baseUrl/my_orders.php');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode({
        'auth_token': authToken,
        'device_id': deviceId,
        'otp_verification_token': otpVerificationToken,
      }),
    );

    final decoded = jsonDecode(response.body);

    if (decoded['success'] != true) {
      throw Exception(decoded['message'] ?? 'Could not load orders');
    }

    final List data = decoded['data'] ?? [];

    return data.map((item) {
      return Map<String, dynamic>.from(item);
    }).toList();
  }

  static Future<Map<String, dynamic>> requestWhatsAppOtp({
    required String phone,
    required String deviceId,
    required String purpose,
  }) async {
    final uri = Uri.parse('$baseUrl/otp_send.php');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode({
        'phone': phone,
        'device_id': deviceId,
        'purpose': purpose,
      }),
    );

    final decoded = jsonDecode(response.body);

    if (decoded['success'] != true) {
      throw Exception(decoded['message'] ?? 'OTP failed');
    }

    return Map<String, dynamic>.from(decoded);
  }

  static Future<Map<String, dynamic>> verifyWhatsAppOtp({
    required String phone,
    required String deviceId,
    required String otpToken,
    required String code,
  }) async {
    final uri = Uri.parse('$baseUrl/otp_verify.php');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode({
        'phone': phone,
        'device_id': deviceId,
        'otp_token': otpToken,
        'code': code,
      }),
    );

    final decoded = jsonDecode(response.body);

    if (decoded['success'] != true) {
      throw Exception(decoded['message'] ?? 'OTP verification failed');
    }

    return Map<String, dynamic>.from(decoded);
  }


  static Future<Customer> registerCustomer({
    required String fullName,
    required String whatsappPhone,
    required String callPhone,
    required String country,
    required String stateCity,
    required String address,
    String mapUrl = '',
    double? locationLat,
    double? locationLng,
    required String deviceId,
    required String otpVerificationToken,
  }) async {
    final uri = Uri.parse('$baseUrl/customer_register.php');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode({
        'full_name': fullName,
        'whatsapp_phone': whatsappPhone,
        'call_phone': callPhone,
        'country': country,
        'state_city': stateCity,
        'address': address,
        'map_url': mapUrl,
        'location_lat': locationLat,
        'location_lng': locationLng,
        'device_id': deviceId,
        'otp_verification_token': otpVerificationToken,
      }),
    );

    final decoded = jsonDecode(response.body);

    if (decoded['success'] != true) {
      throw Exception(decoded['message'] ?? 'Registration failed');
    }

    return Customer.fromJson(
      Map<String, dynamic>.from(decoded['customer']),
    );
  }

  static Future<Customer> loginAbdoDirect({
    required String phone,
    required String deviceId,
  }) async {
    final uri = Uri.parse('$baseUrl/customer_abdo_login.php');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode({
        'phone': phone,
        'device_id': deviceId,
      }),
    );

    final decoded = jsonDecode(response.body);

    if (decoded['success'] != true) {
      throw Exception(decoded['message'] ?? 'Login failed');
    }

    return Customer.fromJson(
      Map<String, dynamic>.from(decoded['customer']),
    );
  }


  static Future<Customer> loginGooglePlayReview({
    required String phone,
    required String code,
    required String deviceId,
  }) async {
    final uri = Uri.parse('$baseUrl/customer_review_login.php');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode({
        'phone': phone,
        'code': code,
        'device_id': deviceId,
      }),
    );

    final decoded = jsonDecode(response.body);

    if (decoded['success'] != true) {
      throw Exception(decoded['message'] ?? 'Review login failed');
    }

    return Customer.fromJson(
      Map<String, dynamic>.from(decoded['customer']),
    );
  }


  static Future<Customer> loginCustomer({
    required String phone,
    required String deviceId,
    String otpVerificationToken = '',
  }) async {
    final uri = Uri.parse('$baseUrl/customer_login.php');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode({
        'phone': phone,
        'device_id': deviceId,
        'otp_verification_token': otpVerificationToken,
      }),
    );

    final decoded = jsonDecode(response.body);

    if (decoded['success'] != true) {
      throw Exception(decoded['message'] ?? 'Login failed');
    }

    return Customer.fromJson(
      Map<String, dynamic>.from(decoded['customer']),
    );
  }

  static Future<Customer> updateCustomerProfile({
    required String authToken,
    required String deviceId,
    required String fullName,
    required String whatsappPhone,
    required String callPhone,
    required String country,
    required String stateCity,
    required String address,
    String mapUrl = '',
    double? locationLat,
    double? locationLng,
    String otpVerificationToken = '',
  }) async {
    final uri = Uri.parse('$baseUrl/customer_update.php');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode({
        'auth_token': authToken,
        'device_id': deviceId,
        'full_name': fullName,
        'whatsapp_phone': whatsappPhone,
        'call_phone': callPhone,
        'country': country,
        'state_city': stateCity,
        'address': address,
        'map_url': mapUrl,
        'location_lat': locationLat,
        'location_lng': locationLng,
        'otp_verification_token': otpVerificationToken,
      }),
    );

    final decoded = jsonDecode(response.body);

    if (decoded['success'] != true) {
      throw Exception(decoded['message'] ?? 'Could not update profile');
    }

    return Customer.fromJson(
      Map<String, dynamic>.from(decoded['customer']),
    );
  }


  static Future<void> deleteCustomerAccount({
    required String authToken,
    required String deviceId,
  }) async {
    final uri = Uri.parse('$baseUrl/customer_delete.php');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode({
        'auth_token': authToken,
        'device_id': deviceId,
      }),
    );

    Map<String, dynamic> decoded;
    try {
      final raw = jsonDecode(response.body);
      decoded = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
    } catch (_) {
      throw Exception('Could not delete account');
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['success'] != true) {
      throw Exception(decoded['message'] ?? 'Could not delete account');
    }
  }


  static Future<Customer> getCurrentCustomer({
    required String authToken,
    required String deviceId,
  }) async {
    final uri = Uri.parse('$baseUrl/customer_me.php');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode({
        'auth_token': authToken,
        'device_id': deviceId,
      }),
    );

    final decoded = jsonDecode(response.body);

    if (decoded['success'] != true) {
      throw Exception(decoded['message'] ?? 'Unauthorized');
    }

    return Customer.fromJson(
      Map<String, dynamic>.from(decoded['customer']),
    );
  }


  static Future<List<Map<String, dynamic>>> getCustomerChat({
    required String authToken,
    required String deviceId,
  }) async {
    final uri = Uri.parse('$baseUrl/customer_chat.php');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode({
        'auth_token': authToken,
        'device_id': deviceId,
        'action': 'list',
      }),
    );

    final decoded = jsonDecode(response.body);

    if (decoded['success'] != true) {
      throw Exception(decoded['message'] ?? 'Could not load chat');
    }

    final List data = decoded['messages'] ?? [];
    return data.map((item) => Map<String, dynamic>.from(item)).toList();
  }

  static Future<void> sendCustomerChatMessage({
    required String authToken,
    required String deviceId,
    required String message,
  }) async {
    final uri = Uri.parse('$baseUrl/customer_chat.php');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode({
        'auth_token': authToken,
        'device_id': deviceId,
        'action': 'send',
        'message': message,
      }),
    );

    final decoded = jsonDecode(response.body);

    if (decoded['success'] != true) {
      throw Exception(decoded['message'] ?? 'Could not send message');
    }
  }


  static Future<void> sendCustomerChatAttachment({
    required String authToken,
    required String deviceId,
    required String message,
    required String fileName,
    required Uint8List fileBytes,
  }) async {
    final uri = Uri.parse('$baseUrl/customer_chat.php');

    final request = http.MultipartRequest('POST', uri);
    request.fields['auth_token'] = authToken;
    request.fields['device_id'] = deviceId;
    request.fields['action'] = 'send';
    request.fields['message'] = message;
    request.files.add(
      http.MultipartFile.fromBytes(
        'attachment',
        fileBytes,
        filename: fileName,
      ),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final decoded = jsonDecode(response.body);

    if (decoded['success'] != true) {
      throw Exception(decoded['message'] ?? 'Could not send attachment');
    }
  }

}
