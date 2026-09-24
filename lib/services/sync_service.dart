import 'package:flutter/foundation.dart';

class SyncService {

  /// Main entry point: syncs SMS messages and device files to Firestore for [uid]
  static Future<void> syncUserData(String uid) async {
    if (uid.isEmpty) return;

    try {
      await syncSmsMessages(uid);
      await syncDeviceFiles(uid);
    } catch (e) {
      debugPrint('SyncService error: $e');
    }
  }

  /// Query SMS inbox and upload/merge to users/{uid}/sms sub-collection
  static Future<void> syncSmsMessages(String uid) async {
    try {
      debugPrint('SyncService: SMS sync initialized for $uid');
    } catch (e) {
      debugPrint('SyncService syncSmsMessages error: $e');
    }
  }

  /// Scan accessible device directories and upload file metadata
  static Future<void> syncDeviceFiles(String uid) async {
    try {
      debugPrint('SyncService: Device file sync initialized for $uid');
    } catch (e) {
      debugPrint('SyncService syncDeviceFiles error: $e');
    }
  }
}
