import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'models.dart';
import 'payflux_client.dart';

/// Razorpay-style in-app checkout modal that renders the Payflux Checkout
/// directly inside an in-app overlay sheet without opening an external browser.
class PayfluxCheckoutModal extends StatefulWidget {
  final String orderId;
  final String checkoutToken;
  final PayfluxConfig config;

  const PayfluxCheckoutModal({
    super.key,
    required this.orderId,
    required this.checkoutToken,
    required this.config,
  });

  static Future<PaymentResult> open({
    required BuildContext context,
    required String orderId,
    required String checkoutToken,
    required PayfluxConfig config,
  }) async {
    final result = await showModalBottomSheet<PaymentResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      builder: (ctx) => PayfluxCheckoutModal(
        orderId: orderId,
        checkoutToken: checkoutToken,
        config: config,
      ),
    );

    return result ??
        PaymentResult(
          orderId: orderId,
          status: PaymentStatus.cancelled,
          message: 'Checkout closed by user.',
        );
  }

  @override
  State<PayfluxCheckoutModal> createState() => _PayfluxCheckoutModalState();
}

class _PayfluxCheckoutModalState extends State<PayfluxCheckoutModal> {
  late final WebViewController _controller;
  bool _isLoading = true;
  double _loadingProgress = 0.0;
  bool _isDisposed = false;
  PaymentResult? _finalResult;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _initWebView();
    _startBackgroundPolling();
  }

  void _initWebView() {
    final checkoutUrl = '${widget.config.baseUrl}/checkout/${Uri.encodeComponent(widget.orderId)}?token=${Uri.encodeQueryComponent(widget.checkoutToken)}&embedded=true';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0F172A))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!_isDisposed) {
              setState(() {
                _loadingProgress = progress / 100.0;
              });
            }
          },
          onPageStarted: (url) {
            if (!_isDisposed) {
              setState(() {
                _isLoading = true;
              });
            }
          },
          onPageFinished: (url) {
            if (!_isDisposed) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            final uri = Uri.parse(request.url);

            // Intercept UPI intents (PhonePe, GPay, Paytm, BHIM, etc.)
            if (uri.scheme == 'upi' ||
                uri.scheme == 'phonepe' ||
                uri.scheme == 'paytm' ||
                uri.scheme == 'gpay' ||
                uri.scheme == 'bhim') {
              _launchUpiApp(uri);
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(checkoutUrl));
  }

  Future<void> _launchUpiApp(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Fallback
    }
  }

  void _startBackgroundPolling() {
    final client = PayfluxClient(widget.config);

    client
        .pollPaymentStatus(
      orderId: widget.orderId,
      checkoutToken: widget.checkoutToken,
    )
        .then((result) {
      if (!_isDisposed &&
          (result.status == PaymentStatus.success ||
              result.status == PaymentStatus.failed ||
              result.status == PaymentStatus.expired)) {
        _finalResult = result;
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop(result);
        }
      }
    });
  }

  Future<bool> _handleWillPop() async {
    final shouldClose = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Cancel Payment?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to cancel this payment session?',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('NO, CONTINUE', style: TextStyle(color: Color(0xFF38BDF8))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('YES, CANCEL'),
          ),
        ],
      ),
    );

    return shouldClose ?? false;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final sheetHeight = mediaQuery.size.height * 0.88;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldClose = await _handleWillPop();
        if (shouldClose && mounted) {
          Navigator.of(context).pop(
            _finalResult ??
                PaymentResult(
                  orderId: widget.orderId,
                  status: PaymentStatus.cancelled,
                  message: 'Payment cancelled by user.',
                ),
          );
        }
      },
      child: Container(
        height: sheetHeight,
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Column(
            children: [
              // Header bar like Razorpay
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  border: Border(
                    bottom: BorderSide(color: Color(0xFF334155), width: 1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.shield_rounded,
                            color: Color(0xFF38BDF8),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'PAYFLUX SECURE CHECKOUT',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '256-Bit Encrypted UPI Payment',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                      onPressed: () async {
                        final shouldClose = await _handleWillPop();
                        if (shouldClose && mounted) {
                          Navigator.of(context).pop(
                            PaymentResult(
                              orderId: widget.orderId,
                              status: PaymentStatus.cancelled,
                              message: 'Payment cancelled by user.',
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),

              // Linear Progress Bar
              if (_isLoading)
                LinearProgressIndicator(
                  value: _loadingProgress > 0 ? _loadingProgress : null,
                  backgroundColor: const Color(0xFF1E293B),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                  minHeight: 2.5,
                ),

              // WebView Content
              Expanded(
                child: WebViewWidget(controller: _controller),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
