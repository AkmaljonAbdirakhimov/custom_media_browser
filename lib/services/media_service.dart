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

    try {
      if (Platform.isAndroid) {
        // Get directories using path_provider
        final List<Directory?> directories = [];

        // App's documents directory
        final appDocDir = await getApplicationDocumentsDirectory();
        directories.add(appDocDir);

        // External storage directory
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          directories.add(externalDir);
        }

        // External documents directory
        final externalDocs = await getExternalStorageDirectories(
          type: StorageDirectory.documents,
        );
        if (externalDocs != null) {
          directories.addAll(externalDocs);
        }

        // External downloads directory
        final externalDownloads = await getExternalStorageDirectories(
          type: StorageDirectory.downloads,
        );
        if (externalDownloads != null) {
          directories.addAll(externalDownloads);
        }

        // Process each directory
        List<FileSystemEntity> allFiles = [];

        for (Directory? dir in directories) {
          if (dir != null && dir.existsSync()) {
            try {
              final dirFiles =
                  dir
                      .listSync(recursive: true)
                      .where(
                        (entity) =>
                            FileSystemEntity.isFileSync(entity.path) &&
                            _isDocumentFile(entity.path),
                      )
                      .toList();
              allFiles.addAll(dirFiles);
            } catch (e) {
              debugPrint('Error accessing directory ${dir.path}: $e');
            }
          }
        }

        // Sort by modification time (newest first)
        allFiles.sort((a, b) {
          final aTime = FileStat.statSync(a.path).modified;
          final bTime = FileStat.statSync(b.path).modified;
          return bTime.compareTo(aTime);
        });

        // Apply pagination
        final paginatedFiles = allFiles.skip(page * size).take(size).toList();

        // Convert to MediaFile objects
        for (var fileEntity in paginatedFiles) {
          try {
            final file = File(fileEntity.path);
            final stat = await file.stat();

            documents.add(
              MediaFile(
                id: fileEntity.path,
                path: fileEntity.path,
                title: path.basename(fileEntity.path),
                type: MediaType.document,
                createDateTime: stat.changed,
                size: stat.size,
                mimeType: _getMimeType(fileEntity.path),
              ),
            );
          } catch (e) {
            debugPrint('Error processing file ${fileEntity.path}: $e');
          }
        }
      } else if (Platform.isIOS) {
        // On iOS, we use the application documents directory
        try {
          final appDocDir = await getApplicationDocumentsDirectory();

          if (appDocDir.existsSync()) {
            final files =
                appDocDir
                    .listSync(recursive: true)
                    .where(
                      (entity) =>
                          FileSystemEntity.isFileSync(entity.path) &&
                          _isDocumentFile(entity.path),
                    )
                    .skip(page * size)
                    .take(size)
                    .toList();

            for (var fileEntity in files) {
              final file = File(fileEntity.path);
              final stat = await file.stat();

              documents.add(
                MediaFile(
                  id: fileEntity.path,
                  path: fileEntity.path,
                  title: path.basename(fileEntity.path),
                  type: MediaType.document,
                  createDateTime: stat.changed,
                  size: stat.size,
                  mimeType: _getMimeType(fileEntity.path),
                ),
              );
            }
          }
        } catch (e) {
          debugPrint('Error accessing iOS documents: $e');
        }
      }
    } catch (e) {
      debugPrint('Error fetching documents: $e');
    }

    return documents;
  }

  // Helper method to identify document files
  bool _isDocumentFile(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    return [
      '.pdf',
      '.doc',
      '.docx',
      '.xls',
      '.xlsx',
      '.ppt',
      '.pptx',
      '.txt',
      '.rtf',
      '.zip',
      '.rar',
    ].contains(ext);
  }

  // Helper method to get mime type from file extension
  String? _getMimeType(String filePath) {
    final ext = path.extension(filePath).toLowerCase();

    switch (ext) {
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
        return null;
    }
  }

  // Clear cache files
  Future<void> clearCache() async {
    await PhotoManager.clearFileCache();
  }
}
