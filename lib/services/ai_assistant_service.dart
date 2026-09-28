import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_service.dart';

class AiMachine {
  final int id;
  final String modelCode;
  final String nameAr;
  final String nameEn;
  final String controller;

  const AiMachine({
    required this.id,
    required this.modelCode,
    required this.nameAr,
    required this.nameEn,
    required this.controller,
  });

  factory AiMachine.fromJson(Map<String, dynamic> json) {
    return AiMachine(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      modelCode: '${json['model_code'] ?? ''}',
      nameAr: '${json['name_ar'] ?? ''}',
      nameEn: '${json['name_en'] ?? ''}',
      controller: '${json['controller'] ?? ''}',
    );
  }
}

class AiMachinePart {
  final int id;
  final int machineId;
  final String category;
  final String partCode;
  final String nameAr;
  final String nameEn;

  const AiMachinePart({
    required this.id,
    required this.machineId,
    required this.category,
    required this.partCode,
    required this.nameAr,
    required this.nameEn,
  });

  factory AiMachinePart.fromJson(Map<String, dynamic> json) {
    return AiMachinePart(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      machineId: int.tryParse('${json['machine_id'] ?? 0}') ?? 0,
      category: '${json['fault_category'] ?? ''}',
      partCode: '${json['part_code'] ?? ''}',
      nameAr: '${json['name_ar'] ?? ''}',
      nameEn: '${json['name_en'] ?? ''}',
    );
  }
}

class AiCatalog {
  final List<AiMachine> machines;
  final List<AiMachinePart> parts;

  const AiCatalog({required this.machines, required this.parts});
}

class AiAssistantReply {
  final bool success;
  final bool machineVerified;
  final String message;
  final String sourceType;
  final double confidence;
  final String caseId;
  final int? machineId;
  final bool askMachine;
  final bool outOfScope;

  const AiAssistantReply({
    required this.success,
    required this.machineVerified,
    required this.message,
    required this.sourceType,
    required this.confidence,
    required this.caseId,
    this.machineId,
    this.askMachine = false,
    this.outOfScope = false,
  });

  factory AiAssistantReply.fromJson(Map<String, dynamic> json) {
    return AiAssistantReply(
      success: json['success'] == true,
      machineVerified: json['machine_verified'] == true,
      message: '${json['message'] ?? json['reply'] ?? ''}',
      sourceType: '${json['source_type'] ?? ''}',
      confidence: double.tryParse('${json['confidence'] ?? 0}') ?? 0,
      caseId: '${json['conversation_id'] ?? json['case_id'] ?? ''}',
      machineId: int.tryParse('${json['machine_id']}'),
      askMachine: json['ask_machine'] == true,
      outOfScope: json['out_of_scope'] == true,
    );
  }
}

class AiAppConfig {
  final bool enabled;
  final bool loginRequired;
  final String titleAr;
  final String titleEn;
  final List<String> teaserMessagesAr;
  final List<String> teaserMessagesEn;
  final int teaserIntervalMs;
  final int animationCycleMs;
  final String welcomeAr;
  final String welcomeEn;

  const AiAppConfig({
    required this.enabled,
    required this.loginRequired,
    required this.titleAr,
    required this.titleEn,
    required this.teaserMessagesAr,
    required this.teaserMessagesEn,
    required this.teaserIntervalMs,
    required this.animationCycleMs,
    required this.welcomeAr,
    required this.welcomeEn,
  });

  factory AiAppConfig.defaults() => const AiAppConfig(
        enabled: true,
        loginRequired: true,
        titleAr: 'مساعد FCE الذكي للصيانة',
        titleEn: 'FCE AI Maintenance Assistant',
        teaserMessagesAr: ['عاوز تسالني', 'عاوز مساعدة', 'انا مساعدك الذكي'],
        teaserMessagesEn: [
          'Want to ask me?',
          'Need help?',
          'I am your smart assistant',
        ],
        teaserIntervalMs: 2200,
        animationCycleMs: 2400,
        welcomeAr:
            'أهلاً بيك، أنا مساعد FCE للصيانة. اشرح المشكلة أو أرسل صورة أو تسجيل صوتي.',
        welcomeEn:
            'Welcome to FCE maintenance. Describe the problem, send a photo, or record your voice.',
      );

