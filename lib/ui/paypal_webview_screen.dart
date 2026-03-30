import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config.dart';
import '../services/api.dart';

class PayPalWebViewScreen extends StatefulWidget {
  final int orderId;
  final String approvalUrl;

  const PayPalWebViewScreen({
    super.key,
    required this.orderId,
    required this.approvalUrl,
  });

  @override
  State<PayPalWebViewScreen> createState() => _PayPalWebViewScreenState();
}

class _PayPalWebViewScreenState extends State<PayPalWebViewScreen> {
  final _api = ApiClient();
  late final WebViewController _controller;
  bool _capturing = false;

  String get _returnPrefix => '${AppConfig.apiBaseUrl.replaceAll(RegExp(r'\/+$'), '')}/api/payments/paypal/return';
  String get _cancelPrefix => '${AppConfig.apiBaseUrl.replaceAll(RegExp(r'\/+$'), '')}/api/payments/paypal/cancel';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (req) async {
            final url = req.url;
            if (url.startsWith(_cancelPrefix)) {
              if (mounted) Navigator.of(context).pop(false);
              return NavigationDecision.prevent;
            }
            if (url.startsWith(_returnPrefix)) {
              await _capture();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.approvalUrl));
  }

  Future<void> _capture() async {
    if (_capturing) return;
    setState(() => _capturing = true);
    try {
      await _api.capturePayPal(orderId: widget.orderId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _capturing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PayPal Checkout'),
        actions: [
          IconButton(
            onPressed: _capturing ? null : () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.close),
          )
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_capturing)
            const ColoredBox(
              color: Color(0x88000000),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

