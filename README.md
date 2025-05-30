# Custom Media Browser

A Telegram-style custom file and image picker for Flutter. This project provides a complete implementation with a clean, modern UI that lets users browse and select images, videos, and documents directly from the app.

## Features

- 📱 Works on Android and iOS
- 🖼️ Browse and select images with thumbnails
- 🎬 Browse and select videos with previews
- 📄 Browse and select documents with icons
- ✅ Multi-selection support with a beautiful UI
- 🔍 Image/video preview with zoom and controls
- 📂 Album/folder selection for images and videos
- 🔄 Efficient pagination for large media libraries
- 🎯 Built with Flutter 3.x with null safety

## Screenshots

(Add screenshots of your app here)

## Installation

Add the following dependencies to your `pubspec.yaml`:

```yaml
dependencies:
  photo_manager: ^2.7.2
  permission_handler: ^11.1.0
  path_provider: ^2.1.1
  video_player: ^2.8.1
  path: ^1.8.3
```

## Usage

### Basic Usage

```dart
import 'package:your_app/widgets/media_picker.dart';
import 'package:your_app/models/media_file.dart';

// Open the media picker for all media types
Future<void> pickMedia() async {
  List<MediaFile>? selectedFiles = await MediaPicker.pickMedia(context);
  if (selectedFiles != null) {
    // Use the selected files
    for (var file in selectedFiles) {
      print('Selected: ${file.path}');
    }
  }
}

// Only pick images
Future<void> pickImages() async {
  List<MediaFile>? selectedFiles = await MediaPicker.pickImages(context);
  // Handle selected images
}

// Only pick videos
Future<void> pickVideos() async {
  List<MediaFile>? selectedFiles = await MediaPicker.pickVideos(context);
  // Handle selected videos
}

// Only pick documents
Future<void> pickDocuments() async {
  List<MediaFile>? selectedFiles = await MediaPicker.pickDocuments(context);
  // Handle selected documents
}
```

### Permissions

#### Android

Add the following permissions to your `AndroidManifest.xml` file:

```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
<uses-permission android:name="android.permission.ACCESS_MEDIA_LOCATION" />
<uses-permission android:name="android.permission.READ_MEDIA_VISUAL_USER_SELECTED" />
```

For Android 10 (API level 29), you can add:

```xml
android:requestLegacyExternalStorage="true"
```

to your application tag.

#### iOS

Add the following keys to your `Info.plist` file:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs access to your photo library to let you select photos and videos.</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>This app needs access to save photos to your photo library.</string>
<key>PHPhotoLibraryPreventAutomaticLimitedAccessAlert</key>
<true/>
```

## Architecture

The project is organized into the following components:

- **models**: Data models for media files
- **services**: Media access and permission handling
- **widgets**: UI components for the media browser
- **screens**: Complete screens for browsing and selecting media

## Customization

You can customize the appearance and behavior of the media picker by modifying the relevant widgets:

- `MediaBrowserScreen`: The main screen with tabs for different media types
- `MediaGridItem`: The individual item in the grid view
- `MediaPreviewScreen`: The screen for previewing selected media

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [photo_manager](https://pub.dev/packages/photo_manager) for media access
- [permission_handler](https://pub.dev/packages/permission_handler) for permission management
- [video_player](https://pub.dev/packages/video_player) for video playback
