import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_controller.dart';
import '../services/customer_session.dart';
import '../services/employee_api_service.dart';
import '../services/employee_session.dart';

class LeaderTaskDistributionScreen extends StatefulWidget {
  const LeaderTaskDistributionScreen({super.key});

  static const Color goldColor = Color(0xFFD4A02A);
  static const Color darkColor = Color(0xFF202020);
  static const Color bgColor = Color(0xFFF5F5F5);

  @override
  State<LeaderTaskDistributionScreen> createState() =>
      _LeaderTaskDistributionScreenState();
}

class _LeaderTaskDistributionScreenState
    extends State<LeaderTaskDistributionScreen> {
  late Future<Map<String, dynamic>> _futureData;
  final Map<int, Set<int>> _selectedEmployeesByTask = {};
  final Set<int> _editingTasks = {};
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  bool _submitting = false;

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

    return EmployeeApiService.getLeaderTasks(
      authToken: employee.authToken,
      deviceId: deviceId,
    );
  }

  void _reload() {
    setState(() {
      _futureData = _load();
    });
  }

  String _memberRolesText(Map<String, dynamic> member) {
    final rawRoles = member['roles'];

    if (rawRoles is! List || rawRoles.isEmpty) {
      return tr('بدون وظيفة محددة', 'No role selected');
    }

    final names = <String>[];

    for (final item in rawRoles) {
      if (item is Map) {
        final role = Map<String, dynamic>.from(item);
        final name = AppController.isArabic
            ? '${role['name_ar'] ?? ''}'
            : '${role['name_en'] ?? ''}';

        if (name.trim().isNotEmpty) {
          names.add(name.trim());
        }
      }
    }

    if (names.isEmpty) {
      return tr('بدون وظيفة محددة', 'No role selected');
    }

    return names.join('، ');
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

  Future<void> _exportReport(String scope) async {
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
      scope: scope,
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

  Future<void> _assign(int requestId) async {
    final selected = _selectedEmployeesByTask[requestId] ?? <int>{};

    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('اختر موظفاً واحداً على الأقل', 'Select at least one employee'))),
      );
      return;
    }

    final employee = await EmployeeSession.getEmployee();

    if (employee == null || employee.authToken.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('الجلسة انتهت', 'Session expired'))),
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final deviceId = await CustomerSession.getOrCreateDeviceId();

      await EmployeeApiService.assignTask(
        authToken: employee.authToken,
        deviceId: deviceId,
        maintenanceRequestId: requestId,
        employeeIds: selected.toList(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('تم حفظ توزيع المهمة', 'Task assignment saved'))),
      );

      setState(() {
        _submitting = false;
        _editingTasks.remove(requestId);
        _selectedEmployeesByTask.remove(requestId);
        _futureData = _load();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _submitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('تعذر توزيع المهمة', 'Could not assign task'))),
      );
    }
  }

  List<int> _assignedIds(Map<String, dynamic> task) {
    final raw = task['assigned_members'];

    if (raw is! List) return [];

    return raw.map((item) {
      if (item is Map) {
        return int.tryParse('${item['id'] ?? 0}') ?? 0;
      }
      return 0;
    }).where((id) => id > 0).toList();
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
            tr('تصدير تقرير PDF', 'Export PDF report'),
            style: const TextStyle(
              color: LeaderTaskDistributionScreen.darkColor,
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _exportReport('self'),
                  icon: const Icon(Icons.person_rounded),
                  label: Text(tr('تقريري', 'My report')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _exportReport('branch'),
                  icon: const Icon(Icons.group_rounded),
                  label: Text(tr('تقرير الفريق', 'Team report')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LeaderTaskDistributionScreen.goldColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
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

  Widget _taskCard({
    required Map<String, dynamic> task,
    required List<Map<String, dynamic>> team,
    required String cardMode,
  }) {
    final requestId = int.tryParse('${task['id'] ?? 0}') ?? 0;
    final assignedNames = '${task['assigned_names'] ?? ''}'.trim();
    final isWaiting = cardMode == 'waiting';
    final isOngoing = cardMode == 'ongoing';
    final isCompleted = cardMode == 'completed';
    final isEditing = isWaiting || _editingTasks.contains(requestId);

    _selectedEmployeesByTask.putIfAbsent(
      requestId,
      () => _assignedIds(task).toSet(),
    );
    final selected = _selectedEmployeesByTask[requestId] ?? <int>{};

    final branchName = AppController.isArabic
        ? '${task['branch_name_ar'] ?? task['branch'] ?? ''}'
        : '${task['branch_name_en'] ?? task['branch'] ?? ''}';

    final statusText = isCompleted
        ? tr('تم الإنجاز', 'Completed')
        : isOngoing
            ? tr('قيد التنفيذ / لم يكتمل', 'In progress / not completed')
            : tr('في انتظار التوزيع', 'Waiting for assignment');

    final statusColor = isCompleted
        ? Colors.green
        : isOngoing
            ? Colors.blue
            : Colors.orange;

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
                  '${tr('طلب صيانة', 'Maintenance')}: ${task['request_number'] ?? ''}',
                  textAlign: AppController.isArabic ? TextAlign.right : TextAlign.left,
                  style: const TextStyle(
                    color: LeaderTaskDistributionScreen.darkColor,
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
          Text('${tr('الفرع', 'Branch')}: $branchName'),
          Text('${tr('الماكينة', 'Machine')}: ${task['machine_name'] ?? ''}'),
          Text('${tr('العنوان', 'Address')}: ${task['address'] ?? ''}'),
          if (assignedNames.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${tr('معلقة لدى', 'Assigned to')}: $assignedNames',
              style: const TextStyle(
                color: LeaderTaskDistributionScreen.goldColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
          if (isOngoing) ...[
            const SizedBox(height: 8),
            Text(
              tr(
                'تظل معلقة لحين تأكيد العميل. يمكن تعديل الموظفين قبل التأكيد.',
                'Pending customer approval. Employees can be changed before approval.',
              ),
              style: TextStyle(
                color: LeaderTaskDistributionScreen.darkColor.withOpacity(0.56),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (isCompleted) ...[
            const SizedBox(height: 8),
            Text(
              '${tr('تم تأكيد العميل', 'Customer approved')}: ${task['approved_by_customer_at'] ?? ''}',
              style: TextStyle(
                color: LeaderTaskDistributionScreen.darkColor.withOpacity(0.56),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (!isCompleted && !isEditing && isOngoing) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _editingTasks.add(requestId);
                  });
                },
                icon: const Icon(Icons.edit_rounded),
                label: Text(tr('تعديل التوزيع', 'Edit assignment')),
              ),
            ),
          ],
          if (!isCompleted && isEditing) ...[
            const SizedBox(height: 14),
            Align(
              alignment: AppController.isArabic ? Alignment.centerRight : Alignment.centerLeft,
              child: Text(
                isWaiting
                    ? tr('اختر الموظفين للمهمة', 'Select employees for this task')
                    : tr('تعديل الموظفين للمهمة', 'Edit assigned employees'),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 8),
            ...team.map((member) {
              final id = int.tryParse('${member['id'] ?? 0}') ?? 0;
              final checked = selected.contains(id);

              return CheckboxListTile(
                value: checked,
                activeColor: LeaderTaskDistributionScreen.goldColor,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${member['full_name'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(_memberRolesText(member)),
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      selected.add(id);
                    } else {
                      selected.remove(id);
                    }
                  });
                },
              );
            }),
            const SizedBox(height: 12),
            Row(
              children: [
                if (isOngoing) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting
                          ? null
                          : () {
                              setState(() {
                                _editingTasks.remove(requestId);
                                _selectedEmployeesByTask[requestId] = _assignedIds(task).toSet();
                              });
                            },
                      child: Text(tr('إلغاء', 'Cancel')),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: SizedBox(
                    height: 45,
                    child: ElevatedButton.icon(
                      onPressed: _submitting ? null : () => _assign(requestId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LeaderTaskDistributionScreen.goldColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: _submitting
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        isWaiting
                            ? tr('تأكيد توزيع المهمة', 'Confirm assignment')
                            : tr('حفظ التعديل', 'Save edit'),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required List<Map<String, dynamic>> tasks,
    required List<Map<String, dynamic>> team,
    required String mode,
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
            color: LeaderTaskDistributionScreen.darkColor,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        ...tasks.map((task) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _taskCard(task: task, team: team, cardMode: mode),
          );
        }),
      ],
    );
  }

  List<Map<String, dynamic>> _listFrom(dynamic raw) {
    if (raw is! List) return <Map<String, dynamic>>[];

    return raw.map((item) {
      return Map<String, dynamic>.from(item as Map);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppController.language,
      builder: (context, lang, child) {
        return Directionality(
          textDirection: AppController.direction,
          child: Scaffold(
            backgroundColor: LeaderTaskDistributionScreen.bgColor,
            appBar: AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              title: Text(
                tr('توزيع المهام', 'Distribute Tasks'),
                style: const TextStyle(
                  color: LeaderTaskDistributionScreen.darkColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            body: SafeArea(
              child: RefreshIndicator(
                color: LeaderTaskDistributionScreen.goldColor,
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
                          color: LeaderTaskDistributionScreen.goldColor,
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return ListView(
                        padding: const EdgeInsets.all(22),
                        children: [
                          const SizedBox(height: 80),
                          const Icon(
                            Icons.assignment_late_outlined,
                            size: 60,
                            color: LeaderTaskDistributionScreen.goldColor,
                          ),
                          const SizedBox(height: 14),
                          Center(
                            child: Text(
                              tr('تعذر تحميل مهام قائد الفريق', 'Could not load leader tasks'),
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
                    final waiting = _listFrom(data['waiting_tasks']);
                    final ongoing = _listFrom(data['ongoing_tasks']);
                    final completed = _listFrom(data['completed_tasks']);
                    final team = _listFrom(data['team']);

                    return ListView(
                      padding: const EdgeInsets.all(18),
                      children: [
                        _reportBox(),
                        _section(
                          title: tr('مهام في انتظار التوزيع', 'Waiting for assignment'),
                          tasks: waiting,
                          team: team,
                          mode: 'waiting',
                        ),
                        _section(
                          title: tr('مهام قيد التنفيذ / لم تكتمل بعد', 'In progress / not completed'),
                          tasks: ongoing,
                          team: team,
                          mode: 'ongoing',
                        ),
                        _section(
                          title: tr('مهام مكتملة', 'Completed tasks'),
                          tasks: completed,
                          team: team,
                          mode: 'completed',
                        ),
                        if (waiting.isEmpty && ongoing.isEmpty && completed.isEmpty) ...[
                          const SizedBox(height: 70),
                          const Icon(
                            Icons.assignment_turned_in_outlined,
                            color: LeaderTaskDistributionScreen.goldColor,
                            size: 64,
                          ),
                          const SizedBox(height: 14),
                          Center(
                            child: Text(
                              tr('لا توجد مهام حالياً', 'No tasks right now'),
                              style: const TextStyle(fontWeight: FontWeight.w900),
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
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
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
