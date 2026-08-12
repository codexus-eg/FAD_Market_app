import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/service_employee.dart';

class EmployeeSession {
  static const String _employeeKey = 'fce_service_employee';

  static Future<void> saveEmployee(ServiceEmployee employee) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _employeeKey,
      jsonEncode(employee.toJson()),
    );
  }

  static Future<ServiceEmployee?> getEmployee() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_employeeKey);

    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      return ServiceEmployee.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw)),
      );
    } catch (_) {
      await clearEmployee();
      return null;
    }
  }

  static Future<bool> isLoggedIn() async {
    final employee = await getEmployee();
    return employee != null && employee.authToken.trim().isNotEmpty;
  }

  static Future<void> clearEmployee() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_employeeKey);
  }
}
