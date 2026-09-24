import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

class PayfluxClient {
  final PayfluxConfig config;

  PayfluxClient(this.config);

  /// Fetch live order details directly from Payflux API (/api/v1/orders/:orderId)
  Future<Map<String, dynamic>?> getOrderDetails({
    required String orderId,
    required String checkoutToken,
  }) async {
    try {
      final uri = Uri.parse('${config.baseUrl}/api/v1/orders/$orderId?token=${Uri.encodeQueryComponent(checkoutToken)}');
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'X-Checkout-Token': checkoutToken,
          'User-Agent': 'Payflux-Flutter-SDK/1.0.0',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return data['data'] as Map<String, dynamic>;
        }
      }
    } catch (_) {
      // Ignore network errors on initial details fetch
    }
    return null;
  }

  /// Polls payment status using the exponential retry backoff schedule:
  /// 2s, 2s, 3s, 5s, 5s... up to timeout (default 5 minutes).
  Future<PaymentResult> pollPaymentStatus({
    required String orderId,
    required String checkoutToken,
  }) async {
    final deadline = DateTime.now().add(config.timeout);
    final delays = [2, 2, 3, 5, 5];
    int attempt = 0;

    while (DateTime.now().isBefore(deadline)) {
      try {
        final uri = Uri.parse('${config.baseUrl}/api/v1/payments/$orderId/status?token=${Uri.encodeQueryComponent(checkoutToken)}');
        final response = await http.get(
          uri,
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'Payflux-Flutter-SDK/1.0.0',
          },
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true && data['data'] != null) {
            final orderData = data['data'];
            final statusStr = (orderData['status'] ?? '').toString().toUpperCase();
            final status = _mapStatus(statusStr);

            if (status == PaymentStatus.success ||
                status == PaymentStatus.failed ||
                status == PaymentStatus.cancelled ||
                status == PaymentStatus.expired) {
              return PaymentResult(
                orderId: orderId,
                status: status,
                transactionId: orderData['transactionId']?.toString(),
                message: orderData['message']?.toString() ?? statusStr,
                paymentMethod: orderData['paymentMethod']?.toString(),
                amount: orderData['amount'] != null ? (orderData['amount'] as num).toDouble() : null,
              );
            }
          }
        }
      } catch (e) {
        // Continue polling on transient network drops
      }

      final delaySec = attempt < delays.length ? delays[attempt] : 5;
      attempt++;
      await Future.delayed(Duration(seconds: delaySec));
    }

    return PaymentResult(
      orderId: orderId,
      status: PaymentStatus.expired,
      message: 'Payment confirmation timed out.',
    );
  }

  /// Checks payment status once for orderId & checkoutToken
  Future<PaymentResult?> checkPaymentStatusOnce({
    required String orderId,
    required String checkoutToken,
  }) async {
    try {
      final uri = Uri.parse('${config.baseUrl}/api/v1/payments/$orderId/status?token=${Uri.encodeQueryComponent(checkoutToken)}');
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Payflux-Flutter-SDK/1.0.0',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final orderData = data['data'];
          final statusStr = (orderData['status'] ?? '').toString().toUpperCase();
          final status = _mapStatus(statusStr);

          return PaymentResult(
            orderId: orderId,
            status: status,
            transactionId: orderData['transactionId']?.toString(),
            message: orderData['message']?.toString() ?? statusStr,
            paymentMethod: orderData['paymentMethod']?.toString(),
            amount: orderData['amount'] != null ? (orderData['amount'] as num).toDouble() : null,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  /// Direct API Payment Verification against Payflux backend (/api/v1/payments/verify)
  Future<Map<String, dynamic>> verifyPayment({
    required String orderId,
    required String checkoutToken,
    String? senderName,
    bool simulateSuccess = false,
  }) async {
    final verifyUrl = Uri.parse('${config.baseUrl}/api/v1/payments/verify');
    try {
      final response = await http.post(
        verifyUrl,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Checkout-Token': checkoutToken,
        },
        body: jsonEncode({
          'orderId': orderId,
          'checkoutToken': checkoutToken,
          if (senderName != null && senderName.isNotEmpty) 'senderName': senderName,
          if (simulateSuccess) 'simulateSuccess': true,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      } else {
        Map<String, dynamic> data = {};
        try {
          data = jsonDecode(response.body);
        } catch (_) {}
        return {
          'success': false,
          'message': data['message'] ?? 'HTTP ${response.statusCode} error during verification.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Verification request error: ${e.toString()}',
      };
    }
  }

  PaymentStatus _mapStatus(String status) {
    switch (status) {
      case 'SUCCESS':
        return PaymentStatus.success;
      case 'FAILED':
        return PaymentStatus.failed;
      case 'CANCELLED':
        return PaymentStatus.cancelled;
      case 'EXPIRED':
        return PaymentStatus.expired;
      case 'PAYMENT_INITIATED':
        return PaymentStatus.paymentInitiated;
      case 'CHECKOUT_OPENED':
        return PaymentStatus.checkoutOpened;
      case 'PENDING':
      default:
        return PaymentStatus.pending;
    }
  }
}
