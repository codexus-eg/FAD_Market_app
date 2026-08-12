// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

int _invoiceFrameCounter = 0;

Widget buildInvoiceWebIframe(String url) {
  final viewType = 'invoice-frame-${_invoiceFrameCounter++}';

  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final frame = html.IFrameElement()
      ..src = url
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = '#ffffff'
      ..allow = 'clipboard-read; clipboard-write; fullscreen'
      ..setAttribute('allowfullscreen', 'true')
      ..setAttribute('loading', 'eager');
    return frame;
  });

  return HtmlElementView(viewType: viewType);
}
