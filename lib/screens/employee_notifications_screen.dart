import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_controller.dart';
import '../models/service_employee.dart';
import '../services/customer_session.dart';
import '../services/employee_api_service.dart';
import '../services/employee_session.dart';

class EmployeeNotificationsScreen extends StatefulWidget {
  const EmployeeNotificationsScreen({super.key});

  static const Color goldColor = Color(0xFFD4A02A);
  static const Color darkColor = Color(0xFF202020);
  static const Color bgColor = Color(0xFFF5F5F5);

  @override
  State<EmployeeNotificationsScreen> createState() =>
      _EmployeeNotificationsScreenState();
}

class _EmployeeNotificationsScreenState
    extends State<EmployeeNotificationsScreen> {
  late Future<Map<String, dynamic>> _futureData;
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();

  String tr(String ar, String en) {
    return AppController.isArabic ? ar : en;
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fromController.text = '${now.year}-${_two(now.month)}-01';
    _toController.text = '${now.year}-${_two(now.month)}-${_two(now.day)}';
    _futureData = _load();
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  Future<Map<String, dynamic>> _load() async {
    final employee = await EmployeeSession.getEmployee();

    if (employee == null || employee.authToken.trim().isEmpty) {
      throw Exception('Unauthorized');
    }

    final deviceId = await CustomerSession.getOrCreateDeviceId();

    return EmployeeApiService.getEmployeeNotifications(
      authToken: employee.authToken,
      deviceId: deviceId,
    );
  }

  void _reload() {
    setState(() {
      _futureData = _load();
    });
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final now = DateTime.now();
    final current = DateTime.tryParse(controller.text) ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );

    if (picked == null) return;

    controller.text = '${picked.year}-${_two(picked.month)}-${_two(picked.day)}';
  }

  Future<void> _exportMyReport() async {
    final employee = await EmployeeSession.getEmployee();

    if (employee == null || employee.authToken.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('الجلسة انتهت', 'Session expired'))),
      );
      return;
    }

    final deviceId = await CustomerSession.getOrCreateDeviceId();

    final uri = EmployeeApiService.employeeReportUrl(
      authToken: employee.authToken,
      deviceId: deviceId,
      from: _fromController.text.trim(),
      to: _toController.text.trim(),
      scope: 'self',
    );

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('تعذر فتح التقرير', 'Could not open report'))),
      );
    }
  }

  Widget _reportBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: AppController.isArabic
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            tr('تصدير تقريري PDF', 'Export my PDF report'),
            style: const TextStyle(
              color: EmployeeNotificationsScreen.darkColor,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _fromController,
                  readOnly: true,
                  onTap: () => _pickDate(_fromController),
                  decoration: InputDecoration(
                    labelText: tr('من تاريخ', 'From'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _toController,
                  readOnly: true,
                  onTap: () => _pickDate(_toController),
                  decoration: InputDecoration(
                    labelText: tr('إلى تاريخ', 'To'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: _exportMyReport,
              icon: const Icon(Icons.download_rounded),
              label: Text(tr('تصدير PDF', 'Export PDF')),
              style: ElevatedButton.styleFrom(
                backgroundColor: EmployeeNotificationsScreen.goldColor,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _openCustomerWhatsApp(dynamic rawPhone) async {
    var phone = '${rawPhone ?? ''}'.replaceAll(RegExp(r'[^0-9]'), '');

    if (phone.startsWith('00')) {
      phone = phone.substring(2);
    }

    if (phone.isEmpty) return;

    final opened = await launchUrl(
      Uri.parse('https://wa.me/$phone'),
      mode: LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('تعذر فتح واتساب', 'Could not open WhatsApp'),
          ),
        ),
      );
    }
  }

  Widget _taskCard(Map<String, dynamic> task, {required bool completed}) {
    final branchName = AppController.isArabic
        ? '${task['branch_name_ar'] ?? task['branch'] ?? ''}'
        : '${task['branch_name_en'] ?? task['branch'] ?? ''}';

    final statusText = completed
        ? tr('تم الإنجاز', 'Completed')
        : tr('قيد التنفيذ / لم يكتمل', 'In progress / not completed');

    final statusColor = completed ? Colors.green : Colors.blue;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: AppController.isArabic
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${tr('مهمة صيانة', 'Maintenance task')}: ${task['request_number'] ?? ''}',
                  textAlign: AppController.isArabic ? TextAlign.right : TextAlign.left,
                  style: const TextStyle(
                    color: EmployeeNotificationsScreen.darkColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _StatusChip(text: statusText, color: statusColor),
            ],
          ),
          const SizedBox(height: 8),
          Text('${tr('العميل', 'Customer')}: ${task['customer_name'] ?? ''}'),
          Text('${tr('واتساب', 'WhatsApp')}: ${task['customer_whatsapp'] ?? ''}'),
          if ('${task['customer_whatsapp'] ?? ''}'.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: OutlinedButton.icon(
                onPressed: () => _openCustomerWhatsApp(
                  task['customer_whatsapp'],
                ),
                icon: const Icon(Icons.chat_rounded),
                label: Text(
                  tr('فتح واتساب العميل', 'Open customer WhatsApp'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF25D366),
                  side: const BorderSide(
                    color: Color(0xFF25D366),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
          Text('${tr('فرع', 'Branch')}: $branchName'),
          Text('${tr('الماكينة', 'Machine')}: ${task['machine_name'] ?? ''}'),
          Text('${tr('عدد الماكينات', 'Machines count')}: ${task['machines_count'] ?? 1}'),
          Text('${tr('العنوان', 'Address')}: ${task['address'] ?? ''}'),
          const SizedBox(height: 8),
          if (completed)
            Text(
              '${tr('تاريخ تأكيد العميل', 'Customer approved at')}: ${task['approved_by_customer_at'] ?? ''}',
              style: TextStyle(
                color: EmployeeNotificationsScreen.darkColor.withOpacity(0.55),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            )
          else ...[
            Text(
              '${tr('تاريخ التوزيع', 'Assigned at')}: ${task['assigned_at'] ?? ''}',
              style: TextStyle(
                color: EmployeeNotificationsScreen.darkColor.withOpacity(0.55),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              tr(
                'المهمة معلقة لحين تأكيد العميل.',
                'Task is pending until customer approval.',
              ),
              style: TextStyle(
                color: EmployeeNotificationsScreen.darkColor.withOpacity(0.50),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _listFrom(dynamic raw) {
    if (raw is! List) return <Map<String, dynamic>>[];

    return raw.map((item) {
      return Map<String, dynamic>.from(item as Map);
    }).toList();
  }

  Widget _section({
    required String title,
    required List<Map<String, dynamic>> tasks,
    required bool completed,
  }) {
    if (tasks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: AppController.isArabic
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: AppController.isArabic ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            color: EmployeeNotificationsScreen.darkColor,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        ...tasks.map((task) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _taskCard(task, completed: completed),
          );
        }),
      ],
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
            backgroundColor: EmployeeNotificationsScreen.bgColor,
            appBar: AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              title: Text(
                tr('مهامي', 'My Tasks'),
                style: const TextStyle(
                  color: EmployeeNotificationsScreen.darkColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            body: SafeArea(
              child: RefreshIndicator(
                color: EmployeeNotificationsScreen.goldColor,
                onRefresh: () async {
                  _reload();
                  await _futureData;
                },
                child: FutureBuilder<Map<String, dynamic>>(
                  future: _futureData,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: EmployeeNotificationsScreen.goldColor,
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return ListView(
                        padding: const EdgeInsets.all(22),
                        children: [
                          const SizedBox(height: 90),
                          const Icon(
                            Icons.notifications_off_outlined,
                            color: EmployeeNotificationsScreen.goldColor,
                            size: 60,
                          ),
                          const SizedBox(height: 14),
                          Center(
                            child: Text(
                              tr('تعذر تحميل المهام', 'Could not load tasks'),
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Center(
                            child: ElevatedButton(
                              onPressed: _reload,
                              child: Text(tr('إعادة المحاولة', 'Retry')),
                            ),
                          ),
                        ],
                      );
                    }

                    final data = snapshot.data ?? {};
                    final active = _listFrom(data['active_tasks'] ?? data['tasks']);
                    final completed = _listFrom(data['completed_tasks']);

                    final rawEmployee = data['employee'];
                    ServiceEmployee? employee;
                    if (rawEmployee is Map) {
                      employee = ServiceEmployee.fromJson(
                        Map<String, dynamic>.from(rawEmployee),
                      );
                    }

                    return ListView(
                      padding: const EdgeInsets.all(18),
                      children: [
                        _reportBox(),
                        const SizedBox(height: 16),
                        if (employee != null)
                          Text(
                            '${tr('الموظف', 'Employee')}: ${employee.fullName}',
                            textAlign: AppController.isArabic ? TextAlign.right : TextAlign.left,
                            style: const TextStyle(
                              color: EmployeeNotificationsScreen.darkColor,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        _section(
                          title: tr('مهام قيد التنفيذ / لم تكتمل بعد', 'In progress / not completed'),
                          tasks: active,
                          completed: false,
                        ),
                        _section(
                          title: tr('مهام مكتملة', 'Completed tasks'),
                          tasks: completed,
                          completed: true,
                        ),
                        if (active.isEmpty && completed.isEmpty) ...[
                          const SizedBox(height: 70),
                          const Icon(
                            Icons.notifications_none_rounded,
                            color: EmployeeNotificationsScreen.goldColor,
                            size: 64,
                          ),
                          const SizedBox(height: 14),
                          Center(
                            child: Text(
                              tr('لا توجد مهام حالياً', 'No tasks right now'),
                              style: const TextStyle(
                                color: EmployeeNotificationsScreen.darkColor,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String text;
  final Color color;

  const _StatusChip({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
