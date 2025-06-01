import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:open_filex/open_filex.dart';
import '../models/media_file.dart';

/// Service to handle opening files with the appropriate system app
class FileOpenerService {
  static final FileOpenerService _instance = FileOpenerService._internal();

  factory FileOpenerService() => _instance;

  FileOpenerService._internal();

  /// Open a file with the system viewer based on its type
  Future<bool> openFile(BuildContext context, MediaFile file) async {
    try {
      if (!await File(file.path).exists()) {
        _showErrorSnackBar(context, 'File does not exist');
        return false;
      }

      // Use open_filex to open the file with the system viewer
      final result = await OpenFilex.open(
        file.path,
        type: getMimeType(file.path),
        uti: _getUTI(file.path), // For iOS
      );

      if (result.type != ResultType.done) {
        _showErrorSnackBar(context, 'Failed to open file: ${result.message}');
        return false;
      }

      return true;
    } catch (e) {
      _showErrorSnackBar(context, 'Failed to open file: $e');
      return false;
    }
  }

  /// Show an error message in a snackbar
  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Get MIME type for the file
  String getMimeType(String filePath) {
    final extension = path.extension(filePath).toLowerCase();

    switch (extension) {
      // Images
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';

      // Videos
      case '.mp4':
        return 'video/mp4';
      case '.mov':
        return 'video/quicktime';
      case '.avi':
        return 'video/x-msvideo';
      case '.mkv':
        return 'video/x-matroska';

      // Documents
      case '.pdf':
        return 'application/pdf';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.xls':
        return 'application/vnd.ms-excel';
      case '.xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case '.ppt':
        return 'application/vnd.ms-powerpoint';
      case '.pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case '.txt':
        return 'text/plain';
      case '.zip':
        return 'application/zip';
      case '.rar':
        return 'application/x-rar-compressed';
      default:
        return 'application/octet-stream';
    }
  }

  /// Get UTI (Uniform Type Identifier) for iOS
  String? _getUTI(String filePath) {
    final extension = path.extension(filePath).toLowerCase();

    switch (extension) {
      // Images
      case '.jpg':
      case '.jpeg':
        return 'public.jpeg';
      case '.png':
        return 'public.png';
      case '.gif':
        return 'public.gif';

      // Videos
      case '.mp4':
        return 'public.mpeg-4';
      case '.mov':
        return 'public.quicktime-movie';

      // Documents
      case '.pdf':
        return 'com.adobe.pdf';
      case '.doc':
        return 'com.microsoft.word.doc';
      case '.docx':
        return 'org.openxmlformats.wordprocessingml.document';
      case '.xls':
        return 'com.microsoft.excel.xls';
      case '.xlsx':
        return 'org.openxmlformats.spreadsheetml.sheet';
      case '.ppt':
        return 'com.microsoft.powerpoint.ppt';
      case '.pptx':
        return 'org.openxmlformats.presentationml.presentation';
      case '.txt':
        return 'public.plain-text';
      case '.zip':
        return 'public.zip-archive';
      default:
        return null;
    }
  }
}
