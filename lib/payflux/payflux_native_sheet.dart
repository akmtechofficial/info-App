import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'payflux_client.dart';

/// 100% Pure Native Flutter UPI Payment Sheet with Email Verification
/// Renders dynamic UPI QR code display, sender name entry, live countdown timer,
/// and email payment verification matching Web SDK.
class PayfluxNativeSheet extends StatefulWidget {
  final String orderId;
  final String checkoutToken;
  final double amount;
  final String? merchantName;
  final String? upiId;
  final String? mode;
  final String? customerName;
  final PayfluxConfig config;

  const PayfluxNativeSheet({
    super.key,
    required this.orderId,
    required this.checkoutToken,
    required this.amount,
    this.merchantName,
    this.upiId,
    this.mode,
    this.customerName,
    required this.config,
  });

  static Future<PaymentResult> show({
    required BuildContext context,
    required String orderId,
    required String checkoutToken,
    required double amount,
    String? merchantName,
    String? upiId,
    String? mode,
    String? customerName,
    required PayfluxConfig config,
  }) async {
    final result = await showModalBottomSheet<PaymentResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      builder: (ctx) => PayfluxNativeSheet(
        orderId: orderId,
        checkoutToken: checkoutToken,
        amount: amount,
        merchantName: merchantName,
        upiId: upiId,
        mode: mode,
        customerName: customerName,
        config: config,
      ),
    );

    return result ??
        PaymentResult(
          orderId: orderId,
          status: PaymentStatus.cancelled,
          message: 'Payment cancelled by user.',
        );
  }

  @override
  State<PayfluxNativeSheet> createState() => _PayfluxNativeSheetState();
}

class _PayfluxNativeSheetState extends State<PayfluxNativeSheet> {
  late final PayfluxClient _client;
  late final TextEditingController _senderNameController;

  bool _isDisposed = false;
  bool _isSuccess = false;
  bool _isVerifying = false;
  String? _verificationError;
  String? _successTxnId;
  int _secondsLeft = 300; // 5 minutes
  Timer? _countdownTimer;
  Timer? _pollingTimer;
  bool _copiedUpi = false;

  late String _vpa;
  late String _merchantName;

  String get _upiPayload =>
      'upi://pay?pa=$_vpa&pn=${Uri.encodeComponent(_merchantName)}&am=${widget.amount.toStringAsFixed(2)}&tr=${widget.orderId}&cu=INR';

  @override
  void initState() {
    super.initState();
    _client = PayfluxClient(widget.config);
    _senderNameController = TextEditingController(text: widget.customerName ?? '');
    _vpa = widget.upiId?.isNotEmpty == true ? widget.upiId! : '';
    _merchantName = widget.merchantName?.isNotEmpty == true ? widget.merchantName! : 'Payflux Merchant';
    _fetchLiveOrderDetails();
    _startCountdown();
    _startStatusPolling();
  }

