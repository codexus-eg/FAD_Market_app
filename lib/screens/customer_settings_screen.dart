import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../models/customer.dart';
import '../services/api_service.dart';
import '../services/customer_session.dart';
import 'location_picker_screen.dart';

class CustomerSettingsScreen extends StatefulWidget {
  const CustomerSettingsScreen({super.key});

  static const Color goldColor = Color(0xFFD4A02A);
  static const Color darkColor = Color(0xFF202020);
  static const Color bgColor = Color(0xFFF5F5F5);

  @override
  State<CustomerSettingsScreen> createState() => _CustomerSettingsScreenState();
}

class _CustomerSettingsScreenState extends State<CustomerSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _callController = TextEditingController();
  final _countryController = TextEditingController();
  final _stateCityController = TextEditingController();
  final _addressController = TextEditingController();
  final _mapUrlController = TextEditingController();
  final _otpController = TextEditingController();

  Customer? _customer;
  bool _loading = true;
  bool _saving = false;
  bool _otpSent = false;
  String _otpToken = '';
  String _verificationToken = '';
  String _originalWhatsapp = '';
  double? _locationLat;
  double? _locationLng;

  String tr(String ar, String en) => AppController.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _loadCustomer();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _whatsappController.dispose();
    _callController.dispose();
    _countryController.dispose();
    _stateCityController.dispose();
    _addressController.dispose();
    _mapUrlController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomer() async {
    final customer = await CustomerSession.getCustomer();
    if (!mounted) return;

    if (customer == null) {
      setState(() => _loading = false);
      _showMessage(tr('يرجى تسجيل الدخول أولاً', 'Please login first'), success: false);
      return;
    }

    _customer = customer;
    _originalWhatsapp = _normalizePhone(customer.whatsappPhone);
    _nameController.text = customer.fullName;
    _whatsappController.text = _originalWhatsapp;
    _callController.text = _normalizePhone(customer.callPhone);
    _countryController.text = customer.country;
    _stateCityController.text = customer.stateCity;
    _addressController.text = customer.address;
    _mapUrlController.text = customer.mapUrl;
    _locationLat = customer.locationLat;
    _locationLng = customer.locationLng;

    setState(() => _loading = false);
  }

  String _normalizePhone(String value) {
    var clean = value.replaceAll(RegExp(r'[^0-9]'), '');
    while (clean.startsWith('00') && clean.length > 10) {
      clean = clean.substring(2);
    }
    return clean;
  }

  bool _isValidPhone(String value) {
    final clean = _normalizePhone(value);
    return RegExp(r'^[1-9][0-9]{7,14}$').hasMatch(clean);
  }

  String _phoneHintMessage() {
    return tr(
      'أدخل الرقم مع مفتاح الدولة بدون علامة +، مثال: 249912345678',
      'Enter the number with country code, without +. Example: 249912345678',
    );
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return tr('هذا الحقل مطلوب', 'This field is required');
    }
    return null;
  }

  String? _phoneValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return tr('رقم الهاتف مطلوب', 'Phone number is required');
    }
    if (!_isValidPhone(value)) {
      return _phoneHintMessage();
    }
    return null;
  }

  bool get _whatsappChanged => _normalizePhone(_whatsappController.text) != _originalWhatsapp;

  void _resetOtpIfPhoneChanged() {
    setState(() {
      if (_verificationToken.isNotEmpty || _otpSent) {
        _otpSent = false;
        _otpToken = '';
        _verificationToken = '';
        _otpController.clear();
      }
    });
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );

    if (result == null) return;

    final url = '${result['map_url'] ?? ''}'.trim();
    final addressText = '${result['address_text'] ?? ''}'.trim();
    final lat = double.tryParse('${result['lat'] ?? ''}');
    final lng = double.tryParse('${result['lng'] ?? ''}');

    if (url.isEmpty || lat == null || lng == null) return;

    setState(() {
      _mapUrlController.text = url;
      if (addressText.isNotEmpty && addressText != 'بدون عنوان') {
        _addressController.text = addressText;
      } else if (_addressController.text.trim().isEmpty) {
        _addressController.text = 'بدون عنوان';
      }
      _locationLat = lat;
      _locationLng = lng;
    });
  }

  Future<void> _sendOtp() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final phone = _normalizePhone(_whatsappController.text);
    _whatsappController.text = phone;
    _whatsappController.selection = TextSelection.collapsed(offset: phone.length);

    setState(() => _saving = true);

    try {
      final deviceId = await CustomerSession.getOrCreateDeviceId();
      final otp = await ApiService.requestWhatsAppOtp(
        phone: phone,
        deviceId: deviceId,
        purpose: 'profile_update',
      );

      final required = otp['otp_required'] == true || '${otp['otp_required']}' == '1';
      if (!required) {
        throw Exception(tr('تعذر إرسال رمز التحقق', 'Could not send OTP'));
      }

      if (!mounted) return;
      setState(() {
        _saving = false;
        _otpSent = true;
        _otpToken = '${otp['otp_token'] ?? ''}';
        _verificationToken = '';
        _otpController.clear();
      });

      _showMessage(tr('تم إرسال رمز التحقق عبر واتساب', 'OTP sent on WhatsApp'), success: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage(e.toString().replaceFirst('Exception: ', ''), success: false);
    }
  }

  Future<void> _verifyOtpAndSave() async {
    final code = _otpController.text.trim();
    if (code.length < 4) {
      _showMessage(tr('أدخل رمز التحقق', 'Enter the OTP code'), success: false);
      return;
    }

    setState(() => _saving = true);

    try {
      final phone = _normalizePhone(_whatsappController.text);
      final deviceId = await CustomerSession.getOrCreateDeviceId();
      final result = await ApiService.verifyWhatsAppOtp(
        phone: phone,
        deviceId: deviceId,
        otpToken: _otpToken,
        code: code,
      );

      final verified = result['verified'] == true || '${result['verified']}' == '1';
      if (!verified) {
        throw Exception(tr('رمز التحقق غير صحيح', 'Invalid OTP code'));
      }

      final token = '${result['verification_token'] ?? ''}';
      if (token.trim().isEmpty) {
        throw Exception(tr('لم يتم تأكيد التحقق، أرسل الرمز مرة أخرى', 'Verification was not confirmed, resend the code'));
      }

      _verificationToken = token;
      await _saveProfile(verificationToken: token, keepLoading: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage(e.toString().replaceFirst('Exception: ', ''), success: false);
    }
  }

  Future<void> _savePressed() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final whatsapp = _normalizePhone(_whatsappController.text);
    final call = _normalizePhone(_callController.text);
    _whatsappController.text = whatsapp;
    _callController.text = call;
    _whatsappController.selection = TextSelection.collapsed(offset: whatsapp.length);
    _callController.selection = TextSelection.collapsed(offset: call.length);

    if (_whatsappChanged && _verificationToken.trim().isEmpty) {
      await _sendOtp();
      return;
    }

    await _saveProfile(verificationToken: _verificationToken);
  }

  Future<void> _saveProfile({String verificationToken = '', bool keepLoading = false}) async {
    final customer = _customer ?? await CustomerSession.getCustomer();
    if (customer == null) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage(tr('يرجى تسجيل الدخول أولاً', 'Please login first'), success: false);
      return;
    }

    if (!keepLoading) {
      setState(() => _saving = true);
    }

    try {
      final deviceId = await CustomerSession.getOrCreateDeviceId();
      final updated = await ApiService.updateCustomerProfile(
        authToken: customer.authToken,
        deviceId: deviceId,
        fullName: _nameController.text.trim(),
        whatsappPhone: _normalizePhone(_whatsappController.text),
        callPhone: _normalizePhone(_callController.text),
        country: _countryController.text.trim(),
        stateCity: _stateCityController.text.trim(),
        address: _addressController.text.trim().isNotEmpty
            ? _addressController.text.trim()
            : (_mapUrlController.text.trim().isNotEmpty ? 'بدون عنوان' : ''),
        mapUrl: _mapUrlController.text.trim(),
        locationLat: _locationLat,
        locationLng: _locationLng,
        otpVerificationToken: verificationToken,
      );

      await CustomerSession.saveCustomer(updated);

      if (!mounted) return;
      setState(() {
        _customer = updated;
        _originalWhatsapp = _normalizePhone(updated.whatsappPhone);
        _otpSent = false;
        _otpToken = '';
        _verificationToken = '';
        _otpController.clear();
        _saving = false;
      });

      _showMessage(tr('تم تحديث البيانات بنجاح', 'Profile updated successfully'), success: true);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage(e.toString().replaceFirst('Exception: ', ''), success: false);
    }
  }

  void _showMessage(String message, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? CustomerSettingsScreen.goldColor : Colors.redAccent,
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int maxLines = 1,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: CustomerSettingsScreen.goldColor),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: CustomerSettingsScreen.goldColor, width: 1.4),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppController.language,
      builder: (context, lang, child) {
        return Directionality(
          textDirection: AppController.direction,
          child: Scaffold(
            backgroundColor: CustomerSettingsScreen.bgColor,
            appBar: AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 0,
              title: Text(
                tr('إعدادات الحساب', 'Account Settings'),
                style: const TextStyle(
                  color: CustomerSettingsScreen.darkColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
              iconTheme: const IconThemeData(color: CustomerSettingsScreen.darkColor),
            ),
            body: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: CustomerSettingsScreen.goldColor),
                  )
                : SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _field(
                                    controller: _nameController,
                                    label: tr('الاسم الكامل', 'Full Name'),
                                    icon: Icons.person_rounded,
                                    validator: _requiredValidator,
                                  ),
                                  const SizedBox(height: 14),
                                  _field(
                                    controller: _whatsappController,
                                    label: tr('رقم واتساب', 'WhatsApp Number'),
                                    icon: Icons.chat_rounded,
                                    keyboardType: TextInputType.phone,
                                    validator: _phoneValidator,
                                    onChanged: (_) => _resetOtpIfPhoneChanged(),
                                  ),
                                  if (_whatsappChanged) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      tr(
                                        'عند تغيير رقم واتساب يجب تأكيد الرقم الجديد برمز تحقق قبل حفظ البيانات.',
                                        'When changing WhatsApp number, the new number must be verified by OTP before saving.',
                                      ),
                                      style: TextStyle(
                                        color: CustomerSettingsScreen.darkColor.withOpacity(0.62),
                                        fontWeight: FontWeight.w700,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 14),
                                  _field(
                                    controller: _callController,
                                    label: tr('رقم الاتصال', 'Call Number'),
                                    icon: Icons.call_rounded,
                                    keyboardType: TextInputType.phone,
                                    validator: _phoneValidator,
                                  ),
                                  const SizedBox(height: 14),
                                  _field(
                                    controller: _countryController,
                                    label: tr('الدولة', 'Country'),
                                    icon: Icons.flag_rounded,
                                    validator: _requiredValidator,
                                  ),
                                  const SizedBox(height: 14),
                                  _field(
                                    controller: _stateCityController,
                                    label: tr('المدينة / الولاية', 'City / State'),
                                    icon: Icons.location_city_rounded,
                                    validator: _requiredValidator,
                                  ),
                                  const SizedBox(height: 14),
                                  _field(
                                    controller: _addressController,
                                    label: tr('العنوان', 'Address'),
                                    icon: Icons.home_rounded,
                                    maxLines: 2,
                                  ),
                                  const SizedBox(height: 14),
                                  OutlinedButton.icon(
                                    onPressed: _saving ? null : _pickLocation,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: CustomerSettingsScreen.goldColor,
                                      side: BorderSide(color: CustomerSettingsScreen.goldColor.withOpacity(0.6)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                    icon: const Icon(Icons.my_location_rounded),
                                    label: Text(
                                      _mapUrlController.text.trim().isEmpty
                                          ? tr('تحديد الموقع', 'Select Location')
                                          : tr('تحديث الموقع', 'Update Location'),
                                      style: const TextStyle(fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                  if (_mapUrlController.text.trim().isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      tr('تم حفظ رابط الموقع مع الحساب', 'Map link is saved with the account'),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: CustomerSettingsScreen.darkColor.withOpacity(0.58),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                  if (_otpSent && _whatsappChanged) ...[
                                    const SizedBox(height: 16),
                                    _field(
                                      controller: _otpController,
                                      label: tr('رمز التحقق', 'OTP Code'),
                                      icon: Icons.verified_rounded,
                                      keyboardType: TextInputType.number,
                                      validator: (value) => (value == null || value.trim().isEmpty)
                                          ? tr('أدخل رمز التحقق', 'Enter the OTP code')
                                          : null,
                                    ),
                                  ],
                                  const SizedBox(height: 18),
                                  SizedBox(
                                    height: 52,
                                    child: ElevatedButton.icon(
                                      onPressed: _saving
                                          ? null
                                          : (_otpSent && _whatsappChanged
                                              ? _verifyOtpAndSave
                                              : _savePressed),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: CustomerSettingsScreen.goldColor,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      icon: _saving
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(Icons.save_rounded),
                                      label: Text(
                                        _otpSent && _whatsappChanged
                                            ? tr('تأكيد الرمز وحفظ البيانات', 'Verify OTP and Save')
                                            : (_whatsappChanged
                                                ? tr('إرسال رمز التحقق', 'Send OTP')
                                                : tr('حفظ التعديلات', 'Save Changes')),
                                        style: const TextStyle(fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
