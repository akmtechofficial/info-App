import 'dart:convert';
import 'package:flutter/foundation.dart';
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
  static const String api1Url =
      'https://num-to-info-reseller.asurpapa.workers.dev/api';
  static const String api1Key = '@SHURU_33-PAGLUU';

  static const String api2Url =
      'https://api-pro-v2.vercel.app/key/576f1e132326cee10f887ec38ccae1/get_data';

  /// Lookup phone number with Multi-API mechanism
  /// Throws Exception if no valid data is found so NO credit is deducted
  static Future<NumberInfoResult> lookupNumber(String phoneNumber) async {
    final cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanedNumber.length < 10) {
      throw Exception('Please enter a valid 10-digit mobile number.');
    }

    // --- STEP 1: Try Primary API (API 1) ---
    try {
      if (kDebugMode) print('Attempting API 1 lookup for $cleanedNumber...');
      final uri1 = Uri.parse('$api1Url?key=$api1Key&number=$cleanedNumber');
      final response1 = await http.get(uri1).timeout(const Duration(seconds: 10));

      if (response1.statusCode == 200) {
        final bodyText = response1.body.trim();
        if (_isValidResponse(bodyText)) {
          final data = jsonDecode(bodyText);
          final result = _parseApi1Data(cleanedNumber, data);
          if (result != null) {
            if (kDebugMode) print('API 1 Success!');
            return result;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('API 1 error: $e');
    }

    // --- STEP 2: Try Fallback API (API 2) ---
    try {
      if (kDebugMode) print('Attempting API 2 lookup for $cleanedNumber...');
      final uri2 = Uri.parse('$api2Url?number=$cleanedNumber');
      final response2 = await http.get(uri2).timeout(const Duration(seconds: 10));

      if (response2.statusCode == 200) {
        final bodyText = response2.body.trim();
        if (_isValidResponse(bodyText)) {
          final data = jsonDecode(bodyText);
          final result = _parseApi2Data(cleanedNumber, data);
          if (result != null) {
            if (kDebugMode) print('API 2 Success!');
            return result;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('API 2 error: $e');
    }

    // If both APIs fail to find raw data, throw Exception (NO CREDIT DEDUCTED)
    throw Exception('No data found for this mobile number. No credits were deducted.');
  }

  static bool _isValidResponse(String text) {
    if (text.isEmpty) return false;
    if (text == '[]' || text == '{}' || text.contains('"data":[]') || text.contains('"data":{}')) {
      return false;
    }
    if (text.contains('"status":false') ||
        text.contains('"status": "false"') ||
        text.contains('"success":false') ||
        text.contains('"error":true')) {
      return false;
    }
    return text.startsWith('{') || text.startsWith('[');
  }

  static NumberInfoResult? _parseApi1Data(
      String phoneNumber, dynamic data) {
    try {
      Map<String, dynamic> raw;
      if (data is List && data.isNotEmpty) {
        raw = Map<String, dynamic>.from(data.first);
      } else if (data is Map) {
        if (data.containsKey('data') && data['data'] != null) {
          final sub = data['data'];
          if (sub is List && sub.isNotEmpty) {
            raw = Map<String, dynamic>.from(sub.first);
          } else if (sub is Map) {
            raw = Map<String, dynamic>.from(sub);
          } else {
            raw = Map<String, dynamic>.from(data);
          }
        } else {
          raw = Map<String, dynamic>.from(data);
        }
      } else {
        return null;
      }

      if (raw.isEmpty) return null;

      final name = raw['name'] ?? raw['Name'] ?? raw['owner'] ?? raw['fullname'] ?? 'Subscriber Details Found';
      final carrier = raw['carrier'] ?? raw['operator'] ?? raw['telecom'] ?? raw['sim'] ?? 'GSM';
      final circle = raw['circle'] ?? raw['location'] ?? raw['state'] ?? raw['region'] ?? 'India';
      final email = raw['email'] ?? raw['mail'] ?? 'N/A';
      final address = raw['address'] ?? raw['city'] ?? 'N/A';

      return NumberInfoResult(
        phoneNumber: phoneNumber,
        name: name.toString(),
        carrier: carrier.toString(),
        circle: circle.toString(),
        country: 'India',
        lineType: raw['type']?.toString() ?? 'Mobile',
        spamScore: 0,
        email: email.toString(),
        address: address.toString(),
        apiSource: 'Reseller API (Server 1)',
        rawDetails: raw,
      );
    } catch (_) {
      return null;
    }
  }

  static NumberInfoResult? _parseApi2Data(
      String phoneNumber, dynamic data) {
    try {
      Map<String, dynamic> raw;
      if (data is List && data.isNotEmpty) {
        raw = Map<String, dynamic>.from(data.first);
      } else if (data is Map) {
        if (data.containsKey('data') && data['data'] != null) {
          final sub = data['data'];
          if (sub is List && sub.isNotEmpty) {
            raw = Map<String, dynamic>.from(sub.first);
          } else if (sub is Map) {
            raw = Map<String, dynamic>.from(sub);
          } else {
            raw = Map<String, dynamic>.from(data);
          }
        } else {
          raw = Map<String, dynamic>.from(data);
        }
      } else {
        return null;
      }

      if (raw.isEmpty) return null;

      final name = raw['name'] ?? raw['Name'] ?? raw['caller'] ?? raw['owner'] ?? 'Subscriber Details Found';
      final carrier = raw['carrier'] ?? raw['sim'] ?? raw['operator'] ?? 'GSM';
      final circle = raw['state'] ?? raw['circle'] ?? raw['region'] ?? 'India';

      return NumberInfoResult(
        phoneNumber: phoneNumber,
        name: name.toString(),
        carrier: carrier.toString(),
        circle: circle.toString(),
        country: 'India',
        lineType: 'Mobile',
        spamScore: 0,
        email: raw['email']?.toString() ?? 'N/A',
        address: raw['address']?.toString() ?? 'N/A',
        apiSource: 'Pro API v2 (Server 2)',
        rawDetails: raw,
      );
    } catch (_) {
      return null;
    }
  }
}
