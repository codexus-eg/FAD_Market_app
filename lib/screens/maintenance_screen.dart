import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../app_controller.dart';
import '../models/service_branch.dart';
import '../services/customer_session.dart';
import '../services/employee_api_service.dart';
import 'login_screen.dart';
import 'my_orders_screen.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  static const Color goldColor = Color(0xFFD4A02A);
  static const Color darkColor = Color(0xFF202020);
  static const Color bgColor = Color(0xFFF5F5F5);

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  static const String _createUrl =
      'https://365hub.site/fce-dashboard/api/maintenance_create.php';

  final TextEditingController _machineController = TextEditingController();
  final TextEditingController _invoiceController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _countController = TextEditingController(text: '1');

  List<ServiceBranch> _branches = [];
  ServiceBranch? _selectedBranch;

  String _warrantyStatus = 'outside';
  bool _loadingSession = true;
  bool _loadingBranches = true;
  bool _loggedIn = false;
  bool _submitting = false;

  String tr(String ar, String en) {
    return AppController.isArabic ? ar : en;
  }

  @override
  void initState() {
    super.initState();
    _checkSession();
    _loadBranches();
  }

  @override
  void dispose() {
    _machineController.dispose();
    _invoiceController.dispose();
    _addressController.dispose();
    _countController.dispose();
    super.dispose();
  }

  Future<void> _checkSession() async {
    final logged = await CustomerSession.isLoggedIn();

    if (!mounted) return;

    setState(() {
      _loggedIn = logged;
      _loadingSession = false;
    });
  }

  Future<void> _loadBranches() async {
    try {
      final branches = await EmployeeApiService.getBranches();

      if (!mounted) return;

      setState(() {
        _branches = branches;
        _selectedBranch = branches.isNotEmpty ? branches.first : null;
        _loadingBranches = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _branches = const [
          ServiceBranch(id: 0, code: 'atbara', nameAr: 'عطبرة', nameEn: 'Atbara'),
          ServiceBranch(id: 0, code: 'wad_madani', nameAr: 'مدني', nameEn: 'Wad Madani'),
          ServiceBranch(id: 0, code: 'khartoum', nameAr: 'الخرطوم', nameEn: 'Khartoum'),
          ServiceBranch(id: 0, code: 'port_sudan', nameAr: 'بورتسودان', nameEn: 'Port Sudan'),
          ServiceBranch(id: 0, code: 'ajman', nameAr: 'عجمان', nameEn: 'Ajman'),
        ];
        _selectedBranch = _branches.last;
        _loadingBranches = false;
      });
    }
  }

  Future<void> _openLogin() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );

    await _checkSession();
  }

  Future<void> _submit() async {
    final machineName = _machineController.text.trim();
    final invoiceNumber = _invoiceController.text.trim();
    final address = _addressController.text.trim();
    final machinesCount = int.tryParse(_countController.text.trim()) ?? 1;

    if (_selectedBranch == null) {
      _showMessage(tr('اختر أقرب فرع', 'Select nearest branch'));
      return;
    }

    if (machineName.isEmpty) {
      _showMessage(tr('أدخل اسم الماكينة', 'Enter machine name'));
      return;
    }

    if (_warrantyStatus == 'inside' && invoiceNumber.isEmpty) {
      _showMessage(tr('أدخل رقم الفاتورة', 'Enter invoice number'));
      return;
    }

    if (address.isEmpty) {
      _showMessage(tr('أدخل العنوان بالتفصيل', 'Enter detailed address'));
      return;
    }

    if (machinesCount <= 0) {
      _showMessage(tr('عدد الماكينات غير صحيح', 'Invalid machines count'));
      return;
    }

    final customer = await CustomerSession.getCustomer();

    if (customer == null || customer.authToken.trim().isEmpty) {
      _showMessage(
        tr(
          'انتهت الجلسة، يرجى تسجيل الدخول مرة أخرى',
          'Session expired, please login again',
        ),
      );
      setState(() {
        _loggedIn = false;
      });
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final deviceId = await CustomerSession.getOrCreateDeviceId();

      final response = await http.post(
        Uri.parse(_createUrl),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          'auth_token': customer.authToken,
          'device_id': deviceId,
          'branch_id': _selectedBranch!.id,
          'branch': _selectedBranch!.nameAr,
          'machine_name': machineName,
          'warranty_status': _warrantyStatus,
          'invoice_number': invoiceNumber,
          'address': address,
          'machines_count': machinesCount,
        }),
      );

      final decoded = jsonDecode(response.body);

      if (decoded['success'] != true) {
        throw Exception(decoded['message'] ?? 'Maintenance request failed');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('طلبك قيد المراجعة', 'Your request is under review'),
          ),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const MyOrdersScreen(),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _submitting = false;
      });

      _showMessage(
        tr(
          'تعذر إرسال طلب الصيانة، حاول مرة أخرى',
          'Could not submit maintenance request, please try again',
        ),
      );
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
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
            backgroundColor: MaintenanceScreen.bgColor,
            appBar: AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              title: Text(
                tr('طلب صيانة', 'Maintenance Request'),
                style: const TextStyle(
                  color: MaintenanceScreen.darkColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            body: SafeArea(
              child: _loadingSession
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: MaintenanceScreen.goldColor,
                      ),
                    )
                  : !_loggedIn
                      ? _LoginRequired(onLogin: _openLogin)
                      : Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 760),
                            child: ListView(
                              padding: const EdgeInsets.all(18),
                              children: [
                                _SectionCard(
                                  title: tr('أقرب فرع لك', 'Nearest branch'),
                                  child: _loadingBranches
                                      ? const LinearProgressIndicator(
                                          color: MaintenanceScreen.goldColor,
                                        )
                                      : DropdownButtonFormField<int>(
                                          alignment: AppController.isArabic
                                              ? Alignment.centerRight
                                              : Alignment.centerLeft,
                                          value: _selectedBranch?.id,
                                          items: _branches.map((branch) {
                                            return DropdownMenuItem<int>(
                                              value: branch.id,
                                              child: Directionality(
                                                textDirection: AppController.direction,
                                                child: Text(
                                                  branch.name(
                                                    AppController.isArabic,
                                                  ),
                                                  textAlign: AppController.isArabic
                                                      ? TextAlign.right
                                                      : TextAlign.left,
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (value) {
                                            if (value == null) return;
                                            setState(() {
                                              _selectedBranch = _branches
                                                  .where((b) => b.id == value)
                                                  .first;
                                            });
                                          },
                                          decoration: InputDecoration(
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                          ),
                                        ),
                                ),
                                const SizedBox(height: 14),
                                _SectionCard(
                                  title: tr('بيانات الماكينة', 'Machine details'),
                                  child: Column(
                                    children: [
                                      TextField(
                                        textDirection: AppController.direction,
                                        textAlign: AppController.isArabic ? TextAlign.right : TextAlign.left,
                                        controller: _machineController,
                                        decoration: InputDecoration(
                                          labelText: tr(
                                            'اسم الماكينة',
                                            'Machine name',
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: RadioListTile<String>(
                                              value: 'inside',
                                              groupValue: _warrantyStatus,
                                              activeColor:
                                                  MaintenanceScreen.goldColor,
                                              onChanged: (value) {
                                                if (value == null) return;
                                                setState(() {
                                                  _warrantyStatus = value;
                                                });
                                              },
                                              title: Text(
                                                tr(
                                                  'داخل الضمان',
                                                  'Inside warranty',
                                                ),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              controlAffinity: ListTileControlAffinity.leading,
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                          ),
                                          Expanded(
                                            child: RadioListTile<String>(
                                              value: 'outside',
                                              groupValue: _warrantyStatus,
                                              activeColor:
                                                  MaintenanceScreen.goldColor,
                                              onChanged: (value) {
                                                if (value == null) return;
                                                setState(() {
                                                  _warrantyStatus = value;
                                                });
                                              },
                                              title: Text(
                                                tr(
                                                  'خارج الضمان',
                                                  'Outside warranty',
                                                ),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              controlAffinity: ListTileControlAffinity.leading,
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (_warrantyStatus == 'inside') ...[
                                        const SizedBox(height: 12),
                                        TextField(
                                          textDirection: AppController.direction,
                                          textAlign: AppController.isArabic ? TextAlign.right : TextAlign.left,
                                          controller: _invoiceController,
                                          decoration: InputDecoration(
                                            labelText: tr(
                                              'رقم الفاتورة',
                                              'Invoice number',
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 12),
                                      TextField(
                                        textDirection: AppController.direction,
                                        textAlign: AppController.isArabic ? TextAlign.right : TextAlign.left,
                                        controller: _countController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: tr(
                                            'عدد الماكينات للصيانة',
                                            'Number of machines',
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _SectionCard(
                                  title: tr('العنوان بالتفصيل', 'Detailed address'),
                                  child: TextField(
                                    textDirection: AppController.direction,
                                    textAlign: AppController.isArabic ? TextAlign.right : TextAlign.left,
                                    controller: _addressController,
                                    maxLines: 5,
                                    decoration: InputDecoration(
                                      hintText: tr(
                                        'أدخل المدينة، الحي، الشارع، وأقرب معلم...',
                                        'Write city, area, street, nearest landmark...',
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: ElevatedButton.icon(
                                    onPressed: _submitting ? null : _submit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          MaintenanceScreen.goldColor,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                    icon: _submitting
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.build_rounded),
                                    label: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        _submitting
                                            ? tr('جارٍ الإرسال...', 'Submitting...')
                                            : tr('تأكيد الطلب', 'Confirm Request'),
                                        maxLines: 1,
                                        softWrap: false,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
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

class _LoginRequired extends StatelessWidget {
  final VoidCallback onLogin;

  const _LoginRequired({
    required this.onLogin,
  });

  String tr(String ar, String en) {
    return AppController.isArabic ? ar : en;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const SizedBox(height: 90),
        const Icon(
          Icons.lock_outline_rounded,
          color: MaintenanceScreen.goldColor,
          size: 68,
        ),
        const SizedBox(height: 18),
        Text(
          tr(
            'يجب تسجيل الدخول لطلب الصيانة',
            'Please login to request maintenance',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: MaintenanceScreen.darkColor,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tr(
            'سيتم تسجيل بيانات العميل تلقائياً مع طلب الصيانة.',
            'Your customer details will be attached automatically.',
          ),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: MaintenanceScreen.darkColor.withOpacity(0.65),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: onLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: MaintenanceScreen.goldColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                tr('تسجيل الدخول / إنشاء حساب', 'Login / Register'),
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: AppController.isArabic
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: MaintenanceScreen.darkColor,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
