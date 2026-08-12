import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/service_branch.dart';
import '../models/service_employee.dart';

class EmployeeApiService {
  static const String baseUrl = 'https://365hub.site/fce-dashboard/api';

  static Future<List<ServiceBranch>> getBranches() async {
    final response = await http.get(
      Uri.parse('$baseUrl/service_branches_list.php'),
    );

    final decoded = jsonDecode(response.body);

    if (decoded['success'] != true) {
      throw Exception(decoded['message'] ?? 'Could not load branches');
    }

    final List data = decoded['data'] ?? [];

    return data.map((item) {
      return ServiceBranch.fromJson(Map<String, dynamic>.from(item));
    }).toList();
  }

  static Future<ServiceEmployee> loginEmployee({
    required String employeeNo,
    required String deviceId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/employee_login.php'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({
        'employee_no': employeeNo,
        'device_id': deviceId,
      }),
    );

    final decoded = jsonDecode(response.body);

    if (decoded['success'] != true) {
      throw Exception(decoded['message'] ?? 'Employee login failed');
    }

    return ServiceEmployee.fromJson(
      Map<String, dynamic>.from(decoded['employee'] ?? {}),
    );
  }

  static Future<ServiceEmployee> employeeMe({
    required String authToken,
    required String deviceId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/employee_me.php'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({
        'auth_token': authToken,
        'device_id': deviceId,
      }),
    );

    final decoded = jsonDecode(response.body);

    if (decoded['success'] != true) {
      throw Exception(decoded['message'] ?? 'Unauthorized');
    }

    return ServiceEmployee.fromJson(
      Map<String, dynamic>.from(decoded['employee'] ?? {}),
    );
  }

  static Future<Map<String, dynamic>> getLeaderTasks({
    required String authToken,
    required String deviceId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/leader_tasks.php'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({
        'auth_token': authToken,
        'device_id': deviceId,
      }),
    );

    final decoded = jsonDecode(response.body);

    if (decoded['success'] != true) {
      throw Exception(decoded['message'] ?? 'Could not load leader tasks');
    }

    return Map<String, dynamic>.from(decoded);
  }

  static Future<void> assignTask({
    required String authToken,
    required String deviceId,
    required int maintenanceRequestId,
    required List<int> employeeIds,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/assign_task.php'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({
        'auth_token': authToken,
        'device_id': deviceId,
        'maintenance_request_id': maintenanceRequestId,
        'employee_ids': employeeIds,
      }),
    );

    final decoded = jsonDecode(response.body);

    if (decoded['success'] != true) {
      throw Exception(decoded['message'] ?? 'Could not assign task');
    }
  }

  static Future<Map<String, dynamic>> getEmployeeNotifications({
    required String authToken,
    required String deviceId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/employee_notifications.php'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({
        'auth_token': authToken,
        'device_id': deviceId,
      }),
    );

    final decoded = jsonDecode(response.body);

    if (decoded['success'] != true) {
      throw Exception(decoded['message'] ?? 'Could not load notifications');
    }

    return Map<String, dynamic>.from(decoded);
  }
  static Uri employeeReportUrl({
    required String authToken,
    required String deviceId,
    required String from,
    required String to,
    required String scope,
  }) {
    return Uri.parse('$baseUrl/employee_report.php').replace(
      queryParameters: {
        'auth_token': authToken,
        'device_id': deviceId,
        'from': from,
        'to': to,
        'scope': scope,
        'format': 'pdf',
      },
    );
  }

}
