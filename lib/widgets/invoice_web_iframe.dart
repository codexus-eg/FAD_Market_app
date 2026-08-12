import 'package:flutter/widgets.dart';

import 'invoice_web_iframe_stub.dart'
    if (dart.library.html) 'invoice_web_iframe_web.dart';

class InvoiceWebIframe extends StatelessWidget {
  final String url;

  const InvoiceWebIframe({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return buildInvoiceWebIframe(url);
  }
}
