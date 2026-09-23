import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

class PayfluxClient {
  final PayfluxConfig config;

  PayfluxClient(this.config);

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
