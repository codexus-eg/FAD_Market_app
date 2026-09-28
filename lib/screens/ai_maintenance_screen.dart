import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../app_controller.dart';
import '../models/customer.dart';
import '../services/ai_assistant_service.dart';
import '../services/customer_session.dart';

class AiMaintenanceScreen extends StatefulWidget {
  final AiAppConfig? appConfig;

  const AiMaintenanceScreen({super.key, this.appConfig});

  @override
  State<AiMaintenanceScreen> createState() => _AiMaintenanceScreenState();
}

class _AiMessage {
  final bool fromUser;
  final String text;
  final String sourceType;
  final double confidence;
  final int? id;
  final String? mediaMime;

  const _AiMessage({
    required this.fromUser,
    required this.text,
    this.sourceType = '',
    this.confidence = 0,
    this.id,
    this.mediaMime,
  });
}

bool _isVoiceMime(String? mime) {
  final value = (mime ?? '').toLowerCase().trim();
  // Browser microphone recordings can be detected by PHP/finfo as video/mp4
  // or video/webm even though they contain an audio track only.
  return value.startsWith('audio/') || value.startsWith('video/');
}

String _audioPlaybackMime(String? mime) {
  final value = (mime ?? '').toLowerCase().trim();
  if (value == 'video/mp4') return 'audio/mp4';
  if (value == 'video/webm') return 'audio/webm';
  return value.isEmpty ? 'audio/mpeg' : value;
}

class _AiMaintenanceScreenState extends State<AiMaintenanceScreen> {
  static const _gold = Color(0xFFD4A02A);
  static const _dark = Color(0xFF202020);

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();
  final _recorder = AudioRecorder();

  Customer? _customer;
  AiCatalog? _catalog;
  AiAppConfig _appConfig = AiAppConfig.defaults();
  AiMachine? _machine;
  bool _askMachine = false;
  bool _hasMore = false;
  int? _oldestId;
  Map<String, String>? _pending;
  List<Map<String, dynamic>> _conversations = [];
  bool _loading = true;
  bool _sending = false;
  bool _recording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  String _sessionId = '';
  final List<_AiMessage> _messages = [];