  factory AiAppConfig.fromJson(Map<String, dynamic> json) {
    List<String> listOf(dynamic value, List<String> fallback) {
      if (value is List) {
        final list =
            value.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList();
        if (list.isNotEmpty) return list;
      }
      if (value is String) {
        final list = value
            .split(RegExp(r'[\n|]+'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        if (list.isNotEmpty) return list;
      }
      return fallback;
    }

    final d = AiAppConfig.defaults();
    return AiAppConfig(
      enabled: json['enabled'] == null
          ? d.enabled
          : json['enabled'] == true || '${json['enabled']}' == '1',
      loginRequired: json['login_required'] == null
          ? d.loginRequired
          : json['login_required'] == true ||
              '${json['login_required']}' == '1',
      titleAr: '${json['title_ar'] ?? d.titleAr}'.trim().isEmpty
          ? d.titleAr
          : '${json['title_ar']}',
      titleEn: '${json['title_en'] ?? d.titleEn}'.trim().isEmpty
          ? d.titleEn
          : '${json['title_en']}',
      teaserMessagesAr: listOf(json['teaser_messages_ar'], d.teaserMessagesAr),
      teaserMessagesEn: listOf(json['teaser_messages_en'], d.teaserMessagesEn),
      teaserIntervalMs:
          int.tryParse('${json['teaser_interval_ms'] ?? d.teaserIntervalMs}') ??
              d.teaserIntervalMs,
      animationCycleMs:
          int.tryParse('${json['animation_cycle_ms'] ?? d.animationCycleMs}') ??
              d.animationCycleMs,
      welcomeAr: '${json['welcome_ar'] ?? d.welcomeAr}'.trim().isEmpty
          ? d.welcomeAr
          : '${json['welcome_ar']}',
      welcomeEn: '${json['welcome_en'] ?? d.welcomeEn}'.trim().isEmpty
          ? d.welcomeEn
          : '${json['welcome_en']}',
    );
  }
}

class AiAssistantService {
  static http.Client client = http.Client();
  static Future<Uint8List> attachment({
    required String authToken,
    required String deviceId,
    required String conversationId,
    required int messageId,
  }) async {
    final response = await client.post(
      Uri.parse('${ApiService.baseUrl}/ai_conversations.php'),
      body: {
        'auth_token': authToken,
        'device_id': deviceId,
        'action': 'attachment',
        'conversation_id': conversationId,
        'message_id': '$messageId',
      },
    ).timeout(const Duration(seconds: 45));
    if (response.statusCode != 200 ||
        (response.headers['content-type'] ?? '').contains('json')) {
      throw Exception('Could not open attachment');
    }
    return response.bodyBytes;
  }

  static Future<Map<String, dynamic>> conversations({
    required String authToken,
    required String deviceId,
    required String action,
    Map<String, String> fields = const {},
  }) async {
    final response = await client.post(
      Uri.parse('${ApiService.baseUrl}/ai_conversations.php'),
      body: {
        'auth_token': authToken,
        'device_id': deviceId,
        'action': action,
        ...fields,
      },
    ).timeout(const Duration(seconds: 30));
    final data = Map<String, dynamic>.from(jsonDecode(response.body));
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception('${data['message'] ?? 'Conversation request failed'}');
    }
    return data;
  }

  static Future<AiAppConfig> getAppConfig() async {
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/ai_app_config.php');
      final response =
          await client.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return AiAppConfig.defaults();
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['success'] != true)
        return AiAppConfig.defaults();
      final raw = decoded['config'];
      if (raw is! Map) return AiAppConfig.defaults();
      return AiAppConfig.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return AiAppConfig.defaults();
    }
  }

  static Future<AiCatalog> getCatalog() async {
    final uri = Uri.parse('${ApiService.baseUrl}/ai_catalog.php');
    final response = await client.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('AI catalog server error: ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['success'] != true) {
      throw Exception(
        decoded is Map
            ? '${decoded['message'] ?? 'AI catalog error'}'
            : 'AI catalog error',
      );
    }
    final machinesRaw =
        decoded['machines'] is List ? decoded['machines'] as List : const [];
    final partsRaw =
        decoded['parts'] is List ? decoded['parts'] as List : const [];
    return AiCatalog(
      machines: machinesRaw
          .whereType<Map>()
          .map((e) => AiMachine.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.id > 0)
          .toList(),
      parts: partsRaw
          .whereType<Map>()
          .map((e) => AiMachinePart.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.id > 0)
          .toList(),
    );
  }

  static Future<AiAssistantReply> send({
    required String authToken,
    required String deviceId,
    required String action,
    int? machineId,
    required String requestId,
    required String appLanguage,
    String faultCategory = '',
    int? partId,
    String message = '',
    String? sessionId,
    String? imagePath,
    String? audioPath,
  }) async {
    final fields = <String, String>{
      'auth_token': authToken,
      'device_id': deviceId,
      'action': action,
      'machine_id': '${machineId ?? 0}',
      'conversation_id': sessionId ?? '',
      'request_id': requestId,
      'app_language': appLanguage,
      'fault_category': faultCategory,
      'part_id': '${partId ?? 0}',
      'message': message,
      'session_id': sessionId ?? '',
    };

    late http.Response response;
    final hasImage = imagePath != null && imagePath.trim().isNotEmpty;
    final hasAudio = audioPath != null && audioPath.trim().isNotEmpty;

    if (!hasImage && !hasAudio) {
      response = await http
          .post(
            Uri.parse('${ApiService.baseUrl}/ai_assistant.php'),
            body: fields,
          )
          .timeout(const Duration(seconds: 120));
    } else {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiService.baseUrl}/ai_assistant.php'),
      );
      request.fields.addAll(fields);

      if (hasImage) {
        await _addAttachment(
          request,
          field: 'image',
          path: imagePath,
          webFilename: 'fault-image.jpg',
        );
      }
      if (hasAudio) {
        await _addAttachment(
          request,
          field: 'audio',
          path: audioPath,
          webFilename: 'voice-message.webm',
        );
      }

      final streamed =
          await client.send(request).timeout(const Duration(seconds: 280));
      response = await http.Response.fromStream(streamed);
    }
    Map<String, dynamic> decoded;
    try {
      decoded = Map<String, dynamic>.from(jsonDecode(response.body));
    } catch (_) {
      throw Exception('Invalid AI server response (${response.statusCode})');
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['success'] != true) {
      throw Exception('${decoded['message'] ?? 'AI request failed'}');
    }
    return AiAssistantReply.fromJson(decoded);
  }

  static Future<void> _addAttachment(
    http.MultipartRequest request, {
    required String field,
    required String path,
    required String webFilename,
  }) async {
    if (kIsWeb) {
      final source = await http.get(Uri.parse(path)).timeout(
            const Duration(seconds: 45),
          );
      if (source.statusCode < 200 || source.statusCode >= 300) {
        throw Exception('Could not read $field attachment');
      }
      request.files.add(
        http.MultipartFile.fromBytes(
          field,
          source.bodyBytes,
          filename: webFilename,
        ),
      );
      return;
    }

    final file = File(path);
    if (!await file.exists()) {
      throw Exception('Could not read $field attachment');
    }
    request.files.add(await http.MultipartFile.fromPath(field, file.path));
  }
}
