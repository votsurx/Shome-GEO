import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

class MailruService {
  static webdav.Client? _client;
  static String? _baseUrl;

  /// Подключение к Mail.ru Cloud через WebDAV
  static Future<bool> connect({
    required String login,
    required String password,
  }) async {
    try {
      _baseUrl = 'https://webdav.cloud.mail.ru';
      _client = webdav.newClient(_baseUrl!, user: login, password: password);
      _client!.setConnectTimeout(10000);
      _client!.setSendTimeout(10000);
      _client!.setReceiveTimeout(10000);

      await _client!.ping();

      // Создаём папки
      try {
        await _client!.mkdir('/SHome');
      } catch (_) {}
      try {
        await _client!.mkdir('/SHome/presence');
      } catch (_) {}

      debugPrint('✅ Mail.ru Cloud подключён');
      return true;
    } catch (e) {
      debugPrint('❌ Ошибка Mail.ru: $e');
      return false;
    }
  }

  /// Загрузить файл
  static Future<bool> uploadFile(String path, String content) async {
    if (_client == null) return false;
    try {
      // Создаём промежуточные папки
      final parts = path.split('/');
      if (parts.length > 1) {
        String currentPath = '';
        for (int i = 0; i < parts.length - 1; i++) {
          currentPath += '/${parts[i]}';
          try {
            await _client!.mkdir(currentPath);
          } catch (_) {
            // Папка уже существует
          }
        }
      }

      final bytes = utf8.encode(content);
      await _client!.write(path, bytes);
      debugPrint('📤 Загружено: $path');
      return true;
    } catch (e) {
      debugPrint('❌ Ошибка загрузки: $e');
      return false;
    }
  }

  /// Скачать файл
  static Future<String?> downloadFile(String path) async {
    if (_client == null) return null;
    try {
      final bytes = await _client!.read(path);
      debugPrint('📥 Скачано: $path');
      return utf8.decode(bytes);
    } catch (e) {
      debugPrint('❌ Ошибка скачивания: $e');
      return null;
    }
  }

  /// Удалить файл
  static Future<bool> deleteFile(String path) async {
    if (_client == null) return false;
    try {
      await _client!.remove(path);
      return true;
    } catch (e) {
      debugPrint('❌ Ошибка удаления: $e');
      return false;
    }
  }

  /// Создать папку
  static Future<bool> createFolder(String path) async {
    if (_client == null) return false;
    try {
      await _client!.mkdir(path);
      return true;
    } catch (e) {
      debugPrint('⚠️ Папка уже существует или ошибка: $e');
      return false;
    }
  }

  /// Проверить подключение
  static bool get isConnected => _client != null;
}