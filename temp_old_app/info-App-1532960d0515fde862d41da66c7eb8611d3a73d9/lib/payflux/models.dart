// Payflux Flutter SDK Models
enum PaymentStatus {
  created,
  checkoutOpened,
  paymentInitiated,
  pending,
  success,
  failed,
  cancelled,
  expired,
}

enum PayfluxEnvironment {
  sandbox,
  production,
}

class PayfluxConfig {
  final PayfluxEnvironment environment;
  final String? customBaseUrl;
  final Duration timeout;

  const PayfluxConfig({
    this.environment = PayfluxEnvironment.production,
    this.customBaseUrl,
    this.timeout = const Duration(minutes: 5),
  });

  String get baseUrl {
    if (customBaseUrl != null && customBaseUrl!.isNotEmpty) {
      return customBaseUrl!.replaceAll(RegExp(r'/+$'), '');
    }
    switch (environment) {
      case PayfluxEnvironment.sandbox:
        return 'https://fampay-merchant-api.onrender.com';
      case PayfluxEnvironment.production:
        return 'https://fampay-merchant-api.onrender.com';
    }
  }
}

class PaymentResult {
  final String orderId;
  final PaymentStatus status;
  final String? transactionId;
  final String? message;
  final String? paymentMethod;
  final double? amount;

  const PaymentResult({
    required this.orderId,
    required this.status,
    this.transactionId,
    this.message,
    this.paymentMethod,
    this.amount,
  });

  bool get isSuccess => status == PaymentStatus.success;

  @override
  String toString() {
    return 'PaymentResult(orderId: $orderId, status: $status, transactionId: $transactionId, message: $message)';
  }
}
