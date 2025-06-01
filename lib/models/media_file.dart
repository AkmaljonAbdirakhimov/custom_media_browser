import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

enum MediaType { image, video, document }

class MediaFile {
  final String id;
  final String path;
  final String? title;
  final MediaType type;
  final DateTime? createDateTime;
  final int? size;
  final String? mimeType;
  final AssetEntity? assetEntity;
  final bool isDirectory;

  const MediaFile({
    required this.id,
    required this.path,
    this.title,
    required this.type,
    this.createDateTime,
    this.size,
    this.mimeType,
    this.assetEntity,
    this.isDirectory = false,
  });

  bool get isImage => type == MediaType.image;
  bool get isVideo => type == MediaType.video;
  bool get isDocument => type == MediaType.document;

  File? get file => File(path);

  String get formattedSize {
    if (size == null) return '';
    final kb = size! / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    } else {
      final mb = kb / 1024;
      return '${mb.toStringAsFixed(1)} MB';
    }
  }

  String get displayName {
    if (title != null && title!.isNotEmpty) return title!;
    return path.split('/').last;
  }

  String get extension {
    final fileName = path.split('/').last;
    final parts = fileName.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  String get fileType {
    if (isDirectory) return 'Folder';
    if (isImage) return 'Image';
    if (isVideo) return 'Video';

    final ext = extension;
    switch (ext) {
      case 'pdf':
        return 'PDF Document';
      case 'doc':
      case 'docx':
      case 'odt':
        return 'Word Document';
      case 'xls':
      case 'xlsx':
      case 'ods':
        return 'Spreadsheet';
      case 'ppt':
      case 'pptx':
      case 'odp':
        return 'Presentation';
      case 'txt':
      case 'rtf':
        return 'Text Document';
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return 'Archive';
      case 'epub':
      case 'mobi':
      case 'azw':
      case 'azw3':
        return 'E-Book';
      default:
        return 'Document';
    }
  }

  IconData get iconData {
    if (isDirectory) return Icons.folder;
    if (isImage) return Icons.image;
    if (isVideo) return Icons.videocam;

    // For documents, return icon based on extension
    final ext = extension;
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
      case 'odt':
      case 'rtf':
        return Icons.description;
      case 'xls':
      case 'xlsx':
      case 'csv':
      case 'ods':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
      case 'odp':
        return Icons.slideshow;
      case 'txt':
        return Icons.text_snippet;
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return Icons.folder_zip;
      case 'epub':
      case 'mobi':
      case 'azw':
      case 'azw3':
        return Icons.menu_book;
      case 'html':
      case 'htm':
      case 'xml':
        return Icons.code;
      case 'mp3':
      case 'wav':
      case 'ogg':
      case 'flac':
        return Icons.audio_file;
      default:
        return Icons.insert_drive_file;
    }
  }

  static Future<MediaFile> fromAssetEntity(AssetEntity asset) async {
    final file = await asset.file;
    int? fileSize;

    if (file != null) {
      final fileStat = await file.stat();
      fileSize = fileStat.size;
    }

    return MediaFile(
      id: asset.id,
      path: file?.path ?? '',
      type:
          asset.type == AssetType.image
              ? MediaType.image
              : asset.type == AssetType.video
              ? MediaType.video
              : MediaType.document,
      createDateTime: asset.createDateTime,
      size: fileSize,
      assetEntity: asset,
    );
  }
}
