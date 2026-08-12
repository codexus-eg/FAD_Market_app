import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_controller.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  static const Color goldColor = Color(0xFFD4A02A);
  static const Color darkColor = Color(0xFF202020);
  static const Color bgColor = Color(0xFFF5F5F5);

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  bool _loadingLocation = true;
  String _errorMessage = '';
  double? _latitude;
  double? _longitude;
  String _mapUrl = '';
  String _addressText = '';

  String tr(String ar, String en) => AppController.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }


  Future<String> _resolveAddressName(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return '';
      final p = placemarks.first;
      final seen = <String>{};
      final parts = <String>[];
      for (final value in <String?>[
        p.name,
        p.street,
        p.subLocality,
        p.locality,
        p.subAdministrativeArea,
        p.administrativeArea,
        p.country,
      ]) {
        final text = (value ?? '').trim();
        if (text.isEmpty) continue;
        final key = text.toLowerCase();
        if (seen.contains(key)) continue;
        seen.add(key);
        parts.add(text);
      }
      return parts.join('، ');
    } catch (_) {
      return '';
    }
  }

  String _googleMapUrl(double lat, double lng) {
    final latText = lat.toStringAsFixed(7);
    final lngText = lng.toStringAsFixed(7);
    return 'https://www.google.com/maps/search/?api=1&query=$latText,$lngText';
  }

  Future<void> _loadCurrentLocation() async {
    setState(() {
      _loadingLocation = true;
      _errorMessage = '';
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _loadingLocation = false;
          _errorMessage = tr(
            'خدمة الموقع مغلقة. يرجى تفعيل خدمة الموقع من إعدادات الهاتف ثم إعادة المحاولة.',
            'Location service is off. Enable location from phone settings and try again.',
          );
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _loadingLocation = false;
          _errorMessage = tr(
            'لم يتم السماح بالوصول إلى الموقع. يرجى السماح للتطبيق باستخدام الموقع ثم إعادة المحاولة.',
            'Location permission was not allowed. Allow location access and try again.',
          );
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final url = _googleMapUrl(position.latitude, position.longitude);
      final resolvedAddress = await _resolveAddressName(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _mapUrl = url;
        _addressText = resolvedAddress.trim().isNotEmpty ? resolvedAddress.trim() : 'بدون عنوان';
        _loadingLocation = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingLocation = false;
        _errorMessage = tr(
          'تعذر تحديد موقعك الحالي. أعد المحاولة.',
          'Could not get your current location. Please try again.',
        );
      });
    }
  }

  Future<void> _openLocationExternally() async {
    if (_mapUrl.isEmpty) return;
    final uri = Uri.parse(_mapUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _confirmLocation() {
    final lat = _latitude;
    final lng = _longitude;
    if (lat == null || lng == null || _mapUrl.isEmpty) return;

    Navigator.pop(context, {
      'lat': lat,
      'lng': lng,
      'map_url': _mapUrl,
      'address_text': _addressText.trim().isNotEmpty
          ? _addressText.trim()
          : 'بدون عنوان',
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppController.language,
      builder: (context, lang, child) {
        return Directionality(
          textDirection: AppController.direction,
          child: Scaffold(
            backgroundColor: LocationPickerScreen.bgColor,
            appBar: AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 0,
              title: Text(
                tr('اختيار الموقع', 'Select Location'),
                style: const TextStyle(
                  color: LocationPickerScreen.darkColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
              iconTheme: const IconThemeData(color: LocationPickerScreen.darkColor),
            ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Center(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 74,
                          height: 74,
                          decoration: BoxDecoration(
                            color: LocationPickerScreen.goldColor.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(
                            Icons.my_location_rounded,
                            color: LocationPickerScreen.goldColor,
                            size: 34,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          tr('استخدم موقعي الحالي', 'Use My Current Location'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: LocationPickerScreen.darkColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tr(
                            'سيتم حفظ رابط Google Maps لموقعك مع الحساب دون فتح الخريطة داخل التطبيق ودون استخدام مفتاح API.',
                            'A Google Maps link for your location will be saved without opening an in-app map or using an API key.',
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: LocationPickerScreen.darkColor.withOpacity(0.58),
                            fontWeight: FontWeight.w700,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (_loadingLocation)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: CircularProgressIndicator(
                              color: LocationPickerScreen.goldColor,
                            ),
                          )
                        else if (_errorMessage.isNotEmpty) ...[
                          Text(
                            _errorMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton.icon(
                              onPressed: _loadCurrentLocation,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: LocationPickerScreen.goldColor,
                                side: BorderSide(
                                  color: LocationPickerScreen.goldColor.withOpacity(0.65),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: const Icon(Icons.refresh_rounded),
                              label: Text(
                                tr('إعادة المحاولة', 'Try Again'),
                                style: const TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                        ] else ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: LocationPickerScreen.bgColor,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '${tr('العنوان', 'Address')}: ${_addressText.trim().isNotEmpty ? _addressText.trim() : tr('بدون عنوان', 'No address')}\n${tr('تم تحديد الموقع', 'Location selected')}\n${_latitude?.toStringAsFixed(6)}, ${_longitude?.toStringAsFixed(6)}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: LocationPickerScreen.darkColor,
                                fontWeight: FontWeight.w800,
                                height: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: _confirmLocation,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: LocationPickerScreen.goldColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: const Icon(Icons.check_circle_outline),
                              label: Text(
                                tr('اعتماد الموقع', 'Use This Location'),
                                style: const TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: _loadCurrentLocation,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: LocationPickerScreen.goldColor,
                                side: BorderSide(
                                  color: LocationPickerScreen.goldColor.withOpacity(0.65),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: const Icon(Icons.refresh_rounded),
                              label: Text(
                                tr('تحديث الموقع', 'Refresh Location'),
                                style: const TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextButton.icon(
                            onPressed: _openLocationExternally,
                            icon: const Icon(Icons.open_in_new_rounded),
                            label: Text(
                              tr('فتح الرابط في Google Maps للتحقق', 'Open in Google Maps to check'),
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
