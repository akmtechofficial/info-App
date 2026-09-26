import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

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

  /// Launch official Web Recharge Portal in browser for web-only recharge service
  static Future<bool> openWebRechargePortal({String? uid, double? amount, String? customPortalUrl}) async {
    final String targetBaseUrl = customPortalUrl ?? webServerUrl;
    String url = targetBaseUrl;
    if (uid != null && uid.isNotEmpty) {
      url = '$targetBaseUrl/dashboard?uid=${Uri.encodeComponent(uid)}';
    }
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error launching web recharge portal: $e');
      }
    }
    return false;
  }

  /// Launch explicit Web Checkout URL
  static Future<bool> launchWebCheckout(String checkoutUrl) async {
    if (checkoutUrl.isEmpty) return false;
    final uri = Uri.parse(checkoutUrl);
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error launching web checkout: $e');
      }
    }
    return false;
  }

  /// Create a payment order via Secure Server API
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
      } catch (_) {}

      final url = Uri.parse('$baseUrl/api/v1/orders');
      final body = {
        'apiKey': activeApiKey,
        'amount': amount.toInt(),
        'currency': 'INR',
        'customerEmail': customerEmail.isEmpty ? 'user@infoapp.com' : customerEmail,
        'customerName': customerName.isEmpty ? 'InfoApp User' : customerName,
        'returnUrl': returnUrl ?? webServerUrl,
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $activeApiKey',
          'Idempotency-Key': 'infoapp_${DateTime.now().millisecondsSinceEpoch}',
        },
        body: jsonEncode(body),
      );

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
        }
      }

      return PayfluxOrderResponse(
        success: false,
        message: 'Unable to initialize order via Payflux web server.',
      );
    } catch (e) {
      return PayfluxOrderResponse(
        success: false,
        message: 'Network error: ${e.toString()}',
      );
    }
  }
}
