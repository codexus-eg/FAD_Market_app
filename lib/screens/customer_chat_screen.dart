import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../app_controller.dart';
import '../services/api_service.dart';
import '../services/customer_session.dart';
import 'login_screen.dart';

class CustomerChatScreen extends StatefulWidget {
  const CustomerChatScreen({super.key});

  static const Color goldColor = Color(0xFFD4A02A);
  static const Color darkColor = Color(0xFF202020);
  static const Color bgColor = Color(0xFFF5F5F5);

  @override
  State<CustomerChatScreen> createState() => _CustomerChatScreenState();
}

class _CustomerChatScreenState extends State<CustomerChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _loading = true;
  bool _sending = false;
  bool _sendingFile = false;
  bool _loggedIn = false;
  String _error = '';
  List<Map<String, dynamic>> _messages = [];
  Timer? _timer;

  String tr(String ar, String en) => AppController.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _checkSessionAndLoad();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<_ChatDisplayItem> _displayItems() {
    final items = <_ChatDisplayItem>[];
    var index = 0;

    while (index < _messages.length) {
      final message = _messages[index];
      if (_chatIsImageMessage(message)) {
        final sender = '${message['sender_type'] ?? ''}';
        final group = <Map<String, dynamic>>[];
        var scan = index;
        while (scan < _messages.length &&
            _chatIsImageMessage(_messages[scan]) &&
            '${_messages[scan]['sender_type'] ?? ''}' == sender) {
          group.add(_messages[scan]);
          scan++;
        }

        if (group.length > 1) {
          items.add(_ChatDisplayItem(messages: group));
          index = scan;
          continue;
        }
      }

      items.add(_ChatDisplayItem(messages: [message]));
      index++;
    }

    return items;
  }

  Future<void> _checkSessionAndLoad() async {
    final logged = await CustomerSession.isLoggedIn();
    if (!mounted) return;

    setState(() {
      _loggedIn = logged;
      _loading = logged;
      _error = '';
    });

    if (logged) {
      await _loadMessages();
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 6), (_) => _loadMessages(silent: true));
    }
  }

  Future<void> _openLogin() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );

    if (result == true) {
      await _checkSessionAndLoad();
    }
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = '';
      });
    }

    try {
      final customer = await CustomerSession.getCustomer();
      if (customer == null || customer.authToken.trim().isEmpty) {
        throw Exception(tr('الرجاء تسجيل الدخول أولاً', 'Please login first'));
      }

      final deviceId = await CustomerSession.getOrCreateDeviceId();
      final data = await ApiService.getCustomerChat(
        authToken: customer.authToken,
        deviceId: deviceId,
      );

      if (!mounted) return;
      setState(() {
        _messages = data;
        _loading = false;
        _loggedIn = true;
        _error = '';
      });

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _loading = false;
          _error = tr(
            'تعذر تحميل الشات. يرجى التأكد من رفع تحديث لوحة التحكم ثم المحاولة مرة أخرى.',
            'Could not load chat. Upload the dashboard chat patch, then try again.',
          );
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending || _sendingFile) return;

    setState(() => _sending = true);

    try {
      final customer = await CustomerSession.getCustomer();
      if (customer == null || customer.authToken.trim().isEmpty) {
        throw Exception(tr('الرجاء تسجيل الدخول أولاً', 'Please login first'));
      }

      final deviceId = await CustomerSession.getOrCreateDeviceId();
      await ApiService.sendCustomerChatMessage(
        authToken: customer.authToken,
        deviceId: deviceId,
        message: text,
      );

      _messageController.clear();
      await _loadMessages(silent: true);
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendAttachment() async {
    if (_sending || _sendingFile) return;

    try {
      final picked = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.custom,
        allowedExtensions: const [
          'jpg', 'jpeg', 'png', 'webp', 'gif',
          'mp4', 'mov', 'webm',
          'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'zip',
        ],
      );

      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw Exception(tr('تعذر قراءة الملف.', 'Could not read the file.'));
      }
      if (bytes.length > 30 * 1024 * 1024) {
        throw Exception(tr('حجم الملف أكبر من المسموح.', 'File is too large.'));
      }

      setState(() => _sendingFile = true);

      final customer = await CustomerSession.getCustomer();
      if (customer == null || customer.authToken.trim().isEmpty) {
        throw Exception(tr('الرجاء تسجيل الدخول أولاً', 'Please login first'));
      }

      final deviceId = await CustomerSession.getOrCreateDeviceId();
      await ApiService.sendCustomerChatAttachment(
        authToken: customer.authToken,
        deviceId: deviceId,
        message: _messageController.text.trim(),
        fileName: file.name,
        fileBytes: bytes,
      );

      _messageController.clear();
      await _loadMessages(silent: true);
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sendingFile = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppController.language,
      builder: (context, lang, child) {
        return Directionality(
          textDirection: AppController.direction,
          child: Scaffold(
            backgroundColor: CustomerChatScreen.bgColor,
            appBar: AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 0,
              title: Text(
                tr('الشات', 'Chat'),
                style: const TextStyle(
                  color: CustomerChatScreen.darkColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
              iconTheme: const IconThemeData(color: CustomerChatScreen.darkColor),
              actions: [
                IconButton(
                  onPressed: () => _loadMessages(),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            body: !_loggedIn
                ? _LoginRequired(onLogin: _openLogin, tr: tr)
                : Column(
                    children: [
                      Expanded(
                        child: _loading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: CustomerChatScreen.goldColor,
                                ),
                              )
                            : _error.isNotEmpty
                                ? _ErrorState(error: _error, onRetry: _loadMessages, tr: tr)
                                : _messages.isEmpty
                                    ? _EmptyState(tr: tr)
                                    : Builder(
                                        builder: (context) {
                                          final items = _displayItems();
                                          return ListView.builder(
                                            controller: _scrollController,
                                            padding: const EdgeInsets.all(16),
                                            itemCount: items.length,
                                            itemBuilder: (context, index) {
                                              final item = items[index];
                                              final first = item.messages.first;
                                              final mine = '${first['sender_type'] ?? ''}' == 'customer';
                                              if (item.isImageGroup) {
                                                return _ImageGroupBubble(messages: item.messages, mine: mine, tr: tr);
                                              }
                                              return _MessageBubble(message: first, mine: mine, tr: tr);
                                            },
                                          );
                                        },
                                      ),
                      ),
                      _MessageComposer(
                        controller: _messageController,
                        sending: _sending,
                        sendingFile: _sendingFile,
                        onSend: _sendMessage,
                        onAttach: _sendAttachment,
                        tr: tr,
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _ChatDisplayItem {
  final List<Map<String, dynamic>> messages;
  const _ChatDisplayItem({required this.messages});

  bool get isImageGroup => messages.length > 1;
}

String _stringField(Map<String, dynamic> message, List<String> keys) {
  for (final key in keys) {
    final value = '${message[key] ?? ''}'.trim();
    if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
  }
  return '';
}

String _dashboardBaseUrl() => ApiService.baseUrl.replaceFirst(RegExp(r'/api$'), '');

String _normalizeChatUrl(String value) {
  var url = value.trim();
  if (url.isEmpty) return '';

  if (url.startsWith('//')) url = 'https:$url';
  if (url.startsWith('http://365hub.site/')) {
    url = url.replaceFirst('http://365hub.site/', 'https://365hub.site/');
  }
  if (url.startsWith('/')) {
    url = '${_dashboardBaseUrl()}$url';
  }
  if (!url.startsWith('http://') && !url.startsWith('https://')) {
    url = '${_dashboardBaseUrl()}/${url.replaceFirst(RegExp(r'^/+'), '')}';
  }

  try {
    return Uri.parse(Uri.encodeFull(url)).toString();
  } catch (_) {
    return url;
  }
}

String _chatAttachmentUrl(Map<String, dynamic> message) {
  final raw = _stringField(message, const [
    'attachment_stream_url',
    'attachment_preview_url',
    'inline_url',
    'preview_url',
    'attachment_url',
    'file_url',
    'media_url',
    'url',
    'download_url',
    'attachment_path',
    'file_path',
    'path',
  ]);
  return _normalizeChatUrl(raw);
}

String _chatAttachmentDownloadUrl(Map<String, dynamic> message) {
  final raw = _stringField(message, const [
    'attachment_download_url',
    'download_url',
    'attachment_stream_url',
    'attachment_url',
    'file_url',
    'media_url',
    'url',
    'attachment_path',
    'file_path',
    'path',
  ]);
  return _normalizeChatUrl(raw);
}

String _chatAttachmentName(Map<String, dynamic> message) => _stringField(message, const [
      'attachment_name',
      'file_name',
      'filename',
      'name',
      'original_name',
    ]);

String _chatAttachmentMime(Map<String, dynamic> message) => _stringField(message, const [
      'attachment_mime',
      'file_mime',
      'mime_type',
      'mime',
      'content_type',
    ]).toLowerCase();

String _chatMessageText(Map<String, dynamic> message) => '${message['message'] ?? ''}'.trim();
bool _chatHasAttachment(Map<String, dynamic> message) => _chatAttachmentUrl(message).isNotEmpty || _chatAttachmentName(message).isNotEmpty;

String _chatAttachmentProbe(Map<String, dynamic> message) {
  final values = <String>[
    _chatAttachmentName(message),
    _chatAttachmentUrl(message),
    '${message['attachment_path'] ?? ''}',
    '${message['file_path'] ?? ''}',
    '${message['path'] ?? ''}',
  ].where((value) => value.trim().isNotEmpty).join(' ');

  try {
    return Uri.decodeFull(values).toLowerCase();
  } catch (_) {
    return values.toLowerCase();
  }
}

bool _chatLooksLikeImage(Map<String, dynamic> message) {
  final mime = _chatAttachmentMime(message);
  if (mime.startsWith('image/') || mime.contains('image')) return true;

  final type = _stringField(message, const ['attachment_type', 'file_type', 'media_type', 'type']).toLowerCase();
  if (type == 'image' || type.contains('image')) return true;

  final probe = _chatAttachmentProbe(message);
  return RegExp(r'\.(jpg|jpeg|png|webp|gif)(?:$|[?&#\s])').hasMatch(probe) ||
      RegExp(r'(jpg|jpeg|png|webp|gif)(?:$|[?&#\s])').hasMatch(probe);
}

bool _chatLooksLikeVideo(Map<String, dynamic> message) {
  final mime = _chatAttachmentMime(message);
  if (mime.startsWith('video/') || mime.contains('video')) return true;

  final type = _stringField(message, const ['attachment_type', 'file_type', 'media_type', 'type']).toLowerCase();
  if (type == 'video' || type.contains('video')) return true;

  final probe = _chatAttachmentProbe(message);
  return RegExp(r'\.(mp4|mov|webm)(?:$|[?&#\s])').hasMatch(probe);
}

bool _chatIsImageMessage(Map<String, dynamic> message) => _chatHasAttachment(message) && _chatLooksLikeImage(message);
bool _chatIsVideoMessage(Map<String, dynamic> message) => _chatHasAttachment(message) && _chatLooksLikeVideo(message);

Future<void> _openUrlInsideApp(BuildContext context, String url, String Function(String ar, String en) tr) async {
  if (url.trim().isEmpty) return;
  final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('تعذر فتح الملف', 'Could not open file'))),
    );
  }
}

void _showImageViewer(
  BuildContext context,
  List<Map<String, dynamic>> messages,
  int initialIndex,
  String Function(String ar, String en) tr,
) {
  final controller = PageController(initialPage: initialIndex);
  var currentIndex = initialIndex;

  showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          final safeIndex = currentIndex.clamp(0, messages.length - 1).toInt();
          final current = messages[safeIndex];
          return Dialog(
            insetPadding: const EdgeInsets.all(12),
            backgroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.78,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: controller,
                    itemCount: messages.length,
                    onPageChanged: (index) => setState(() => currentIndex = index),
                    itemBuilder: (context, index) {
                      final url = _chatAttachmentUrl(messages[index]);
                      return InteractiveViewer(
                        child: Center(
                          child: _ChatImageBytes(
                            imageUrl: url,
                            fit: BoxFit.contain,
                            fallback: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.image_not_supported_rounded, color: Colors.white70, size: 52),
                                const SizedBox(height: 10),
                                Text(
                                  tr('تعذر عرض الصورة', 'Could not display image'),
                                  style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => _openUrlInsideApp(context, _chatAttachmentDownloadUrl(current), tr),
                          icon: const Icon(Icons.download_rounded, color: Colors.white),
                          tooltip: tr('تحميل', 'Download'),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close_rounded, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  if (messages.length > 1)
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${currentIndex + 1} / ${messages.length}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}


class _ChatImageBytes extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget fallback;

  const _ChatImageBytes({
    required this.imageUrl,
    required this.fallback,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  @override
  State<_ChatImageBytes> createState() => _ChatImageBytesState();
}

class _ChatImageBytesState extends State<_ChatImageBytes> {
  List<int>? _bytes;
  bool _loading = true;
  bool _failed = false;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _ChatImageBytes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl.trim() != widget.imageUrl.trim()) {
      _bytes = null;
      _loading = true;
      _failed = false;
      _attempt = 0;
      _load();
    }
  }

  Future<void> _load() async {
    final rawUrl = _normalizeChatUrl(widget.imageUrl);
    if (rawUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
      return;
    }

    try {
      var url = rawUrl;
      if (_attempt > 0) {
        final separator = url.contains('?') ? '&' : '?';
        url = '$url${separator}retry=$_attempt';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: const {
          'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
          'User-Agent': 'FAD-Market-App',
        },
      ).timeout(const Duration(seconds: 18));

      final contentType = (response.headers['content-type'] ?? '').toLowerCase();
      final body = response.bodyBytes;
      final okStatus = response.statusCode >= 200 && response.statusCode < 300;
      final looksLikeImage = contentType.startsWith('image/') || _bytesLookLikeImage(body);

      if (!okStatus || body.isEmpty || !looksLikeImage) {
        throw Exception('Image response is not valid');
      }

      if (!mounted) return;
      setState(() {
        _bytes = body;
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (_attempt < 2) {
        _attempt += 1;
        Future<void>.delayed(Duration(milliseconds: 650 + 450 * _attempt), () {
          if (mounted) _load();
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  static bool _bytesLookLikeImage(List<int> bytes) {
    if (bytes.length < 12) return false;
    // JPG
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;
    // PNG
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return true;
    // GIF
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return true;
    // WEBP: RIFF....WEBP
    if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
        bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: CustomerChatScreen.goldColor),
          ),
        ),
      );
    }

    if (_failed || _bytes == null) {
      return widget.fallback;
    }

    return Image.memory(
      Uint8List.fromList(_bytes!),
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) => widget.fallback,
    );
  }
}

class _LoginRequired extends StatelessWidget {
  final VoidCallback onLogin;
  final String Function(String ar, String en) tr;

  const _LoginRequired({required this.onLogin, required this.tr});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline, color: CustomerChatScreen.goldColor, size: 54),
            const SizedBox(height: 14),
            Text(
              tr('يرجى تسجيل الدخول لفتح الشات', 'Login to open chat'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: CustomerChatScreen.goldColor,
                foregroundColor: Colors.white,
              ),
              child: Text(tr('تسجيل الدخول', 'Login')),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String Function(String ar, String en) tr;

  const _EmptyState({required this.tr});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          tr('أدخل رسالتك وسنرد عليك من الشات', 'Write your message and we will reply from chat'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  final String Function(String ar, String en) tr;

  const _ErrorState({required this.error, required this.onRetry, required this.tr});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onRetry, child: Text(tr('إعادة المحاولة', 'Retry'))),
          ],
        ),
      ),
    );
  }
}

class _ImageGroupBubble extends StatelessWidget {
  final List<Map<String, dynamic>> messages;
  final bool mine;
  final String Function(String ar, String en) tr;

  const _ImageGroupBubble({required this.messages, required this.mine, required this.tr});

  @override
  Widget build(BuildContext context) {
    final shown = messages.take(3).toList();
    final hiddenCount = messages.length - shown.length;
    final size = MediaQuery.of(context).size.width * 0.56;
    final firstText = _chatMessageText(messages.first);

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: mine ? CustomerChatScreen.goldColor : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (firstText.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
                child: Text(
                  firstText,
                  style: TextStyle(
                    color: mine ? Colors.white : CustomerChatScreen.darkColor,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
                ),
              ),
            ],
            SizedBox(
              width: size,
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: shown.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemBuilder: (context, index) {
                  final url = _chatAttachmentUrl(shown[index]);
                  final isOverlay = index == shown.length - 1 && hiddenCount > 0;
                  return InkWell(
                    onTap: () => _showImageViewer(context, messages, index, tr),
                    borderRadius: BorderRadius.circular(12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _ChatImageBytes(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            fallback: Container(
                              color: Colors.black12,
                              child: const Icon(Icons.image_not_supported_rounded),
                            ),
                          ),
                          if (isOverlay)
                            Container(
                              color: Colors.black54,
                              child: Center(
                                child: Text(
                                  '+$hiddenCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 7),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${messages.length} ${tr('صور', 'images')}',
                  style: TextStyle(
                    color: mine ? Colors.white70 : Colors.black45,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${messages.last['created_at'] ?? ''}',
                  style: TextStyle(
                    color: mine ? Colors.white70 : Colors.black45,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool mine;
  final String Function(String ar, String en) tr;

  const _MessageBubble({required this.message, required this.mine, required this.tr});

  Future<void> _openAttachment(BuildContext context) async {
    final url = _chatAttachmentUrl(message);
    if (url.isEmpty) return;
    if (_chatIsImageMessage(message)) {
      _showImageViewer(context, [message], 0, tr);
      return;
    }
    await _openUrlInsideApp(context, url, tr);
  }

  @override
  Widget build(BuildContext context) {
    final text = _chatMessageText(message);
    final attachmentName = _chatAttachmentName(message);
    final attachmentUrl = _chatAttachmentUrl(message);
    final isImage = _chatIsImageMessage(message);
    final isVideo = _chatIsVideoMessage(message);
    final hasAttachment = _chatHasAttachment(message);

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: mine ? CustomerChatScreen.goldColor : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (text.isNotEmpty)
              Text(
                text,
                style: TextStyle(
                  color: mine ? Colors.white : CustomerChatScreen.darkColor,
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                ),
              ),
            if (hasAttachment) ...[
              if (text.isNotEmpty) const SizedBox(height: 8),
              InkWell(
                onTap: () => _openAttachment(context),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: mine ? Colors.white.withOpacity(0.15) : CustomerChatScreen.bgColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isImage && attachmentUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              _ChatImageBytes(
                                imageUrl: attachmentUrl,
                                width: 210,
                                height: 160,
                                fit: BoxFit.cover,
                                fallback: Container(
                                  width: 210,
                                  height: 160,
                                  color: Colors.black12,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.image_not_supported_rounded, color: Colors.black45, size: 34),
                                      const SizedBox(height: 6),
                                      Text(
                                        tr('تعذر عرض الصورة', 'Could not display image'),
                                        style: const TextStyle(color: Colors.black45, fontSize: 11, fontWeight: FontWeight.w800),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Container(
                                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  child: const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: Icon(Icons.open_in_full_rounded, color: Colors.white, size: 16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (isVideo)
                        SizedBox(
                          width: 190,
                          height: 110,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 42),
                                  const SizedBox(height: 6),
                                  Text(
                                    tr('فيديو مرفق', 'Attached video'),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.insert_drive_file_rounded, color: mine ? Colors.white : CustomerChatScreen.goldColor),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                attachmentName.isEmpty ? tr('ملف مرفق', 'Attachment') : attachmentName,
                                style: TextStyle(color: mine ? Colors.white : CustomerChatScreen.darkColor, fontWeight: FontWeight.w900),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              attachmentName.isEmpty
                                  ? (isImage ? tr('صورة مرفقة', 'Attached image') : tr('ملف مرفق', 'Attachment'))
                                  : attachmentName,
                              style: TextStyle(color: mine ? Colors.white : CustomerChatScreen.darkColor, fontWeight: FontWeight.w800, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (isImage || isVideo)
                            Icon(
                              isImage ? Icons.open_in_full_rounded : Icons.play_circle_fill_rounded,
                              color: mine ? Colors.white : CustomerChatScreen.goldColor,
                              size: 18,
                            ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                            tooltip: tr('تحميل', 'Download'),
                            onPressed: attachmentUrl.isEmpty ? null : () => _openUrlInsideApp(context, _chatAttachmentDownloadUrl(message), tr),
                            icon: Icon(Icons.download_rounded, color: mine ? Colors.white : CustomerChatScreen.goldColor, size: 18),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 5),
            Text(
              '${message['created_at'] ?? ''}',
              style: TextStyle(
                color: mine ? Colors.white70 : Colors.black45,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final bool sendingFile;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final String Function(String ar, String en) tr;

  const _MessageComposer({
    required this.controller,
    required this.sending,
    required this.sendingFile,
    required this.onSend,
    required this.onAttach,
    required this.tr,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: (sending || sendingFile) ? null : onAttach,
              tooltip: tr('إرفاق ملف', 'Attach file'),
              icon: sendingFile
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: CustomerChatScreen.goldColor))
                  : const Icon(Icons.attach_file_rounded, color: CustomerChatScreen.goldColor),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: tr('أدخل رسالتك...', 'Write your message...'),
                  filled: true,
                  fillColor: CustomerChatScreen.bgColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: (sending || sendingFile) ? null : onSend,
              style: ElevatedButton.styleFrom(
                backgroundColor: CustomerChatScreen.goldColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              ),
              child: sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