  Future<void> _fetchLiveOrderDetails() async {
    final details = await _client.getOrderDetails(
      orderId: widget.orderId,
      checkoutToken: widget.checkoutToken,
    );
    if (details != null && !_isDisposed) {
      setState(() {
        final apiUpi = (details['upiId'] ?? details['payeeVpa'] ?? details['vpa'] ?? details['upi'] ?? details['merchantUpi'] ?? '').toString();
        final apiMerchant = (details['merchantName'] ?? details['businessName'] ?? details['merchant'] ?? '').toString();
        final apiName = (details['customerName'] ?? details['name'] ?? '').toString();

        if (apiUpi.isNotEmpty) {
          _vpa = apiUpi;
        }
        if (apiMerchant.isNotEmpty) {
          _merchantName = apiMerchant;
        }
        if (apiName.isNotEmpty && _senderNameController.text.isEmpty) {
          _senderNameController.text = apiName;
        }
      });
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        if (!_isDisposed) {
          setState(() {
            _secondsLeft--;
          });
        }
      } else {
        timer.cancel();
        if (!_isDisposed && !_isSuccess) {
          Navigator.of(context).pop(
            PaymentResult(
              orderId: widget.orderId,
              status: PaymentStatus.expired,
              message: 'Payment session expired.',
            ),
          );
        }
      }
    });
  }

  void _startStatusPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_isDisposed || _isSuccess || _isVerifying) return;

      final result = await _client.checkPaymentStatusOnce(
        orderId: widget.orderId,
        checkoutToken: widget.checkoutToken,
      );

      if (result != null && result.status == PaymentStatus.success && !_isDisposed && !_isSuccess) {
        _pollingTimer?.cancel();
        _triggerSuccess(result.transactionId ?? 'PF_${widget.orderId}');
      }
    });
  }

  Future<void> _verifyPaymentWithServer() async {
    final senderName = _senderNameController.text.trim();

    setState(() {
      _isVerifying = true;
      _verificationError = null;
    });

    try {
      final isTest = widget.mode == 'test' || widget.config.environment == PayfluxEnvironment.sandbox;
      final result = await _client.verifyPayment(
        orderId: widget.orderId,
        checkoutToken: widget.checkoutToken,
        senderName: senderName,
        simulateSuccess: isTest,
      );

      if (_isDisposed) return;

      if (result['success'] == true || result['status'] == 'SUCCESS' || result['status'] == 'success') {
        final txnId = result['transactionId'] ?? result['data']?['transactionId'] ?? 'PF_${DateTime.now().millisecondsSinceEpoch}';
        _triggerSuccess(txnId.toString());
      } else {
        setState(() {
          _isVerifying = false;
          _verificationError = result['message'] ?? result['error'] ?? 'Payment pending. Complete UPI transaction & retry.';
        });
      }
    } catch (e) {
      if (!_isDisposed) {
        setState(() {
          _isVerifying = false;
          _verificationError = 'Error verifying payment: ${e.toString()}';
        });
      }
    }
  }

  void _triggerSuccess(String txnId) {
    if (_isSuccess) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _isSuccess = true;
      _isVerifying = false;
      _successTxnId = txnId;
    });

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
        Navigator.of(context).pop(
          PaymentResult(
            orderId: widget.orderId,
            status: PaymentStatus.success,
            transactionId: txnId,
            amount: widget.amount,
          ),
        );
      }
    });
  }

  Future<void> _simulateTestSuccess() async {
    setState(() {
      _isVerifying = true;
      _verificationError = null;
    });

    try {
      final result = await _client.verifyPayment(
        orderId: widget.orderId,
        checkoutToken: widget.checkoutToken,
        senderName: _senderNameController.text.trim(),
        simulateSuccess: true,
      );

      if (_isDisposed) return;

      if (result['success'] == true || result['status'] == 'SUCCESS' || result['status'] == 'success') {
        final txnId = result['transactionId'] ?? result['data']?['transactionId'] ?? 'TEST_SIM_${DateTime.now().millisecondsSinceEpoch}';
        _triggerSuccess(txnId.toString());
      } else {
        setState(() {
          _isVerifying = false;
          _verificationError = result['message'] ?? 'Test simulation failed on server.';
        });
      }
    } catch (_) {
      if (!_isDisposed) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  void _copyUpiId() {
    Clipboard.setData(ClipboardData(text: _vpa));
    HapticFeedback.selectionClick();
    setState(() {
      _copiedUpi = true;
    });
    Timer(const Duration(milliseconds: 2000), () {
      if (!_isDisposed) {
        setState(() {
          _copiedUpi = false;
        });
      }
    });
  }

  String _formatTimer(int totalSecs) {
    final m = (totalSecs ~/ 60).toString().padLeft(2, '0');
    final s = (totalSecs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _isDisposed = true;
    _countdownTimer?.cancel();
    _pollingTimer?.cancel();
    _senderNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTest = kDebugMode && (widget.mode == 'test' || widget.config.environment == PayfluxEnvironment.sandbox);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black87,
              blurRadius: 30,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: _isSuccess ? _buildSuccessView() : _buildPaymentView(isTest),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF22C55E),
              size: 72,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Payment Verified!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${widget.amount.toStringAsFixed(2)} Paid Successfully',
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF38BDF8),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Ref: ${_successTxnId ?? "CONFIRMED"}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentView(bool isTest) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle bar
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),

        // Header Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.bolt_rounded, color: Color(0xFF38BDF8), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _merchantName.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.verified_user_rounded, color: Color(0xFF22C55E), size: 12),
                          const SizedBox(width: 4),
                          Text(
                            isTest ? 'TEST MODE' : 'UPI Instant Pay',
                            style: TextStyle(
                              fontSize: 11,
                              color: isTest ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${widget.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '⏱ ${_formatTimer(_secondsLeft)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: _secondsLeft < 60 ? const Color(0xFFEF4444) : const Color(0xFF38BDF8),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const Divider(color: Color(0xFF1E293B), height: 1),

        // Main Content (QR Code & Sender Name Input)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: _buildMainForm(isTest),
        ),

        // Bottom Action Bar & Status
        Container(
          margin: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.shield_rounded, color: Color(0xFF22C55E), size: 14),
                  SizedBox(width: 4),
                  Text(
                    '256-bit Encrypted SSL Security',
                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(40, 24),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainForm(bool isTest) {
    if (_vpa.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_verificationError == null) ...[
              const CircularProgressIndicator(color: Color(0xFF38BDF8), strokeWidth: 2.5),
              const SizedBox(height: 16),
              const Text(
                'Loading Merchant Payment VPA...',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              const Text(
                'Retrieving live UPI details from Payflux server',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
              ),
            ] else ...[
              const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 40),
              const SizedBox(height: 12),
              Text(
                _verificationError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF334155),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Close & Retry'),
              ),
            ],
          ],
        ),
      );
    }

    final qrUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=260x260&data=${Uri.encodeComponent(_upiPayload)}';

    return Column(
      children: [
        // Sender / Payer Name Input Field
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.person_rounded, color: Color(0xFF38BDF8), size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Sender / Payer Name',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _senderNameController,
                enabled: !_isVerifying,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g. Sima or Rahul Sharma',
                  hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF38BDF8)),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Auto-polling server status every 2s. Enter your name and tap button below to verify.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        const Text(
          'Scan QR Code with PhonePe, GPay, Paytm, or BHIM',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),

        // QR Code Container
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                blurRadius: 18,
              ),
            ],
          ),
          child: Image.network(
            qrUrl,
            width: 160,
            height: 160,
            fit: BoxFit.contain,
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return const SizedBox(
                width: 160,
                height: 160,
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.black)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),

        // Copyable UPI ID Row
        GestureDetector(
          onTap: _copyUpiId,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.alternate_email_rounded, color: Color(0xFF38BDF8), size: 14),
                const SizedBox(width: 6),
                Text(
                  _vpa,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Icon(
                  _copiedUpi ? Icons.check_circle_rounded : Icons.copy_rounded,
                  color: _copiedUpi ? const Color(0xFF22C55E) : const Color(0xFF94A3B8),
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  _copiedUpi ? 'Copied!' : 'Copy',
                  style: TextStyle(
                    color: _copiedUpi ? const Color(0xFF22C55E) : const Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),

        if (_verificationError != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFEF4444)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _verificationError!,
                    style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 14),

        // Primary Verification CTA Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isVerifying ? null : _verifyPaymentWithServer,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0EA5E9),
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isVerifying
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'VERIFYING WITH PAYFLUX SERVER...',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ],
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified_user_rounded, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'I HAVE PAID • VERIFY WITH PAYFLUX',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ],
                  ),
          ),
        ),

        // Test Simulation Button (If Test Mode)
        if (isTest) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: OutlinedButton.icon(
              onPressed: _isVerifying ? null : _simulateTestSuccess,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFF59E0B),
                side: const BorderSide(color: Color(0xFFF59E0B), width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.flash_on_rounded, size: 16),
              label: const Text(
                '⚡ SIMULATE PAYMENT SUCCESS (TEST MODE)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
