import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../services/api_service.dart';
import '../services/customer_session.dart';
import 'location_picker_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  static const Color goldColor = Color(0xFFD4A02A);
  static const Color darkColor = Color(0xFF202020);
  static const Color bgColor = Color(0xFFF5F5F5);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _callController = TextEditingController();
  final _countryController = TextEditingController();
  final _stateCityController = TextEditingController();
  final _addressController = TextEditingController();
  final _mapUrlController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isLoading = false;
  bool _otpSent = false;
  String _otpToken = '';
  String _verificationToken = '';
  double? _locationLat;
  double? _locationLng;

  String tr(String ar, String en) => AppController.isArabic ? ar : en;

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

  String _normalizeWhatsappNumber(String value) {
    var clean = value.replaceAll(RegExp(r'[^0-9]'), '');
    while (clean.startsWith('00') && clean.length > 10) {
      clean = clean.substring(2);
    }
    return clean;
  }

  bool _isValidWhatsappNumber(String value) {
    final clean = _normalizeWhatsappNumber(value);
    return RegExp(r'^[1-9][0-9]{7,14}$').hasMatch(clean);
  }

  String _phoneHintMessage() {
    return tr(
      'أدخل رقم واتساب مع مفتاح الدولة بدون علامة +، مثال: 249912345678',
      'Enter WhatsApp number only with country code, without +. Example: 249912345678',
    );
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return tr('هذا الحقل مطلوب', 'This field is required');
    }
    return null;
  }

  String? _whatsappValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return tr('رقم الواتساب مطلوب', 'WhatsApp number is required');
    }

    if (!_isValidWhatsappNumber(value)) {
      return _phoneHintMessage();
    }

    return null;
  }

  String? _phoneValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return tr('رقم الهاتف مطلوب', 'Phone number is required');
    }

    final clean = _normalizeWhatsappNumber(value);

    if (!_isValidWhatsappNumber(clean)) {
      return _phoneHintMessage();
    }

    return null;
  }

  Future<void> _sendOtp() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final phone = _normalizeWhatsappNumber(_whatsappController.text);

    _whatsappController.text = phone;
    _whatsappController.selection = TextSelection.collapsed(offset: phone.length);

    setState(() => _isLoading = true);

    try {
      final deviceId = await CustomerSession.getOrCreateDeviceId();

      final otp = await ApiService.requestWhatsAppOtp(
        phone: phone,
        deviceId: deviceId,
        purpose: 'register',
      );

      final required = otp['otp_required'] == true || '${otp['otp_required']}' == '1';

      if (!required) {
        throw Exception(tr('تعذر إرسال رمز التحقق', 'Could not send OTP'));
      }

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _otpSent = true;
        _otpToken = '${otp['otp_token'] ?? ''}';
        _verificationToken = '';
        _otpController.clear();
      });

      _showMessage(tr('تم إرسال رمز التحقق عبر واتساب', 'OTP sent on WhatsApp'), success: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage(e.toString().replaceFirst('Exception: ', ''), success: false);
    }
  }

  Future<void> _verifyAndCreate() async {
    final code = _otpController.text.trim();

    if (code.length < 4) {
      _showMessage(tr('أدخل رمز التحقق', 'Enter the OTP code'), success: false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final phone = _normalizeWhatsappNumber(_whatsappController.text);
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

      _verificationToken = '${result['verification_token'] ?? ''}';

      if (_verificationToken.trim().isEmpty) {
        throw Exception(tr('لم يتم تأكيد التحقق، يرجى إرسال الرمز مرة أخرى', 'Verification was not confirmed, resend the code'));
      }

      await _createAccount(deviceId: deviceId, verificationToken: _verificationToken);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage(e.toString().replaceFirst('Exception: ', ''), success: false);
    }
  }

  Future<void> _createAccount({
    required String deviceId,
    required String verificationToken,
  }) async {
    final customer = await ApiService.registerCustomer(
      fullName: _nameController.text.trim(),
      whatsappPhone: _normalizeWhatsappNumber(_whatsappController.text),
      callPhone: _normalizeWhatsappNumber(_callController.text),
      country: _countryController.text.trim(),
      stateCity: _stateCityController.text.trim(),
      address: _addressController.text.trim().isNotEmpty
          ? _addressController.text.trim()
          : (_mapUrlController.text.trim().isNotEmpty
              ? 'بدون عنوان'
              : ''),
      mapUrl: _mapUrlController.text.trim(),
      locationLat: _locationLat,
      locationLng: _locationLng,
      deviceId: deviceId,
      otpVerificationToken: verificationToken,
    );

    await CustomerSession.saveCustomer(customer);

    if (!mounted) return;

    _showMessage(tr('تم إنشاء الحساب بنجاح', 'Account created successfully'), success: true);
    Navigator.pop(context, true);
  }


  Future<void> _pickLocation() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => const LocationPickerScreen(),
      ),
    );

    if (result == null) return;

    final url = '${result['map_url'] ?? ''}'.trim();
    final addressText = '${result['address_text'] ?? ''}'.trim();
    final lat = double.tryParse('${result['lat'] ?? ''}');
    final lng = double.tryParse('${result['lng'] ?? ''}');

    if (url.isEmpty || lat == null || lng == null) return;

    setState(() {
      _mapUrlController.text = url;
      if (_addressController.text.trim().isEmpty) {
        _addressController.text = addressText.isNotEmpty
            ? addressText
            : 'بدون عنوان';
      }
      _locationLat = lat;
      _locationLng = lng;
    });
  }

  void _resetOtp() {
    setState(() {
      _otpSent = false;
      _otpToken = '';
      _verificationToken = '';
      _otpController.clear();
    });
  }

  void _showMessage(String message, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : Colors.redAccent,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_otpSent) {
      await _sendOtp();
      return;
    }

    await _verifyAndCreate();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppController.language,
      builder: (context, lang, child) {
        return Directionality(
          textDirection: AppController.direction,
          child: Scaffold(
            backgroundColor: RegisterScreen.bgColor,
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 700;
                  final cardWidth = isWide ? 520.0 : constraints.maxWidth;

                  return SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isWide ? 32 : 18,
                      vertical: 18,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: cardWidth),
                        child: Column(
                          children: [
                            _TopBar(
                              title: tr('إنشاء حساب', 'Create Account'),
                              onLanguageTap: AppController.toggleLanguage,
                            ),
                            const SizedBox(height: 18),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 24,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: AppController.isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tr(
                                        'لن يتم إنشاء الحساب إلا بعد تأكيد رمز واتساب.',
                                        'The account will not be created until WhatsApp OTP is verified.',
                                      ),
                                      textAlign: AppController.isArabic ? TextAlign.right : TextAlign.left,
                                      style: const TextStyle(
                                        color: RegisterScreen.darkColor,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        height: 1.3,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      _phoneHintMessage(),
                                      textAlign: AppController.isArabic ? TextAlign.right : TextAlign.left,
                                      style: TextStyle(
                                        color: RegisterScreen.darkColor.withOpacity(0.65),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    _AppTextField(
                                      controller: _nameController,
                                      label: tr('الاسم', 'Full Name'),
                                      icon: Icons.person_outline,
                                      validator: _requiredValidator,
                                      enabled: !_otpSent,
                                    ),
                                    const SizedBox(height: 14),
                                    _AppTextField(
                                      controller: _whatsappController,
                                      label: tr('رقم واتساب مع مفتاح الدولة بدون +', 'WhatsApp number with country code, without +'),
                                      icon: Icons.chat_outlined,
                                      keyboardType: TextInputType.phone,
                                      validator: _whatsappValidator,
                                      enabled: !_otpSent,
                                    ),
                                    const SizedBox(height: 14),
                                    _AppTextField(
                                      controller: _callController,
                                      label: tr('رقم الاتصال', 'Call Number'),
                                      icon: Icons.phone_outlined,
                                      keyboardType: TextInputType.phone,
                                      validator: _phoneValidator,
                                      enabled: !_otpSent,
                                    ),
                                    const SizedBox(height: 14),
                                    _AppTextField(
                                      controller: _countryController,
                                      label: tr('البلد', 'Country'),
                                      icon: Icons.public_outlined,
                                      validator: _requiredValidator,
                                      enabled: !_otpSent,
                                    ),
                                    const SizedBox(height: 14),
                                    _AppTextField(
                                      controller: _stateCityController,
                                      label: tr('الولاية / المدينة', 'State / City'),
                                      icon: Icons.location_city_outlined,
                                      validator: _requiredValidator,
                                      enabled: !_otpSent,
                                    ),
                                    const SizedBox(height: 14),
                                    _AppTextField(
                                      controller: _addressController,
                                      label: tr('العنوان اختياري', 'Address optional'),
                                      icon: Icons.location_on_outlined,
                                      maxLines: 2,
                                      enabled: !_otpSent,
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: _otpSent ? null : _pickLocation,
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: RegisterScreen.goldColor,
                                          side: BorderSide(color: RegisterScreen.goldColor.withOpacity(0.65)),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
                                        ),
                                        icon: const Icon(Icons.map_outlined),
                                        label: Text(
                                          _mapUrlController.text.trim().isEmpty
                                              ? tr('استخدام موقعي الحالي', 'Use My Current Location')
                                              : tr('تم اختيار الموقع - تعديل', 'Location selected - Edit'),
                                          style: const TextStyle(fontWeight: FontWeight.w900),
                                        ),
                                      ),
                                    ),
                                    if (_mapUrlController.text.trim().isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        tr('تم حفظ رابط الموقع مع الحساب', 'Map link will be saved with the account'),
                                        textAlign: AppController.isArabic ? TextAlign.right : TextAlign.left,
                                        style: TextStyle(
                                          color: RegisterScreen.darkColor.withOpacity(0.58),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                    if (_otpSent) ...[
                                      const SizedBox(height: 16),
                                      _AppTextField(
                                        controller: _otpController,
                                        label: tr('رمز واتساب', 'WhatsApp OTP'),
                                        icon: Icons.verified_user_outlined,
                                        keyboardType: TextInputType.number,
                                      ),
                                      const SizedBox(height: 8),
                                      TextButton(
                                        onPressed: _isLoading ? null : _resetOtp,
                                        child: Text(
                                          tr('تغيير الرقم وإعادة الإرسال', 'Change number and resend'),
                                          style: const TextStyle(
                                            color: RegisterScreen.goldColor,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 24),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 54,
                                      child: ElevatedButton(
                                        onPressed: _isLoading ? null : _submit,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: RegisterScreen.goldColor,
                                          foregroundColor: Colors.white,
                                          disabledBackgroundColor: RegisterScreen.goldColor.withOpacity(0.45),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(18),
                                          ),
                                        ),
                                        child: _isLoading
                                            ? const SizedBox(
                                                width: 24,
                                                height: 24,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.4,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : Text(
                                                _otpSent
                                                    ? tr('تأكيد الرمز وإنشاء الحساب', 'Verify OTP and Create Account')
                                                    : tr('إرسال رمز واتساب', 'Send WhatsApp OTP'),
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Center(
                                      child: TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text(
                                          tr('لدي حساب بالفعل', 'I already have an account'),
                                          style: const TextStyle(
                                            color: RegisterScreen.darkColor,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
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
}

class _TopBar extends StatelessWidget {
  final String title;
  final VoidCallback onLanguageTap;

  const _TopBar({
    required this.title,
    required this.onLanguageTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filled(
          onPressed: () => Navigator.pop(context),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: RegisterScreen.darkColor,
          ),
          icon: const Icon(Icons.arrow_back),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: RegisterScreen.darkColor,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        TextButton(
          onPressed: onLanguageTap,
          child: Text(
            AppController.t('language'),
            style: const TextStyle(
              color: RegisterScreen.goldColor,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;
  final bool enabled;

  const _AppTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFFF7F7F7),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: RegisterScreen.goldColor,
            width: 1.4,
          ),
        ),
      ),
    );
  }
}
