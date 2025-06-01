import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/media_file.dart';

class FileSystemService {
  static final FileSystemService _instance = FileSystemService._internal();

  factory FileSystemService() => _instance;

  FileSystemService._internal();

  /// Request storage permissions
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      // For Android, request storage permissions
      final status = await Permission.manageExternalStorage.request();
      if (status.isGranted) {
        return true;
      }

      // Try with regular storage permission if manage external storage is not granted
      final regularStorageStatus = await Permission.storage.request();
      return regularStorageStatus.isGranted;
    } else if (Platform.isIOS) {
      // iOS doesn't need explicit permissions for the app's container directory
      return true;
    }

    return false;
  }

  /// Get the list of root directories that can be browsed
  Future<List<Directory>> getRootDirectories() async {
    List<Directory> rootDirs = [];

    try {
      // Add common directories
      if (Platform.isAndroid) {
        // External storage directory (main storage)
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          // On Android, navigate up to the root of external storage
          Directory? current = externalDir;
          while (current != null && path.basename(current.path) != '0') {
            final parent = Directory(path.dirname(current.path));
            if (await parent.exists()) {
              current = parent;
            } else {
              break;
            }
          }

          // If we found the root, add it
          if (current != null) {
            rootDirs.add(current);
          } else {
            // Otherwise use the original external directory
            rootDirs.add(externalDir);
          }
        }

        // Add specific storage directories
        final types = [
          StorageDirectory.documents,
          StorageDirectory.downloads,
          StorageDirectory.pictures,
          StorageDirectory.music,
          StorageDirectory.movies,
        ];

        for (var type in types) {
          final dirs = await getExternalStorageDirectories(type: type);
          if (dirs != null && dirs.isNotEmpty) {
            rootDirs.addAll(dirs);
          }
        }
      } else if (Platform.isIOS) {
        // iOS: Add the app's documents directory
        final docsDir = await getApplicationDocumentsDirectory();
        rootDirs.add(docsDir);

        // Add the temporary directory
        final tempDir = await getTemporaryDirectory();
        rootDirs.add(tempDir);
      }

      // App documents directory (for all platforms)
      final appDocsDir = await getApplicationDocumentsDirectory();
      if (!rootDirs.contains(appDocsDir)) {
        rootDirs.add(appDocsDir);
      }

      // Remove duplicates
      rootDirs = _removeDuplicateDirectories(rootDirs);
    } catch (e) {
      debugPrint('Error getting root directories: $e');
    }

    return rootDirs;
  }

  /// Get the contents of a directory
  Future<Map<String, List<FileSystemEntity>>> getDirectoryContents(
    String directoryPath,
  ) async {
    final Map<String, List<FileSystemEntity>> result = {
      'directories': [],
      'files': [],
    };

    try {
      final directory = Directory(directoryPath);
      if (await directory.exists()) {
        final entities = await directory.list().toList();

        // Sort directories and files
        for (var entity in entities) {
          if (entity is Directory) {
            result['directories']!.add(entity);
          } else if (entity is File) {
            result['files']!.add(entity);
          }
        }

        // Sort alphabetically
        result['directories']!.sort(
          (a, b) => path
              .basename(a.path)
              .toLowerCase()
              .compareTo(path.basename(b.path).toLowerCase()),
        );

        result['files']!.sort(
          (a, b) => path
              .basename(a.path)
              .toLowerCase()
              .compareTo(path.basename(b.path).toLowerCase()),
        );
      }
    } catch (e) {
      debugPrint('Error reading directory contents: $e');
    }

    return result;
  }

  /// Convert a file to a MediaFile
  Future<MediaFile> fileToMediaFile(File file) async {
    final stat = await file.stat();
    final fileName = path.basename(file.path);
    final extension = path.extension(file.path).toLowerCase();

    // Determine file type
    MediaType type;
    if ([
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.webp',
      '.heic',
      '.heif',
    ].contains(extension)) {
      type = MediaType.image;
    } else if ([
      '.mp4',
      '.mov',
      '.avi',
      '.mkv',
      '.webm',
      '.m4v',
      '.3gp',
    ].contains(extension)) {
      type = MediaType.video;
    } else {
      type = MediaType.document;
    }

    return MediaFile(
      id: file.path,
      path: file.path,
      title: fileName,
      type: type,
      createDateTime: stat.changed,
      size: stat.size,
      mimeType: _getMimeType(file.path),
    );
  }

  /// Convert a directory to a MediaFile (for display purposes)
  MediaFile directoryToMediaFile(Directory directory) {
    final dirName = path.basename(directory.path);

    return MediaFile(
      id: directory.path,
      path: directory.path,
      title: dirName,
      type: MediaType.document, // Using document type for directories
      isDirectory: true,
    );
  }

  /// Helper method to get mime type from file extension
  String? _getMimeType(String filePath) {
    final ext = path.extension(filePath).toLowerCase();

    switch (ext) {
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

  /// Remove duplicate directories from the list
  List<Directory> _removeDuplicateDirectories(List<Directory> directories) {
    final Set<String> paths = {};
    final List<Directory> uniqueDirs = [];

    for (var dir in directories) {
      if (!paths.contains(dir.path)) {
        paths.add(dir.path);
        uniqueDirs.add(dir);
      }
    }

    return uniqueDirs;
  }
}