  bool get _ar => AppController.isArabic;
  String t(String ar, String en) => _ar ? ar : en;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _recorder.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final customer = await CustomerSession.getCustomer();
      final config =
          widget.appConfig ?? await AiAssistantService.getAppConfig();
      if (customer == null || customer.authToken.trim().isEmpty) {
        if (!mounted) return;
        setState(() {
          _customer = null;
          _appConfig = config;
          _loading = false;
        });
        return;
      }
      final catalog = await AiAssistantService.getCatalog();
      if (!mounted) return;
      setState(() {
        _customer = customer;
        _catalog = catalog;
        _appConfig = config;
      });
      final result = await _conversationRequest('list');
      final rows = result['conversations'] as List;
      if (rows.isNotEmpty) {
        await _openConversation('${rows.first['id']}');
      } else {
        await _newConversation();
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('$e');
    }
  }

  Future<Map<String, dynamic>> _conversationRequest(
    String action, [
    Map<String, String> fields = const {},
  ]) async {
    final customer = _customer;
    if (customer == null) throw Exception('Please sign in');
    return AiAssistantService.conversations(
      authToken: customer.authToken,
      deviceId: await CustomerSession.getOrCreateDeviceId(),
      action: action,
      fields: fields,
    );
  }

  void _applyConversation(Map<String, dynamic> c) {
    _sessionId = '${c['id']}';
    final id = int.tryParse('${c['machine_id']}');
    _machine = null;
    for (final m in _catalog?.machines ?? <AiMachine>[]) {
      if (m.id == id) _machine = m;
    }
    _askMachine = '${c['ask_machine']}' == '1' && _machine == null;
  }

  Future<void> _openConversation(String id) async {
    final result = await _conversationRequest('messages', {
      'conversation_id': id,
    });
    if (!mounted) return;
    final rows = List<Map<String, dynamic>>.from(
      (result['messages'] as List).map((e) => Map<String, dynamic>.from(e)),
    );
    setState(() {
      _applyConversation(Map<String, dynamic>.from(result['conversation']));
      _messages.clear();
      _messages.addAll(rows.map(_storedMessage));
      _hasMore = result['has_more'] == true;
      _oldestId = rows.isEmpty ? null : int.tryParse('${rows.first['id']}');
      _pending = null;
      if (rows.isNotEmpty &&
          rows.last['role'] == 'user' &&
          rows.last['request_id'] != 'legacy') {
        _pending = {
          'request_id': '${rows.last['request_id']}',
          'message': '${rows.last['content'] ?? ''}',
        };
      }
    });
    _scrollBottom();
  }

  _AiMessage _storedMessage(Map<String, dynamic> row) {
    Map<String, dynamic> metadata = {};
    try {
      if (row['response_json'] is String)
        metadata = Map<String, dynamic>.from(jsonDecode(row['response_json']));
    } catch (_) {}
    final mediaMime = row['media_mime'] as String?;
    final isVoice = _isVoiceMime(mediaMime);
    final fromUser = row['role'] == 'user';
    return _AiMessage(
      id: int.tryParse('${row['id']}'),
      mediaMime: mediaMime,
      fromUser: fromUser,
      sourceType: '${metadata['source_type'] ?? ''}',
      confidence: double.tryParse('${metadata['confidence'] ?? 0}') ?? 0,
      // Keep the transcript on the server for AI context, but present voice
      // messages as audio bubbles instead of exposing the transcription.
      text: isVoice && fromUser
          ? t('رسالة صوتية', 'Voice message')
          : '${row['content'] ?? ''}'.isNotEmpty
          ? '${row['content']}'
          : ('${row['media_mime']}'.startsWith('image/')
              ? t('📷 صورة', '📷 Image')
              : t('🎤 تسجيل صوتي', '🎤 Voice message')),
    );
  }

  Future<Uint8List> _attachmentBytes(_AiMessage message) async {
    if (message.id == null || _customer == null) {
      throw Exception(t('تعذر فتح التسجيل.', 'Could not open recording.'));
    }
    return AiAssistantService.attachment(
      authToken: _customer!.authToken,
      deviceId: await CustomerSession.getOrCreateDeviceId(),
      conversationId: _sessionId,
      messageId: message.id!,
    );
  }

  Future<void> _openAttachment(_AiMessage message) async {
    if (message.id == null || _customer == null || _sending) return;
    setState(() => _sending = true);
    try {
      final bytes = await AiAssistantService.attachment(
        authToken: _customer!.authToken,
        deviceId: await CustomerSession.getOrCreateDeviceId(),
        conversationId: _sessionId,
        messageId: message.id!,
      );
      if (!mounted) return;
      final preview = InteractiveViewer(child: Image.memory(bytes));
      await showModalBottomSheet<void>(
        context: context,
        builder: (_) => SafeArea(child: SizedBox(height: 350, child: preview)),
      );
    } catch (e) {
      _showError('$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _loadOlder() async {
    if (_oldestId == null || _sending) return;
    setState(() => _sending = true);
    try {
      final result = await _conversationRequest('messages', {
        'conversation_id': _sessionId,
        'before_id': '$_oldestId',
      });
      if (!mounted) return;
      final rows = List<Map<String, dynamic>>.from(
        (result['messages'] as List).map((e) => Map<String, dynamic>.from(e)),
      );
      setState(() {
        _messages.insertAll(0, rows.map(_storedMessage));
        _hasMore = result['has_more'] == true;
        if (rows.isNotEmpty) _oldestId = int.tryParse('${rows.first['id']}');
      });
    } catch (e) {
      _showError('$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _newConversation() async {
    if (_sending || _recording) return;
    setState(() => _sending = true);
    try {
      final result = await _conversationRequest('create');
      if (!mounted) return;
      setState(() {
        _applyConversation(Map<String, dynamic>.from(result['conversation']));
        _messages.clear();
        _pending = null;
        _hasMore = false;
        _oldestId = null;
        _messageController.clear();
      });
    } catch (e) {
      _showError('$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _showHistory() async {
    if (_sending || _recording) return;
    setState(() => _sending = true);
    try {
      final result = await _conversationRequest('list');
      if (!mounted) return;
      _conversations = List<Map<String, dynamic>>.from(
        (result['conversations'] as List).map(
          (e) => Map<String, dynamic>.from(e),
        ),
      );
      final selected = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, update) => SafeArea(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * .75,
              child: ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      t('المحادثات السابقة', 'Previous conversations'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ..._conversations.map(
                    (c) => ListTile(
                      title: Text(
                        '${c['title']}'.isEmpty
                            ? t('محادثة جديدة', 'New conversation')
                            : '${c['title']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${c['last_message'] ?? ''}\n${c['updated_at']} • ${c['model_code'] ?? t('الموديل غير محدد', 'Model not selected')}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => Navigator.pop(sheetContext, '${c['id']}'),
                    ),
                  ),
                  if (_conversations.length % 50 == 0 &&
                      _conversations.isNotEmpty)
                    TextButton(
                      onPressed: () async {
                        try {
                          final more = await _conversationRequest('list', {
                            'offset': '${_conversations.length}',
                          });
                          if (sheetContext.mounted)
                            update(
                              () => _conversations.addAll(
                                (more['conversations'] as List).map(
                                  (e) => Map<String, dynamic>.from(e),
                                ),
                              ),
                            );
                        } catch (e) {
                          _showError('$e');
                        }
                      },
                      child: Text(t('تحميل المزيد', 'Load more')),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      if (selected != null) await _openConversation(selected);
    } catch (e) {
      _showError('$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _selectMachine(AiMachine machine) async {
    if (_sending || _recording) return;
    setState(() => _sending = true);
    try {
      final result = await _conversationRequest('select_machine', {
        'conversation_id': _sessionId,
        'machine_id': '${machine.id}',
      });
      if (mounted)
        setState(
          () => _applyConversation(
            Map<String, dynamic>.from(result['conversation']),
          ),
        );
    } catch (e) {
      _showError('$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendText() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending || _pending != null) return;
    _messageController.clear();
    setState(() => _messages.add(_AiMessage(fromUser: true, text: text)));
    _scrollBottom();
    await _sendToAi(action: 'diagnose', message: text);
  }

  Future<void> _sendImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 82,
      maxWidth: 1800,
    );
    if (image == null || !mounted || _sending || _pending != null) return;
    setState(
      () => _messages.add(
        _AiMessage(
          fromUser: true,
          text: t('📷 تم إرسال صورة للعطل', '📷 Fault image sent'),
        ),
      ),
    );
    _scrollBottom();
    await _sendToAi(
      action: 'diagnose',
      imagePath: image.path,
    );
  }

  Future<void> _toggleRecording() async {
    try {
      await _toggleRecordingImpl();
    } catch (e) {
      _recordTimer?.cancel();
      if (mounted) setState(() { _recording = false; _recordSeconds = 0; });
      _showError('$e');
    }
  }

  Future<void> _toggleRecordingImpl() async {
    if (_recording) {
      final path = await _recorder.stop();
      if (!mounted) return;
      _recordTimer?.cancel();
      setState(() {
        _recording = false;
        _recordSeconds = 0;
      });
      if (path != null && path.isNotEmpty) {
        setState(
          () => _messages.add(
            _AiMessage(
              fromUser: true,
              text: '',
              mediaMime: kIsWeb ? 'audio/webm' : 'audio/mp4',
            ),
          ),
        );
        _scrollBottom();
        await _sendToAi(action: 'diagnose', audioPath: path);
      }
      return;
    }

    final allowed = await _recorder.hasPermission();
    if (!mounted) return;
    if (!allowed) {
      _showError(
        t(
          'يجب السماح باستخدام الميكروفون.',
          'Microphone permission is required.',
        ),
      );
      return;
    }
    // The web recorder ignores the path and returns a blob URL from stop().
    // path_provider has no web implementation, so only use it on mobile.
    final path = kIsWeb
        ? ''
        : '${(await getTemporaryDirectory()).path}/fce_ai_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordSeconds++);
    });
    if (mounted) setState(() => _recording = true);
  }

  Future<void> _sendToAi({
    required String action,
    String message = '',
    String? imagePath,
    String? audioPath,
  }) async {
    final customer = _customer;
    if (customer == null || customer.authToken.trim().isEmpty) {
      _showError(
        t(
          'يجب تسجيل الدخول لاستخدام مساعد الصيانة.',
          'Please login to use the maintenance assistant.',
        ),
      );
      return;
    }

    _pending ??= {
      // DateTime microseconds are unique enough for a client request id and
      // work consistently on Android, iOS, and Flutter Web.
      'request_id': '${DateTime.now().microsecondsSinceEpoch}_0',
      'message': message,
      if (imagePath != null) 'image': imagePath,
      if (audioPath != null) 'audio': audioPath,
    };
    setState(() => _sending = true);
    try {
      final deviceId = await CustomerSession.getOrCreateDeviceId();
      final reply = await AiAssistantService.send(
        authToken: customer.authToken,
        deviceId: deviceId,
        action: action,
        machineId: _machine?.id,
        requestId: _pending!['request_id']!,
        appLanguage: AppController.language.value,
        message: message,
        sessionId: _sessionId,
        imagePath: imagePath,
        audioPath: audioPath,
      );
      if (reply.askMachine ||
          (reply.machineId != null &&
              !_catalog!.machines.any((m) => m.id == reply.machineId))) {
        final catalog = await AiAssistantService.getCatalog();
        if (!mounted) return;
        _catalog = catalog;
      }
      if (!mounted) return;
      setState(() {
        if (reply.caseId.isNotEmpty) _sessionId = reply.caseId;
        _askMachine = reply.askMachine;
        for (final m in _catalog?.machines ?? <AiMachine>[]) {
          if (m.id == reply.machineId) _machine = m;
        }
        _pending = null;
        _messages.add(
          _AiMessage(
            fromUser: false,
            text: reply.message,
            sourceType: reply.sourceType,
            confidence: reply.confidence,
          ),
        );
      });
      await _openConversation(_sessionId);
      _scrollBottom();
    } catch (e) {
      _showError('$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  void _showError(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppController.direction,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: _dark,
          foregroundColor: Colors.white,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _ar ? _appConfig.titleAr : _appConfig.titleEn,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (_machine != null)
                Text(
                  _machine!.modelCode,
                  style: const TextStyle(fontSize: 11, color: _gold),
                ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: (_sending || _recording) ? null : _showHistory,
              tooltip: t('المحادثات السابقة', 'History'),
              icon: const Icon(Icons.history),
            ),
            IconButton(
              onPressed: (_sending || _recording) ? null : _newConversation,
              tooltip: t('محادثة جديدة', 'New conversation'),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _gold))
            : _customer == null || _customer!.authToken.trim().isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.lock_person_rounded,
                            color: _gold,
                            size: 64,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            t('أنشئ حساب أولاً', 'Create an account first'),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: _dark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            t(
                              'يجب تسجيل الدخول قبل استخدام مساعد FCE الذكي.',
                              'You must sign in before using FCE AI Assistant.',
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _dark,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(t('رجوع', 'Back')),
                          ),
                        ],
                      ),
                    ),
                  )
                : _catalog == null
                    ? Center(
                        child: Text(
                          t(
                            'تعذر تحميل إعدادات الماكينات.',
                            'Could not load machine settings.',
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          if (_hasMore)
                            TextButton(
                              onPressed: _sending ? null : _loadOlder,
                              child: Text(t('رسائل أقدم', 'Older messages')),
                            ),
                          Expanded(child: _chatStep()),
                          if (_askMachine)
                            SizedBox(height: 150, child: _machineStep()),
                          if (_pending != null && !_sending)
                            TextButton.icon(
                              onPressed: () => _sendToAi(
                                action: 'diagnose',
                                message: _pending!['message'] ?? '',
                                imagePath: _pending!['image'],
                                audioPath: _pending!['audio'],
                              ),
                              icon: const Icon(Icons.refresh),
                              label: Text(
                                t('إعادة محاولة إرسال الرسالة',
                                    'Retry message'),
                              ),
                            ),
                          if (_readyForChat) _buildComposer(),
                          if (!_readyForChat)
                            TextButton(
                              onPressed: _init,
                              child: Text(t('إعادة المحاولة', 'Retry')),
                            ),
                        ],
                      ),
      ),
    );
  }

  bool get _readyForChat => _sessionId.isNotEmpty;

  Widget _stepShell({
    required String number,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: _gold,
                shape: BoxShape.circle,
              ),
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: _dark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: _dark.withOpacity(.62),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        child,
      ],
    );
  }

  Widget _machineStep() {
    final machines = _catalog!.machines;
    return _stepShell(
      number: '1',
      title: t('ما هو موديل ماكينتك؟', 'What is your machine model?'),
      subtitle: t(
        'اختر موديل ماكينة FCE من القائمة.',
        'Choose your FCE machine model.',
      ),
      child: machines.isEmpty
          ? Text(
              t(
                'لم تتم إضافة موديلات بعد. أضفها من الداشبورد.',
                'No machine models have been added yet. Add them from the dashboard.',
              ),
            )
          : Column(
              children: machines.map((machine) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: _dark,
                      child: Icon(
                        Icons.precision_manufacturing_rounded,
                        color: _gold,
                      ),
                    ),
                    title: Text(
                      _ar ? machine.nameAr : machine.nameEn,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      [
                        machine.modelCode,
                        machine.controller,
                      ].where((e) => e.trim().isNotEmpty).join(' • '),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _sending ? null : () => _selectMachine(machine),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _chatStep() {
    if (_messages.isEmpty) {
      _messages.add(
        _AiMessage(
          fromUser: false,
          text: _ar ? _appConfig.welcomeAr : _appConfig.welcomeEn,
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 22),
      itemCount: _messages.length + (_sending ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _messages.length) {
          return const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(color: _gold, strokeWidth: 2),
            ),
          );
        }
        final m = _messages[index];
        return m.fromUser ? _userBubble(m) : _assistantBubble(m);
      },
    );
  }

  Widget _userBubble(_AiMessage m) {
    final isVoice = _isVoiceMime(m.mediaMime);
    return Align(
      alignment: _ar ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        constraints: const BoxConstraints(maxWidth: 330),
        decoration: BoxDecoration(
          color: _gold,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isVoice)
              if (m.id != null)
                _VoiceMessagePlayer(
                  loadBytes: () => _attachmentBytes(m),
                  mimeType: _audioPlaybackMime(m.mediaMime),
                  errorText: t(
                    'تعذر تشغيل التسجيل الصوتي.',
                    'Could not play the voice message.',
                  ),
                )
              else
                const _PendingVoiceMessage()
            else
              Text(
                m.text,
                style: const TextStyle(
                  color: Colors.white,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (!isVoice && m.mediaMime != null && m.id != null)
              TextButton.icon(
                onPressed: _sending ? null : () => _openAttachment(m),
                icon: Icon(
                  Icons.image,
                  color: Colors.white,
                ),
                label: Text(
                  t('فتح الصورة', 'Open image'),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _assistantBubble(_AiMessage m) {
    final hasVoice = _isVoiceMime(m.mediaMime) && m.id != null;
    return Align(
      alignment: _ar ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                const Icon(Icons.smart_toy_rounded, color: _gold, size: 18),
                const SizedBox(width: 6),
                Text(
                  'FCE AI',
                  style: TextStyle(
                    color: _dark.withOpacity(.7),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            if (hasVoice) ...[
              const SizedBox(height: 10),
              _VoiceMessagePlayer(
                loadBytes: () => _attachmentBytes(m),
                mimeType: _audioPlaybackMime(m.mediaMime),
                errorText: t(
                  'تعذر تشغيل الرد الصوتي.',
                  'Could not play the voice reply.',
                ),
                assistantStyle: true,
              ),
            ],
            const SizedBox(height: 8),
            Text(m.text, style: const TextStyle(color: _dark, height: 1.5)),
            if (m.sourceType.isNotEmpty) ...[
              const SizedBox(height: 9),
              Text(
                '${t('المصدر', 'Source')}: ${m.sourceType}${m.confidence > 0 ? ' • ${(m.confidence * 100).clamp(0, 100).toStringAsFixed(0)}%' : ''}',
                style: TextStyle(
                  fontSize: 11,
                  color: _dark.withOpacity(.5),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x16000000),
              blurRadius: 14,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: (_sending || _recording || _pending != null)
                  ? null
                  : _sendImage,
              icon: const Icon(Icons.camera_alt_outlined, color: _gold),
            ),
            IconButton(
              onPressed:
                  (_sending || _pending != null) ? null : _toggleRecording,
              icon: Icon(
                _recording ? Icons.stop_circle_rounded : Icons.mic_rounded,
                color: _recording ? Colors.red : _gold,
              ),
            ),
            if (_recording)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '$_recordSeconds s',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            Expanded(
              child: TextField(
                controller: _messageController,
                enabled: !_recording,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: t('اكتب وصف العطل...', 'Describe the fault...'),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: (_sending || _recording || _pending != null)
                  ? null
                  : _sendText,
              icon: const Icon(Icons.send_rounded, color: _dark),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingVoiceMessage extends StatelessWidget {
  const _PendingVoiceMessage();

  @override
  Widget build(BuildContext context) {
    const heights = <double>[
      12, 20, 28, 17, 34, 24, 14, 30, 38, 22, 16, 32, 26, 13,
      23, 36, 19, 29, 15, 33, 25, 18, 37, 21,
    ];
    return SizedBox(
      width: 280,
      child: Row(
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: Padding(
              padding: EdgeInsets.all(10),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: SizedBox(
              height: 42,
              child: Row(
                children: heights
                    .map(
                      (height) => Expanded(
                        child: Container(
                          height: height,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.mic_rounded, color: Colors.white, size: 20),
        ],
      ),
    );
  }
}

class _VoiceMessagePlayer extends StatefulWidget {
  final Future<Uint8List> Function() loadBytes;
  final String mimeType;
  final String errorText;
  final bool assistantStyle;

  const _VoiceMessagePlayer({
    required this.loadBytes,
    required this.mimeType,
    required this.errorText,
    this.assistantStyle = false,
  });

  @override
  State<_VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<_VoiceMessagePlayer> {
  final AudioPlayer _player = AudioPlayer();
  Uint8List? _bytes;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  PlayerState _state = PlayerState.stopped;
  bool _loading = false;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _subscriptions.add(_player.onPlayerStateChanged.listen(
      (value) {
        if (mounted) setState(() => _state = value);
      },
      onError: _handleStreamError,
    ));
    _subscriptions.add(_player.onDurationChanged.listen(
      (value) {
        if (mounted) setState(() => _duration = value);
      },
      onError: _handleStreamError,
    ));
    _subscriptions.add(_player.onPositionChanged.listen(
      (value) {
        if (mounted) setState(() => _position = value);
      },
      onError: _handleStreamError,
    ));
    _subscriptions.add(_player.onPlayerComplete.listen(
      (_) {
        if (mounted) {
          setState(() {
            _state = PlayerState.completed;
            _position = Duration.zero;
          });
        }
      },
      onError: _handleStreamError,
    ));
  }

  void _handleStreamError(Object _) {
    if (mounted) setState(() => _state = PlayerState.stopped);
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_loading) return;
    try {
      if (_state == PlayerState.playing) {
        await _player.pause();
        return;
      }
      if (_state == PlayerState.paused) {
        await _player.resume();
        return;
      }
      setState(() => _loading = true);
      _bytes ??= await widget.loadBytes();
      await _player.play(
        BytesSource(_bytes!, mimeType: widget.mimeType),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.errorText)),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _time(Duration value) {
    final seconds = value.inSeconds.clamp(0, 3599);
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final waveformColor =
        widget.assistantStyle ? const Color(0xFFD4A02A) : Colors.white;
    final inactiveColor = widget.assistantStyle
        ? const Color(0xFFD4A02A).withOpacity(.32)
        : Colors.white.withOpacity(.46);
    final buttonColor =
        widget.assistantStyle ? const Color(0xFFD4A02A) : Colors.white;
    final iconColor =
        widget.assistantStyle ? Colors.white : const Color(0xFFD4A02A);
    final labelColor =
        widget.assistantStyle ? const Color(0xFF202020) : Colors.white;
    final totalMs = _duration.inMilliseconds;
    final progress = totalMs <= 0
        ? 0.0
        : (_position.inMilliseconds / totalMs).clamp(0.0, 1.0);
    const heights = <double>[
      12, 20, 28, 17, 34, 24, 14, 30, 38, 22, 16, 32, 26, 13,
      23, 36, 19, 29, 15, 33, 25, 18, 37, 21, 14, 28, 35, 17,
    ];
    final activeBars = (progress * heights.length).round();

    return SizedBox(
      width: 280,
      child: Row(
        children: [
          Material(
            color: buttonColor,
            shape: const CircleBorder(),
            child: IconButton(
              onPressed: _toggle,
              icon: _loading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: iconColor,
                      ),
                    )
                  : Icon(
                      _state == PlayerState.playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: iconColor,
                    ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 42,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: List.generate(heights.length, (index) {
                      return Expanded(
                        child: Container(
                          height: heights[index],
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: index < activeBars
                                ? waveformColor
                                : inactiveColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                Text(
                  _duration == Duration.zero
                      ? '0:00'
                      : '${_time(_position)} / ${_time(_duration)}',
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.graphic_eq_rounded, color: waveformColor, size: 20),
        ],
      ),
    );
  }
}
