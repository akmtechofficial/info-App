import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../payflux/payflux.dart';

class PayfluxOrderResponse {
  final bool success;
  final String? orderId;
  final String? checkoutToken;
  final String? checkoutUrl;
  final String? merchantName;
  final String? upiId;
  final String? mode;
  final double? amount;
  final String? message;

  PayfluxOrderResponse({
    required this.success,
    this.orderId,
    this.checkoutToken,
    this.checkoutUrl,
    this.merchantName,
    this.upiId,
    this.mode,
    this.amount,
    this.message,
  });
}

class PayfluxService {
  static const String baseUrl = 'https://fampay-merchant-api.onrender.com';
  static const String webServerUrl = 'https://info-app-recharge-tawny.vercel.app';

  static void initialize() {
    Payflux.initialize(
      const PayfluxConfig(
        environment: PayfluxEnvironment.production,
        customBaseUrl: baseUrl,
      ),
    );
  }

  /// Create a payment order via Secure Server API (No client-side key required)
  static Future<PayfluxOrderResponse> createOrder({
    required double amount,
    required String customerEmail,
    required String customerName,
    String? apiKey,
    String? returnUrl,
  }) async {
    final activeApiKey = (apiKey != null && apiKey.isNotEmpty)
        ? apiKey
        : 'akm_Z_test_7fc491fbdbcf80ed436b4c7acb7ce34e189661dcea1dcfc1';

    try {
      // 1. Try secure backend server route first so API key is configured
      final backendUrl = Uri.parse('$webServerUrl/api/payflux/create-order');
      final backendBody = {
        'amount': amount,
        'customerEmail': customerEmail.isEmpty ? 'user@infoapp.com' : customerEmail,
        'customerName': customerName.isEmpty ? 'InfoApp User' : customerName,
        'apiKey': activeApiKey,
      };

      try {
        final backendRes = await http.post(
          backendUrl,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(backendBody),
        );
        if (backendRes.statusCode == 200 || backendRes.statusCode == 201) {
          final data = jsonDecode(backendRes.body);
          if (data['success'] == true) {
            return PayfluxOrderResponse(
              success: true,
              orderId: data['orderId'],
              checkoutToken: data['checkoutToken'] ?? data['orderId'],
              checkoutUrl: data['checkoutUrl'],
              merchantName: data['merchantName'] ?? 'InfoApp Recharge',
              upiId: data['upiId'],
              mode: data['mode'],
              amount: (data['amount'] as num?)?.toDouble() ?? amount,
            );
          }
        }
      } catch (_) {
        // Backend fallback to direct gateway endpoint if apiKey provided
      }

      final url = Uri.parse('$baseUrl/api/v1/orders');
      final body = {
        'apiKey': activeApiKey,
        'amount': amount.toInt(),
        'currency': 'INR',
        'customerEmail': customerEmail.isEmpty ? 'user@infoapp.com' : customerEmail,
        'customerName': customerName.isEmpty ? 'InfoApp User' : customerName,
        'returnUrl': returnUrl ?? baseUrl,
      };

      if (kDebugMode) {
        print('Creating Payflux Order at $url: $body');
      }

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $activeApiKey',
          'Idempotency-Key': 'infoapp_${DateTime.now().millisecondsSinceEpoch}',
        },
        body: jsonEncode(body),
      );

      if (kDebugMode) {
        print('Payflux Response (${response.statusCode}): ${response.body}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final orderData = data['data'];
          final orderId = orderData['id'] ?? orderData['orderId'];
          final checkoutToken = orderData['checkoutToken'] ?? '';
          final checkoutUrl = orderData['checkoutUrl'] ?? '';
          final merchantName = orderData['merchantName'] ?? 'InfoApp Recharge';
          final upiId = orderData['upiId'] ?? '';
          final mode = orderData['mode'] ?? 'test';
          final orderAmount = (orderData['amount'] as num?)?.toDouble() ?? amount;

          return PayfluxOrderResponse(
            success: true,
            orderId: orderId,
            checkoutToken: checkoutToken,
            checkoutUrl: checkoutUrl,
            merchantName: merchantName,
            upiId: upiId,
            mode: mode,
            amount: orderAmount,
          );
        } else {
          return PayfluxOrderResponse(
            success: false,
            message: data['message'] ?? 'Failed to initialize payment order',
          );
        }
      } else {
        final data = jsonDecode(response.body);
        return PayfluxOrderResponse(
          success: false,
          message: data['message'] ?? 'Server error (${response.statusCode})',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Payflux order error: $e');
      }
      return PayfluxOrderResponse(
        success: false,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  /// Start Web Checkout using Web SDK URL & Background Status Verification
  static Future<PaymentResult> startPayment({
    BuildContext? context,
    required String orderId,
    required String checkoutToken,
    double? amount,
    String? merchantName,
    String? upiId,
    String? mode,
    String? customerName,
  }) async {
    return await Payflux.startPayment(
      context: context,
      orderId: orderId,
      checkoutToken: checkoutToken,
      amount: amount,
      merchantName: merchantName,
      upiId: upiId,
      mode: mode,
      customerName: customerName,
      preferPureNative: false, // 100% Web SDK / Web Checkout Page!
    );
  }
}
