import 'package:flutter/material.dart';

class ReliableNetworkImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget fallback;
  final Color loadingColor;
  final int maxRetries;

  const ReliableNetworkImage({
    super.key,
    required this.imageUrl,
    required this.fallback,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
    this.loadingColor = const Color(0xFFD4A02A),
    this.maxRetries = 2,
  });

  @override
  State<ReliableNetworkImage> createState() => _ReliableNetworkImageState();
}

class _ReliableNetworkImageState extends State<ReliableNetworkImage> {
  int _attempt = 0;
  bool _retryScheduled = false;

  @override
  void didUpdateWidget(covariant ReliableNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.imageUrl.trim() != widget.imageUrl.trim()) {
      _attempt = 0;
      _retryScheduled = false;
    }
  }

  String _cleanUrl(String value) {
    var url = value.trim();

    if (url.startsWith('http://365hub.site/')) {
      url = url.replaceFirst('http://365hub.site/', 'https://365hub.site/');
    }

    final uri = Uri.tryParse(url);
    return uri?.toString() ?? url;
  }

  String _requestUrl(String cleanUrl) {
    if (_attempt == 0) return cleanUrl;

    final separator = cleanUrl.contains('?') ? '&' : '?';
    return '$cleanUrl${separator}retry=$_attempt';
  }

  int? _decodeDimension(double value, double devicePixelRatio) {
    if (!value.isFinite || value <= 0) return null;

    final pixels = (value * devicePixelRatio).round();
    return pixels.clamp(1, 1600);
  }

  void _scheduleRetry() {
    if (_attempt >= widget.maxRetries || _retryScheduled) return;

    _retryScheduled = true;
    final delay = Duration(milliseconds: 750 + (_attempt * 700));

    Future<void>.delayed(delay, () {
      if (!mounted) return;

      setState(() {
        _attempt += 1;
        _retryScheduled = false;
      });
    });
  }

  Widget _loadingIndicator() {
    return Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          color: widget.loadingColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cleanUrl = _cleanUrl(widget.imageUrl);

    if (cleanUrl.isEmpty) {
      return widget.fallback;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final devicePixelRatio =
            MediaQuery.devicePixelRatioOf(context).clamp(1.0, 3.0);

        final logicalWidth = widget.width ??
            (constraints.maxWidth.isFinite ? constraints.maxWidth : 0);
        final logicalHeight = widget.height ??
            (constraints.maxHeight.isFinite ? constraints.maxHeight : 0);

        return Image.network(
          _requestUrl(cleanUrl),
          key: ValueKey<String>('${cleanUrl}_$_attempt'),
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          cacheWidth: _decodeDimension(logicalWidth, devicePixelRatio),
          cacheHeight: _decodeDimension(logicalHeight, devicePixelRatio),
          headers: const {
            'Accept': 'image/*',
            'User-Agent': 'FAD-CNC-App',
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _loadingIndicator();
          },
          errorBuilder: (context, error, stackTrace) {
            if (_attempt < widget.maxRetries) {
              _scheduleRetry();
              return _loadingIndicator();
            }

            return widget.fallback;
          },
        );
      },
    );
  }
}
