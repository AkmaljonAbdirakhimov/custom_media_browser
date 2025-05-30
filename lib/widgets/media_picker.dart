import 'package:flutter/material.dart';
import '../models/media_file.dart';
import '../screens/media_browser_screen.dart';

class MediaPicker {
  /// Open the media picker and return selected media files
  static Future<List<MediaFile>?> pickMedia(BuildContext context) async {
    final result = await Navigator.push<List<MediaFile>>(
      context,
      MaterialPageRoute(builder: (context) => const MediaBrowserScreen()),
    );

    return result;
  }

  /// Open the media picker with only image selection enabled
  static Future<List<MediaFile>?> pickImages(BuildContext context) async {
    final result = await pickMedia(context);
    if (result == null) return null;

    return result.where((file) => file.isImage).toList();
  }

  /// Open the media picker with only video selection enabled
  static Future<List<MediaFile>?> pickVideos(BuildContext context) async {
    final result = await pickMedia(context);
    if (result == null) return null;

    return result.where((file) => file.isVideo).toList();
  }

  /// Open the media picker with only document selection enabled
  static Future<List<MediaFile>?> pickDocuments(BuildContext context) async {
    final result = await pickMedia(context);
    if (result == null) return null;

    return result.where((file) => file.isDocument).toList();
  }
}
