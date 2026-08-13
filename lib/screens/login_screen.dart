import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../services/api_service.dart';
import '../services/customer_session.dart';
import '../services/employee_api_service.dart';
import '../services/employee_session.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static const Color goldColor = Color(0xFFD4A02A);
  static const Color darkColor = Color(0xFF202020);
  static const Color bgColor = Color(0xFFF5F5F5);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String _googlePlayReviewPhone = '12345678';
  static const String _abdoDirectPhone = '249912345678';
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  bool _loading = false;
  bool _otpSent = false;
  String _otpToken = '';
  String _pendingPhone = '';
  String _verificationToken = '';

  String tr(String ar, String en) => AppController.isArabic ? ar : en;

  @override
  void dispose() {
    _loginController.dispose();
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
      'Enter WhatsApp number with country code without +. Example: 249912345678',
    );
  }

  bool _looksLikeEmployeeNo(String value) {
    final clean = value.trim().toUpperCase();
    if (clean.isEmpty) return false;

    return clean.startsWith('FCE-MNT') ||
        clean.startsWith('FAD-MNT') ||
        clean.startsWith('MNT') ||
        clean.startsWith('EMP') ||
        clean.startsWith('TECH') ||
        clean.contains('-MNT-') ||
        RegExp(r'[A-Z]').hasMatch(clean);
  }

  Future<void> _login() async {
    final rawValue = _loginController.text.trim();

    if (rawValue.isEmpty) {
      _showMessage(_phoneHintMessage());
      return;
    }

    final isEmployee = _looksLikeEmployeeNo(rawValue);
    final value = isEmployee ? rawValue : _normalizeWhatsappNumber(rawValue);

    if (!isEmployee && !_isValidWhatsappNumber(value)) {
      _showMessage(_phoneHintMessage());
      return;
    }

    if (!isEmployee && _loginController.text.trim() != value) {
      _loginController.text = value;
      _loginController.selection = TextSelection.collapsed(offset: value.length);
    }

    setState(() => _loading = true);

    final deviceId = await CustomerSession.getOrCreateDeviceId();

    try {
      if (isEmployee) {
        await _loginAsEmployee(employeeNo: value, deviceId: deviceId);
        return;
      }

      if (value == _abdoDirectPhone) {
        final customer = await ApiService.loginAbdoDirect(
          phone: value,
          deviceId: deviceId,
        );

        await CustomerSession.saveCustomer(customer);

        if (!mounted) return;
        Navigator.pop(context, true);
        return;
      }

      if (value == _googlePlayReviewPhone) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _otpSent = true;
          _pendingPhone = value;
          _otpToken = '';
          _verificationToken = '';
          _otpController.clear();
        });
        _showMessage(tr('أدخل كود المراجعة', 'Enter the review code'));
        return;
      }

      final otp = await ApiService.requestWhatsAppOtp(
        phone: value,
        deviceId: deviceId,
        purpose: 'login',
      );

      final otpRequired = otp['otp_required'] == true || '${otp['otp_required']}' == '1';

      if (otpRequired) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _otpSent = true;
          _pendingPhone = value;
          _otpToken = '${otp['otp_token'] ?? ''}';
          _verificationToken = '';
          _otpController.clear();
        });
        _showMessage(tr('تم إرسال رمز التحقق عبر واتساب', 'OTP sent on WhatsApp'));
        return;
      }

      await _loginAsCustomer(phone: value, deviceId: deviceId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();

    if (code.length < 4) {
      _showMessage(tr('أدخل رمز التحقق', 'Enter the OTP code'));
      return;
    }

    setState(() => _loading = true);

    final deviceId = await CustomerSession.getOrCreateDeviceId();

    try {
      if (_pendingPhone == _googlePlayReviewPhone) {
        final customer = await ApiService.loginGooglePlayReview(
          phone: _pendingPhone,
          code: code,
          deviceId: deviceId,
        );

        await CustomerSession.saveCustomer(customer);

        if (!mounted) return;
        Navigator.pop(context, true);
        return;
      }

      final result = await ApiService.verifyWhatsAppOtp(
        phone: _pendingPhone,
        deviceId: deviceId,
        otpToken: _otpToken,
        code: code,
      );

      final verified = result['verified'] == true || '${result['verified']}' == '1';

      if (!verified) {
        if (!mounted) return;
        setState(() => _loading = false);
        _showMessage(tr('رمز التحقق غير صحيح', 'Invalid OTP code'));
        return;
      }

      _verificationToken = '${result['verification_token'] ?? ''}';

      if (_verificationToken.trim().isEmpty) {
        throw Exception(tr('لم يتم تأكيد التحقق، يرجى إرسال الرمز مرة أخرى', 'Verification was not confirmed, resend the code'));
      }

      await _loginAsCustomer(
        phone: _pendingPhone,
        deviceId: deviceId,
        otpVerificationToken: _verificationToken,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _resendOtp() async {
    setState(() {
      _otpSent = false;
      _otpToken = '';
      _verificationToken = '';
      _otpController.clear();
    });
    await _login();
  }

  Future<void> _loginAsCustomer({
    required String phone,
    required String deviceId,
    String otpVerificationToken = '',
  }) async {
    final customer = await ApiService.loginCustomer(
      phone: phone,
      deviceId: deviceId,
      otpVerificationToken: otpVerificationToken,
    );

    await CustomerSession.saveCustomer(customer);

    if (!mounted) return;

    Navigator.pop(context, true);
  }

  Future<void> _loginAsEmployee({
    required String employeeNo,
    required String deviceId,
  }) async {
    final employee = await EmployeeApiService.loginEmployee(
      employeeNo: employeeNo,
      deviceId: deviceId,
    );

    await EmployeeSession.saveEmployee(employee);

    if (!mounted) return;

    Navigator.pop(context, true);
  }

  Future<void> _openRegister() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );

    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppController.language,
      builder: (context, lang, child) {
        return Directionality(
          textDirection: AppController.direction,
          child: Scaffold(
            backgroundColor: LoginScreen.bgColor,
            appBar: AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              title: Text(
                tr('تسجيل الدخول', 'Login'),
                style: const TextStyle(
                  color: LoginScreen.darkColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 540),
                  child: ListView(
                    padding: const EdgeInsets.all(22),
                    children: [
                      const SizedBox(height: 26),
                      Container(
                        width: 84,
                        height: 84,
                        margin: const EdgeInsets.symmetric(horizontal: 110),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 22,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/fce_logo.jpeg',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        tr('تسجيل دخول العملاء', 'Customer Login'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: LoginScreen.darkColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: Column(
                          children: [
                            Text(
                              _phoneHintMessage(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: LoginScreen.darkColor.withOpacity(0.65),
                                fontWeight: FontWeight.w800,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _loginController,
                              enabled: !_otpSent,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                labelText: tr('رقم الواتساب', 'WhatsApp number'),
                                helperText: tr('مثال :249912345678', 'Example: 249912345678'),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onSubmitted: (_) {
                                if (!_loading && !_otpSent) _login();
                              },
                            ),
                            if (_otpSent) ...[
                              const SizedBox(height: 14),
                              TextField(
                                controller: _otpController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  labelText: tr('رمز التحقق', 'OTP code'),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                onSubmitted: (_) {
                                  if (!_loading) _verifyOtp();
                                },
                              ),
                              const SizedBox(height: 10),
                              TextButton(
                                onPressed: _loading ? null : _resendOtp,
                                child: Text(
                                  tr('إعادة إرسال الرمز', 'Resend OTP'),
                                  style: const TextStyle(
                                    color: LoginScreen.goldColor,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton.icon(
                                onPressed: _loading ? null : (_otpSent ? _verifyOtp : _login),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: LoginScreen.goldColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                ),
                                icon: _loading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : Icon(_otpSent ? Icons.verified_user_rounded : Icons.login_rounded),
                                label: Text(
                                  _loading
                                      ? tr('جارٍ التحقق...', 'Checking...')
                                      : (_otpSent ? tr('تأكيد الرمز', 'Verify code') : tr('تسجيل الدخول', 'Login')),
                                  style: const TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (!_otpSent)
                              TextButton(
                                onPressed: _loading ? null : _openRegister,
                                child: Text(
                                  tr('إنشاء حساب جديد', 'Create new account'),
                                  style: const TextStyle(
                                    color: LoginScreen.goldColor,
                                    fontWeight: FontWeight.w900,
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
