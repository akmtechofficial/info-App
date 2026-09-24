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

  /// Starts the 100% Pure Native Flutter UPI Payment Sheet (Zero WebView).
  /// Launches PhonePe, GPay, Paytm, BHIM, QR code and auto-polls backend status.
  static Future<PaymentResult> startPayment({
    BuildContext? context,
    required String orderId,
    required String checkoutToken,
    double? amount,
    String? merchantName,
    String? upiId,
    String? mode,
    String? customerName,
    bool preferPureNative = true,
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

    // 1. If BuildContext is available & preferPureNative is true -> 100% Native Flutter Sheet!
    if (context != null && preferPureNative) {
      _isProcessing = true;
      try {
        final result = await PayfluxNativeSheet.show(
          context: context,
          orderId: orderId,
          checkoutToken: checkoutToken,
          amount: amount ?? 0.0,
          merchantName: merchantName,
          upiId: upiId,
          mode: mode,
          customerName: customerName,
          config: _config,
        );
        _isProcessing = false;
        return result;
      } catch (e) {
        _isProcessing = false;
        return PaymentResult(
          orderId: orderId,
          status: PaymentStatus.failed,
          message: 'Native checkout error: ${e.toString()}',
        );
      }
    }

    // 2. Fallback in-app modal sheet
    if (context != null) {
      _isProcessing = true;
      try {
        final result = await PayfluxCheckoutModal.open(
          context: context,
          orderId: orderId,
          checkoutToken: checkoutToken,
          config: _config,
        );
        _isProcessing = false;
        return result;
      } catch (e) {
        _isProcessing = false;
        return PaymentResult(
          orderId: orderId,
          status: PaymentStatus.failed,
          message: 'In-app checkout error: ${e.toString()}',
        );
      }
    }

    // 3. Fallback: URL Launcher
    _isProcessing = true;
    try {
      final checkoutUrl = '${_config.baseUrl}/checkout/${Uri.encodeComponent(orderId)}?token=${Uri.encodeQueryComponent(checkoutToken)}';
      final uri = Uri.parse(checkoutUrl);

      bool launched = false;
      try {
        launched = await launchUrl(
          uri,
          mode: LaunchMode.inAppWebView,
        );
      } catch (_) {
        launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      }

      if (!launched) {
        _isProcessing = false;
        return PaymentResult(
          orderId: orderId,
          status: PaymentStatus.failed,
          message: 'Unable to open Payflux checkout.',
        );
      }

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
