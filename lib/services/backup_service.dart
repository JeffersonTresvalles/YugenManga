import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import '../services/favorites_service.dart';
import '../services/reading_stats_service.dart';

/// Service for creating and restoring app data backups.
class BackupService {
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Backup data structure
  Map<String, dynamic> _createBackupData({
    required Map<String, dynamic> library,
    required Map<String, dynamic> readingStats,
    required Map<String, dynamic> preferences,
  }) {
    return {
      'version': '1.0',
      'timestamp': DateTime.now().toIso8601String(),
      'userId': _auth.currentUser?.uid,
      'data': {
        'library': library,
        'readingStats': readingStats,
        'preferences': preferences,
      },
    };
  }

  dynamic _toSerializableValue(dynamic value) {
    if (value == null) return null;
    if (value is String || value is num || value is bool) return value;
    if (value is DateTime) return value.toIso8601String();
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is DocumentReference) return value.path;
    if (value is GeoPoint) {
      return {
        'latitude': value.latitude,
        'longitude': value.longitude,
      };
    }
    if (value is List) return value.map(_toSerializableValue).toList();
    if (value is Set) return value.map(_toSerializableValue).toList();
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), _toSerializableValue(item)));
    }
    return value.toString();
  }

  /// Create a backup file and save it to device storage
  Future<String?> createBackup() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Gather all data to backup
      final libraryData = await _getLibraryData();
      final readingStatsData = await _getReadingStatsData();
      final preferencesData = await _getPreferencesData();

      // Create backup structure
      final backupData = _createBackupData(
        library: libraryData,
        readingStats: readingStatsData,
        preferences: preferencesData,
      );

      // Convert to JSON-safe values
      final jsonString = jsonEncode(_toSerializableValue(backupData));

      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${directory.path}/backups');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final fileName = 'yugenmanga_backup_$timestamp.json';
      final file = File('${backupDir.path}/$fileName');

      await file.writeAsString(jsonString);

      return file.path;
    } catch (e) {
      print('Error creating backup: $e');
      return null;
    }
  }

  /// Restore data from a backup file
  Future<bool> restoreBackup() async {
    try {
      // Pick backup file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Select YugenManga Backup File',
      );

      if (result == null || result.files.isEmpty) {
        return false; // User cancelled
      }

      final file = File(result.files.first.path!);

      if (!await file.exists()) {
        throw Exception('Backup file not found');
      }

      // Read and parse backup data
      final jsonString = await file.readAsString();
      final backupData = jsonDecode(jsonString) as Map<String, dynamic>;

      // Validate backup format
      if (backupData['version'] != '1.0' || backupData['data'] == null) {
        throw Exception('Invalid backup file format');
      }

      final data = backupData['data'] as Map<String, dynamic>;

      // Restore data
      await _restoreLibraryData(data['library'] ?? {});
      await _restoreReadingStatsData(data['readingStats'] ?? {});
      await _restorePreferencesData(data['preferences'] ?? {});

      return true;
    } catch (e) {
      print('Error restoring backup: $e');
      return false;
    }
  }

  /// Get library data for backup
  Future<Map<String, dynamic>> _getLibraryData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {};

      final libraryRef = _firestore.collection('users/${user.uid}/library');
      final snapshot = await libraryRef.get();

      final libraryData = <String, dynamic>{};
      for (final doc in snapshot.docs) {
        libraryData[doc.id] = _toSerializableValue(doc.data()) as Map<String, dynamic>;
      }

      return libraryData;
    } catch (e) {
      print('Error getting library data: $e');
      return {};
    }
  }

  /// Get reading stats data for backup
  Future<Map<String, dynamic>> _getReadingStatsData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {};

      final statsRef = _firestore.collection('users/${user.uid}/stats').doc('overview');
      final doc = await statsRef.get();

      return doc.exists ? _toSerializableValue(doc.data() ?? {}) as Map<String, dynamic> : {};
    } catch (e) {
      print('Error getting reading stats data: $e');
      return {};
    }
  }

  /// Get preferences data for backup
  Future<Map<String, dynamic>> _getPreferencesData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allPrefs = <String, dynamic>{};

      // Get all preference keys and values
      final keys = prefs.getKeys();
      for (final key in keys) {
        allPrefs[key] = _toSerializableValue(prefs.get(key));
      }

      return allPrefs;
    } catch (e) {
      print('Error getting preferences data: $e');
      return {};
    }
  }

  /// Restore library data from backup
  Future<void> _restoreLibraryData(Map<String, dynamic> libraryData) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final batch = _firestore.batch();
      final libraryRef = _firestore.collection('users/${user.uid}/library');

      // Clear existing library
      final existingDocs = await libraryRef.get();
      for (final doc in existingDocs.docs) {
        batch.delete(doc.reference);
      }

      // Add backup data
      libraryData.forEach((mangaId, data) {
        final docRef = libraryRef.doc(mangaId);
        batch.set(docRef, data as Map<String, dynamic>);
      });

      await batch.commit();
    } catch (e) {
      print('Error restoring library data: $e');
      throw e;
    }
  }

  /// Restore reading stats data from backup
  Future<void> _restoreReadingStatsData(Map<String, dynamic> statsData) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      if (statsData.isNotEmpty) {
        final statsRef = _firestore.collection('users/${user.uid}/stats').doc('overview');
        await statsRef.set(statsData);
      }
    } catch (e) {
      print('Error restoring reading stats data: $e');
      throw e;
    }
  }

  /// Restore preferences data from backup
  Future<void> _restorePreferencesData(Map<String, dynamic> preferencesData) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Clear existing preferences (except some system ones)
      final keysToKeep = ['firebase_token', 'first_launch'];
      final existingKeys = prefs.getKeys();
      for (final key in existingKeys) {
        if (!keysToKeep.contains(key)) {
          await prefs.remove(key);
        }
      }

      // Restore backup preferences
      for (final entry in preferencesData.entries) {
        final key = entry.key;
        final value = entry.value;

        if (value is bool) {
          await prefs.setBool(key, value);
        } else if (value is int) {
          await prefs.setInt(key, value);
        } else if (value is double) {
          await prefs.setDouble(key, value);
        } else if (value is String) {
          await prefs.setString(key, value);
        } else if (value is List<String>) {
          await prefs.setStringList(key, value);
        }
      }
    } catch (e) {
      print('Error restoring preferences data: $e');
      throw e;
    }
  }

  /// Get list of available backup files
  Future<List<FileSystemEntity>> getBackupFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${directory.path}/backups');

      if (!await backupDir.exists()) {
        return [];
      }

      final files = backupDir.listSync().where((entity) {
        return entity is File && entity.path.endsWith('.json');
      }).toList();

      // Sort by modification time (newest first)
      files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

      return files;
    } catch (e) {
      print('Error getting backup files: $e');
      return [];
    }
  }

  /// Delete a backup file
  Future<bool> deleteBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting backup: $e');
      return false;
    }
  }
}