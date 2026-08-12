class Customer {
  final int id;
  final String fullName;
  final String whatsappPhone;
  final String callPhone;
  final String country;
  final String stateCity;
  final String address;
  final String mapUrl;
  final double? locationLat;
  final double? locationLng;
  final String authToken;

  Customer({
    required this.id,
    required this.fullName,
    required this.whatsappPhone,
    required this.callPhone,
    required this.country,
    required this.stateCity,
    required this.address,
    this.mapUrl = '',
    this.locationLat,
    this.locationLng,
    required this.authToken,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic value) {
      final text = '${value ?? ''}'.trim();
      if (text.isEmpty) return null;
      return double.tryParse(text);
    }

    return Customer(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      fullName: '${json['full_name'] ?? ''}',
      whatsappPhone: '${json['whatsapp_phone'] ?? ''}',
      callPhone: '${json['call_phone'] ?? ''}',
      country: '${json['country'] ?? ''}',
      stateCity: '${json['state_city'] ?? ''}',
      address: '${json['address'] ?? ''}',
      mapUrl: '${json['map_url'] ?? json['customer_map_url'] ?? ''}',
      locationLat: parseDouble(json['location_lat'] ?? json['customer_location_lat']),
      locationLng: parseDouble(json['location_lng'] ?? json['customer_location_lng']),
      authToken: '${json['auth_token'] ?? json['token'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'whatsapp_phone': whatsappPhone,
      'call_phone': callPhone,
      'country': country,
      'state_city': stateCity,
      'address': address,
      'map_url': mapUrl,
      'location_lat': locationLat,
      'location_lng': locationLng,
      'auth_token': authToken,
    };
  }
}
