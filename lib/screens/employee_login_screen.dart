import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../services/customer_session.dart';
import '../services/employee_api_service.dart';
import '../services/employee_session.dart';

class EmployeeLoginScreen extends StatefulWidget {
  const EmployeeLoginScreen({super.key});

  static const Color goldColor = Color(0xFFD4A02A);
  static const Color darkColor = Color(0xFF202020);
  static const Color bgColor = Color(0xFFF5F5F5);

  @override
  State<EmployeeLoginScreen> createState() => _EmployeeLoginScreenState();
}

class _EmployeeLoginScreenState extends State<EmployeeLoginScreen> {
  final TextEditingController _employeeNoController = TextEditingController();
  bool _loading = false;

  String tr(String ar, String en) {
    return AppController.isArabic ? ar : en;
  }

  @override
  void dispose() {
    _employeeNoController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final employeeNo = _employeeNoController.text.trim();

    if (employeeNo.isEmpty) {
      _showMessage(tr('أدخل الرقم الوظيفي', 'Enter employee number'));
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final deviceId = await CustomerSession.getOrCreateDeviceId();

      final employee = await EmployeeApiService.loginEmployee(
        employeeNo: employeeNo,
        deviceId: deviceId,
      );

      await EmployeeSession.saveEmployee(employee);

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showMessage(
        tr(
          'الرقم الوظيفي غير صحيح أو غير مفعل',
          'Employee number is invalid or inactive',
        ),
      );
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
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
            backgroundColor: EmployeeLoginScreen.bgColor,
            appBar: AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              title: Text(
                tr('تسجيل دخول موظف الصيانة', 'Employee Login'),
                style: const TextStyle(
                  color: EmployeeLoginScreen.darkColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: ListView(
                    padding: const EdgeInsets.all(22),
                    children: [
                      const SizedBox(height: 30),
                      const Icon(
                        Icons.engineering_rounded,
                        size: 70,
                        color: EmployeeLoginScreen.goldColor,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        tr(
                          'أدخل الرقم الوظيفي لتسجيل الدخول كموظف صيانة',
                          'Enter your employee number to login',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: EmployeeLoginScreen.darkColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: _employeeNoController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: InputDecoration(
                                labelText: tr(
                                  'الرقم الوظيفي',
                                  'Employee number',
                                ),
                                hintText: 'FCE-MNT-2026-0001',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton.icon(
                                onPressed: _loading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      EmployeeLoginScreen.goldColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                icon: _loading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.login_rounded),
                                label: Text(
                                  _loading
                                      ? tr('جارٍ تسجيل الدخول...', 'Logging in...')
                                      : tr('تسجيل الدخول', 'Login'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
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
