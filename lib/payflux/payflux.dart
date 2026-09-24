import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models.dart';
import 'payflux_client.dart';
import 'payflux_native_sheet.dart';
import 'payflux_checkout_modal.dart';

export 'models.dart';
export 'payflux_native_sheet.dart';
export 'payflux_checkout_modal.dart';

class Payflux {
  Payflux._();

  static PayfluxConfig _config = const PayfluxConfig();
  static PayfluxClient _client = PayfluxClient(_config);
  static bool _isProcessing = false;

  /// Initialize Payflux with environment configuration.
  static void initialize(PayfluxConfig config) {
    _config = config;
    _client = PayfluxClient(config);
  }

  /// Starts Payflux Checkout using Web Checkout / Web SDK.
  /// Launches Web Checkout URL and auto-polls backend status until verified.
  static Future<PaymentResult> startPayment({
    BuildContext? context,
    required String orderId,
    required String checkoutToken,
    double? amount,
    String? merchantName,
    String? upiId,
    String? mode,
    String? customerName,
    bool preferPureNative = false,
  }) async {
    if (orderId.trim().isEmpty) {
      throw ArgumentError('orderId cannot be empty');
    }
    if (checkoutToken.trim().isEmpty) {
      throw ArgumentError('checkoutToken cannot be empty');
    }

    if (_isProcessing) {
      return PaymentResult(
        orderId: orderId,
        status: PaymentStatus.pending,
        message: 'A payment session is already active.',
      );
    }

    _isProcessing = true;
    try {
      final checkoutUrl = '${_config.baseUrl}/checkout/${Uri.encodeComponent(orderId)}?token=${Uri.encodeQueryComponent(checkoutToken)}';
      final uri = Uri.parse(checkoutUrl);

      bool launched = false;
      try {
        launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        try {
          launched = await launchUrl(
            uri,
            mode: LaunchMode.inAppWebView,
          );
        } catch (_) {}
      }

      if (!launched) {
        _isProcessing = false;
        return PaymentResult(
          orderId: orderId,
          status: PaymentStatus.failed,
          message: 'Unable to open Payflux Web Checkout.',
        );
      }

      // Auto-poll payment status until verified by backend
      final result = await _client.pollPaymentStatus(
        orderId: orderId,
        checkoutToken: checkoutToken,
      );

      _isProcessing = false;
      return result;
    } catch (e) {
      _isProcessing = false;
      return PaymentResult(
        orderId: orderId,
        status: PaymentStatus.failed,
        message: 'Payment error: ${e.toString()}',
      );
    }
  }
}
