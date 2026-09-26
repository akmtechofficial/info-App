import 'dart:convert';
import 'package:http/http.dart' as http;

class NumberInfoResult {
  final String phoneNumber;
  final String name;
  final String carrier;
  final String circle;
  final String country;
  final String lineType;
  final int spamScore;
  final String email;
  final String address;
  final String apiSource;
  final Map<String, dynamic> rawDetails;
  final DateTime timestamp;

  NumberInfoResult({
    required this.phoneNumber,
    required this.name,
    required this.carrier,
    required this.circle,
    required this.country,
    required this.lineType,
    required this.spamScore,
    required this.email,
    required this.address,
    required this.apiSource,
    required this.rawDetails,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'phoneNumber': phoneNumber,
      'name': name,
      'carrier': carrier,
      'circle': circle,
      'country': country,
      'lineType': lineType,
      'spamScore': spamScore,
      'email': email,
      'address': address,
      'apiSource': apiSource,
      'rawDetails': rawDetails,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory NumberInfoResult.fromMap(Map<String, dynamic> map) {
    return NumberInfoResult(
      phoneNumber: map['phoneNumber'] ?? '',
      name: map['name'] ?? 'Subscriber Details Found',
      carrier: map['carrier'] ?? 'Unknown',
      circle: map['circle'] ?? 'India',
      country: map['country'] ?? 'India',
      lineType: map['lineType'] ?? 'Mobile',
      spamScore: map['spamScore'] ?? 0,
      email: map['email'] ?? 'N/A',
      address: map['address'] ?? 'N/A',
      apiSource: map['apiSource'] ?? 'API Server',
      rawDetails: Map<String, dynamic>.from(map['rawDetails'] ?? {}),
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String get formattedRawJson {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(rawDetails);
    } catch (_) {
      return rawDetails.toString();
    }
  }
}

class NumberLookupService {
  static const String _backendBaseUrl = 'https://info-app-recharge-tawny.vercel.app';

  /// Securely lookup phone number via Next.js Backend Proxy
  /// Protects all third-party API keys from APK decompilation & reverse engineering
  static Future<NumberInfoResult> lookupNumber(String phoneNumber, {required String uid}) async {
    final cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanedNumber.length < 10) {
      throw Exception('Please enter a valid 10-digit mobile number.');
    }

    try {
      final response = await http.post(
        Uri.parse('$_backendBaseUrl/api/lookup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phoneNumber': cleanedNumber,
          'uid': uid,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['result'] != null) {
          return NumberInfoResult.fromMap(Map<String, dynamic>.from(data['result']));
        } else {
          throw Exception(data['error'] ?? 'No data found for this mobile number.');
        }
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['error'] ?? 'No data found for this mobile number.');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to fetch number details securely: $e');
    }
  }
}
