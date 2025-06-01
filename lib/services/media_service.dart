import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../models/media_file.dart';

class MediaService {
  static final MediaService _instance = MediaService._internal();

  factory MediaService() => _instance;

  MediaService._internal();

  // Get the current permission state
  Future<PermissionState> checkPermission() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    return ps;
  }

  // Request permission for photo/media access
  Future<bool> requestPermission() async {
    PermissionState ps = await PhotoManager.requestPermissionExtend();

    if (ps.isAuth) {
      return true;
    }

    // For Android, we might need to request additional permissions
    if (Platform.isAndroid) {
      Map<Permission, PermissionStatus> statuses =
          await [
            Permission.storage,
            Permission.manageExternalStorage,
            Permission.photos,
            Permission.videos,
          ].request();

      bool allGranted = true;
      statuses.forEach((permission, status) {
        if (!status.isGranted) {
          allGranted = false;
        }
      });

      return allGranted;
    }

    return false;
  }

  // Open device settings to allow the user to grant permissions
  Future<void> openSettings() async {
    await PhotoManager.openSetting();
  }

  // Fetch all albums (Image, Video, and All)
  Future<List<AssetPathEntity>> getAlbums({
    RequestType type = RequestType.common,
  }) async {
    List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: type,
      hasAll: true,
    );

    return albums;
  }

  // Fetch assets from a specific album with pagination
  Future<List<MediaFile>> getAssetsFromAlbum(
    AssetPathEntity album, {
    int page = 0,
    int size = 30,
  }) async {
    List<AssetEntity> assets = await album.getAssetListPaged(
      page: page,
      size: size,
    );

    List<MediaFile> mediaFiles = [];
    for (var asset in assets) {
      final mediaFile = await _convertAssetToMediaFile(asset);
      if (mediaFile != null) {
        mediaFiles.add(mediaFile);
      }
    }

    return mediaFiles;
  }

  // Convert AssetEntity to our custom MediaFile model
  Future<MediaFile?> _convertAssetToMediaFile(AssetEntity asset) async {
    try {
      final file = await asset.file;
      if (file == null) return null;

      MediaType type;
      switch (asset.type) {
        case AssetType.image:
          type = MediaType.image;
          break;
        case AssetType.video:
          type = MediaType.video;
          break;
        default:
          type = MediaType.document;
      }

      final fileStat = await file.stat();

      return MediaFile(
        id: asset.id,
        path: file.path,
        title: await asset.titleAsync,
        type: type,
        createDateTime: asset.createDateTime,
        size: fileStat.size,
        mimeType: asset.mimeType,
        assetEntity: asset,
      );
    } catch (e) {
      debugPrint('Error converting asset: $e');
      return null;
    }
  }

  // Get document files with pagination
  Future<List<MediaFile>> getDocuments({int page = 0, int size = 30}) async {
    final List<MediaFile> documents = [];
    debugPrint('========== STARTING DOCUMENT SEARCH ==========');

    try {
      if (Platform.isAndroid) {
        // Get directories using path_provider
        final List<Directory?> directories = [];
        final List<String> additionalPaths = [];

        // Try to get the root external storage directory first (for Android)
        try {
          final externalDir = await getExternalStorageDirectory();
          if (externalDir != null) {
            debugPrint('Found external dir: ${externalDir.path}');

            // Try to find the Android root storage
            Directory? current = externalDir;
            while (current != null && path.basename(current.path) != '0') {
              final parent = Directory(path.dirname(current.path));
              if (await parent.exists()) {
                current = parent;
                debugPrint('Moving up to parent: ${current.path}');
              } else {
                break;
              }
            }

            if (current != null) {
              debugPrint('Found root: ${current.path}');
              directories.add(current);

              // Also try to access the main storage areas directly
              final storageDir = Directory(path.dirname(current.path));
              if (await storageDir.exists()) {
                try {
                  final storageEntities = await storageDir.list().toList();
                  for (var entity in storageEntities) {
                    if (entity is Directory) {
                      debugPrint('Found storage entity: ${entity.path}');
                      directories.add(entity);
                    }
                  }
                } catch (e) {
                  debugPrint('Error listing storage entities: $e');
                }
              }
            } else {
              debugPrint(
                'Could not find root, using original: ${externalDir.path}',
              );
              directories.add(externalDir);
            }

            // Try to directly access the Downloads folder
            additionalPaths.add('${externalDir.path}/Download');
            additionalPaths.add('${externalDir.path}/Downloads');
            additionalPaths.add('/storage/emulated/0/Download');
            additionalPaths.add('/storage/emulated/0/Downloads');
          }
        } catch (e) {
          debugPrint('Error finding root external storage: $e');
        }

        // App's documents directory
        final appDocDir = await getApplicationDocumentsDirectory();
        directories.add(appDocDir);
        debugPrint('Added app docs dir: ${appDocDir.path}');

        // Add specific storage directories
        final types = [
          StorageDirectory.documents,
          StorageDirectory.downloads,
          StorageDirectory.dcim,
          StorageDirectory.pictures,
          StorageDirectory.music,
          StorageDirectory.movies,
        ];

        for (var type in types) {
          try {
            final dirs = await getExternalStorageDirectories(type: type);
            if (dirs != null && dirs.isNotEmpty) {
              for (var dir in dirs) {
                debugPrint('Added ${type.toString()} dir: ${dir.path}');
                directories.add(dir);
              }
            }
          } catch (e) {
            debugPrint('Error accessing $type directory: $e');
          }
        }

        // Try the additional paths
        for (var pathStr in additionalPaths) {
          try {
            final dir = Directory(pathStr);
            if (await dir.exists()) {
              debugPrint('Added additional path: $pathStr');
              directories.add(dir);
            }
          } catch (e) {
            debugPrint('Error accessing additional path $pathStr: $e');
          }
        }

        // Process each directory
        List<FileSystemEntity> allFiles = [];

        // Common folders to look deeper into
        final deeperFolderNames = [
          'downloads',
          'download',
          'documents',
          'docs',
          'files',
          'media',
          'pdf',
          'ebooks',
          'books',
          'document',
        ];

        for (Directory? dir in directories) {
          if (dir != null && dir.existsSync()) {
            try {
              debugPrint('Searching in directory: ${dir.path}');

              // First check for files in the current directory
              final entities = await dir.list().toList();

              for (var entity in entities) {
                if (entity is File) {
                  final filePath = entity.path.toLowerCase();
                  if (!_isImageOrVideo(filePath) &&
                      !allFiles.any((f) => f.path == entity.path)) {
                    debugPrint('Found file: ${entity.path}');
                    allFiles.add(entity);
                  }
                } else if (entity is Directory) {
                  final dirName = path.basename(entity.path).toLowerCase();

                  // Look one level deep for all directories
                  try {
                    final subEntities = await entity.list().toList();
                    for (var subEntity in subEntities) {
                      if (subEntity is File) {
                        final filePath = subEntity.path.toLowerCase();
                        if (!_isImageOrVideo(filePath) &&
                            !allFiles.any((f) => f.path == subEntity.path)) {
                          debugPrint(
                            'Found file in subdirectory: ${subEntity.path}',
                          );
                          allFiles.add(subEntity);
                        }
                      }
                    }
                  } catch (e) {
                    debugPrint('Error listing subdirectory ${entity.path}: $e');
                  }

                  // For certain directories, look even deeper (2 levels)
                  if (deeperFolderNames.contains(dirName)) {
                    try {
                      final subDirs =
                          await entity
                              .list()
                              .where((e) => e is Directory)
                              .cast<Directory>()
                              .toList();

                      for (var subDir in subDirs) {
                        try {
                          final deepFiles =
                              await subDir
                                  .list()
                                  .where((e) => e is File)
                                  .cast<File>()
                                  .toList();

                          for (var file in deepFiles) {
                            final filePath = file.path.toLowerCase();
                            if (!_isImageOrVideo(filePath) &&
                                !allFiles.any((f) => f.path == file.path)) {
                              debugPrint(
                                'Found file in deep subdirectory: ${file.path}',
                              );
                              allFiles.add(file);
                            }
                          }
                        } catch (e) {
                          debugPrint(
                            'Error listing deep subdirectory ${subDir.path}: $e',
                          );
                        }
                      }
                    } catch (e) {
                      debugPrint(
                        'Error listing subdirectories of ${entity.path}: $e',
                      );
                    }
                  }
                }
              }
            } catch (e) {
              debugPrint('Error accessing directory ${dir.path}: $e');
            }
          }
        }

        // Sort by modification time (newest first)
        allFiles.sort((a, b) {
          try {
            final aTime = FileStat.statSync(a.path).modified;
            final bTime = FileStat.statSync(b.path).modified;
            return bTime.compareTo(aTime);
          } catch (e) {
            return 0;
          }
        });

        debugPrint('Total files found: ${allFiles.length}');

        // Look for specific PDF files in the list
        final pdfFiles =
            allFiles
                .where((file) => file.path.toLowerCase().endsWith('.pdf'))
                .toList();
        debugPrint('PDF files found: ${pdfFiles.length}');
        for (var pdf in pdfFiles) {
          debugPrint('PDF: ${pdf.path}');
        }

        // Apply pagination
        final paginatedFiles = allFiles.skip(page * size).take(size).toList();

        // Convert to MediaFile objects
        for (var fileEntity in paginatedFiles) {
          try {
            final file = File(fileEntity.path);
            final stat = await file.stat();

            // Skip system and hidden files
            final fileName = path.basename(file.path);
            if (fileName.startsWith('.') || _isSystemFile(file.path)) {
              continue;
            }

            // Only include common document formats
            if (!_isDocumentFile(file.path)) {
              continue;
            }

            final mediaFile = MediaFile(
              id: fileEntity.path,
              path: fileEntity.path,
              title: fileName,
              type: MediaType.document,
              createDateTime: stat.changed,
              size: stat.size,
              mimeType: _getMimeType(fileEntity.path),
            );

            documents.add(mediaFile);
            debugPrint('Added to documents list: ${fileEntity.path}');
          } catch (e) {
            debugPrint('Error processing file ${fileEntity.path}: $e');
          }
        }
      } else if (Platform.isIOS) {
        // On iOS, we use the application documents directory and other available directories
        try {
          final List<Directory> directories = [];

          // Add documents directory
          final docsDir = await getApplicationDocumentsDirectory();
          directories.add(docsDir);
          debugPrint('iOS: Added docs dir: ${docsDir.path}');

          // Add the temporary directory
          final tempDir = await getTemporaryDirectory();
          directories.add(tempDir);
          debugPrint('iOS: Added temp dir: ${tempDir.path}');

          // Use container directory if available (iOS)
          try {
            final containerDir = Directory(path.dirname(docsDir.path));
            if (await containerDir.exists()) {
              directories.add(containerDir);
              debugPrint('iOS: Added container dir: ${containerDir.path}');
            }
          } catch (e) {
            debugPrint('Error accessing container directory: $e');
          }

          List<FileSystemEntity> allFiles = [];

          // Process each directory
          for (var dir in directories) {
            if (await dir.exists()) {
              try {
                debugPrint('iOS: Searching in directory: ${dir.path}');
                final dirFiles = await dir.list(recursive: true).toList();

                for (var entity in dirFiles) {
                  if (entity is File) {
                    final filePath = entity.path.toLowerCase();
                    if (!_isImageOrVideo(filePath) &&
                        !allFiles.any((f) => f.path == entity.path)) {
                      debugPrint('iOS: Found file: ${entity.path}');
                      allFiles.add(entity);
                    }
                  }
                }
              } catch (e) {
                debugPrint('Error accessing iOS directory ${dir.path}: $e');
              }
            }
          }

          debugPrint('iOS: Total files found: ${allFiles.length}');

          // Sort by modification time (newest first)
          allFiles.sort((a, b) {
            try {
              final aTime = FileStat.statSync(a.path).modified;
              final bTime = FileStat.statSync(b.path).modified;
              return bTime.compareTo(aTime);
            } catch (e) {
              return 0;
            }
          });

          // Apply pagination
          final paginatedFiles = allFiles.skip(page * size).take(size).toList();

          // Convert to MediaFile objects
          for (var fileEntity in paginatedFiles) {
            try {
              final file = File(fileEntity.path);
              final stat = await file.stat();

              // Skip system and hidden files
              final fileName = path.basename(file.path);
              if (fileName.startsWith('.') || _isSystemFile(file.path)) {
                continue;
              }

              // Only include common document formats
              if (!_isDocumentFile(file.path)) {
                continue;
              }

              documents.add(
                MediaFile(
                  id: fileEntity.path,
                  path: fileEntity.path,
                  title: fileName,
                  type: MediaType.document,
                  createDateTime: stat.changed,
                  size: stat.size,
                  mimeType: _getMimeType(fileEntity.path),
                ),
              );
              debugPrint('iOS: Added to documents list: ${fileEntity.path}');
            } catch (e) {
              debugPrint('Error processing iOS file ${fileEntity.path}: $e');
            }
          }
        } catch (e) {
          debugPrint('Error accessing iOS documents: $e');
        }
      }
    } catch (e) {
      debugPrint('Error fetching documents: $e');
    }

    debugPrint('Returning ${documents.length} documents');
    debugPrint('========== FINISHED DOCUMENT SEARCH ==========');

    return documents;
  }

  // Check if a file is an image or video (to avoid duplicating media that's already in photos/videos tabs)
  bool _isImageOrVideo(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    return [
      '.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic', '.heif', // Images
      '.mp4', '.mov', '.avi', '.mkv', '.webm', '.m4v', '.3gp', // Videos
    ].contains(ext);
  }

  // Check if a file is a relevant document type to show to users
  bool _isDocumentFile(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    return [
      // Documents
      '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx',
      '.txt', '.rtf', '.csv', '.odt', '.ods', '.odp',

      // Archives
      '.zip', '.rar', '.7z', '.tar', '.gz',

      // Other common formats
      '.epub', '.mobi', '.azw', '.azw3', // E-books
      '.json', '.xml', '.html', '.htm', // Data/web formats
    ].contains(ext);
  }

  // Check if this is a system file that shouldn't be shown to users
  bool _isSystemFile(String filePath) {
    final fileName = path.basename(filePath).toLowerCase();
    final ext = path.extension(filePath).toLowerCase();

    // System file patterns
    if (fileName.startsWith('.') ||
        fileName.endsWith('.tmp') ||
        fileName.contains('thumbs.db') ||
        fileName.contains('.ds_store') ||
        fileName.contains('desktop.ini')) {
      return true;
    }

    // System extensions
    if ([
      '.ini',
      '.dat',
      '.dll',
      '.sys',
      '.log',
      '.cache',
      '.db',
      '.so',
    ].contains(ext)) {
      return true;
    }

    // System paths
    if (filePath.contains('/system/') ||
        filePath.contains('/lib/') ||
        filePath.contains('/.config/') ||
        filePath.contains('/android/')) {
      return true;
    }

    return false;
  }

  // Helper method to get mime type from file extension
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

  // Clear cache files
  Future<void> clearCache() async {
    await PhotoManager.clearFileCache();
  }
}
