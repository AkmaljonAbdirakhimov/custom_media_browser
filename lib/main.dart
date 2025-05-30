import 'dart:io';
import 'package:flutter/material.dart';
import 'models/media_file.dart';
import 'widgets/media_picker.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Custom Media Browser',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<MediaFile> _selectedFiles = [];

  Future<void> _openMediaPicker() async {
    final result = await MediaPicker.pickMedia(context);
    if (result != null) {
      setState(() {
        _selectedFiles = result;
      });
    }
  }

  Future<void> _openImagePicker() async {
    final result = await MediaPicker.pickImages(context);
    if (result != null) {
      setState(() {
        _selectedFiles = result;
      });
    }
  }

  Future<void> _openVideoPicker() async {
    final result = await MediaPicker.pickVideos(context);
    if (result != null) {
      setState(() {
        _selectedFiles = result;
      });
    }
  }

  Future<void> _openDocumentPicker() async {
    final result = await MediaPicker.pickDocuments(context);
    if (result != null) {
      setState(() {
        _selectedFiles = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Custom Media Browser')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Telegram-style Media Picker',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'A custom media picker that allows browsing and selecting images, videos, and documents with a beautiful UI.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _openMediaPicker,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Open Media Picker (All)'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _openImagePicker,
                        icon: const Icon(Icons.image),
                        label: const Text('Images'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _openVideoPicker,
                        icon: const Icon(Icons.videocam),
                        label: const Text('Videos'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _openDocumentPicker,
                        icon: const Icon(Icons.description),
                        label: const Text('Docs'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child:
                _selectedFiles.isEmpty
                    ? Center(
                      child: Text(
                        'No files selected',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    )
                    : _buildSelectedFilesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedFilesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Selected Files (${_selectedFiles.length})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _selectedFiles.length,
            itemBuilder: (context, index) {
              final file = _selectedFiles[index];
              return ListTile(
                leading: _buildFilePreview(file),
                title: Text(
                  file.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${file.isImage
                      ? 'Image'
                      : file.isVideo
                      ? 'Video'
                      : 'Document'} • ${file.formattedSize}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    setState(() {
                      _selectedFiles.removeAt(index);
                    });
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilePreview(MediaFile file) {
    if (file.isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.file(
          File(file.path),
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.broken_image);
          },
        ),
      );
    } else if (file.isVideo) {
      return Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              width: 48,
              height: 48,
              color: Colors.grey[300],
              child: Image.file(
                File(file.path),
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    width: 48,
                    height: 48,
                  );
                },
              ),
            ),
          ),
          const Icon(Icons.play_circle_fill, color: Colors.white, size: 24),
        ],
      );
    } else {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(file.iconData, color: Colors.grey[700]),
      );
    }
  }
}
