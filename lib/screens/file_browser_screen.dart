import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../models/media_file.dart';
import '../services/file_system_service.dart';
import '../widgets/media_grid_item.dart';
import 'media_preview_screen.dart';

class FileBrowserScreen extends StatefulWidget {
  final String? initialDirectory;

  const FileBrowserScreen({super.key, this.initialDirectory});

  @override
  State<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends State<FileBrowserScreen> {
  final FileSystemService _fileSystemService = FileSystemService();

  bool _isLoading = true;
  bool _hasPermission = false;
  String _currentPath = '';
  List<MediaFile> _currentItems = [];
  final Set<String> _selectedItemIds = <String>{};

  @override
  void initState() {
    super.initState();
    _checkPermissionAndLoad();
  }

  Future<void> _checkPermissionAndLoad() async {
    setState(() {
      _isLoading = true;
    });

    final hasPermission = await _fileSystemService.requestPermission();

    setState(() {
      _hasPermission = hasPermission;
      _isLoading = false;
    });

    if (hasPermission) {
      if (widget.initialDirectory != null) {
        await _navigateToDirectory(widget.initialDirectory!);
      } else {
        await _loadRootDirectories();
      }
    }
  }

  Future<void> _loadRootDirectories() async {
    setState(() {
      _isLoading = true;
      _currentPath = '';
    });

    try {
      final rootDirs = await _fileSystemService.getRootDirectories();

      final List<MediaFile> rootItems = [];
      for (var dir in rootDirs) {
        rootItems.add(_fileSystemService.directoryToMediaFile(dir));
      }

      setState(() {
        _currentItems = rootItems;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading root directories: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _navigateToDirectory(String directoryPath) async {
    setState(() {
      _isLoading = true;
      _currentPath = directoryPath;
    });

    try {
      final contents = await _fileSystemService.getDirectoryContents(
        directoryPath,
      );

      final List<MediaFile> items = [];

      // Add directories first
      for (var dir in contents['directories']!) {
        items.add(_fileSystemService.directoryToMediaFile(dir as Directory));
      }

      // Then add files
      for (var file in contents['files']!) {
        items.add(await _fileSystemService.fileToMediaFile(file as File));
      }

      setState(() {
        _currentItems = items;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error navigating to directory: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _navigateUp() async {
    if (_currentPath.isEmpty) return;

    final parentPath = path.dirname(_currentPath);
    await _navigateToDirectory(parentPath);
  }

  void _toggleSelection(MediaFile file) {
    setState(() {
      if (_selectedItemIds.contains(file.id)) {
        _selectedItemIds.remove(file.id);
      } else {
        _selectedItemIds.add(file.id);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedItemIds.clear();
    });
  }

  Future<void> _handleItemTap(MediaFile item) async {
    if (_selectedItemIds.isNotEmpty) {
      _toggleSelection(item);
      return;
    }

    if (item.isDirectory) {
      await _navigateToDirectory(item.path);
    } else {
      await _openFilePreview(item);
    }
  }

  Future<void> _openFilePreview(MediaFile file) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MediaPreviewScreen(file: file)),
    );
  }

  Widget _buildDirectoryListing() {
    if (_currentItems.isEmpty) {
      return Center(
        child: Text(
          'Empty directory',
          style: TextStyle(color: Colors.grey[600], fontSize: 16),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _currentItems.length,
      itemBuilder: (context, index) {
        final item = _currentItems[index];
        final isSelected = _selectedItemIds.contains(item.id);

        return MediaGridItem(
          file: item,
          isSelected: isSelected,
          onTap: () => _handleItemTap(item),
          onLongPress: () => _toggleSelection(item),
        );
      },
    );
  }

  Widget _buildPermissionDeniedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_off, size: 72, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'Storage Permission Denied',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'This app needs access to your device storage to browse files.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                await _checkPermissionAndLoad();
              },
              child: const Text('Request Permission'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentPath.isEmpty ? 'File Browser' : path.basename(_currentPath),
        ),
        leading:
            _currentPath.isEmpty
                ? null
                : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _navigateUp,
                ),
        actions: [
          if (_selectedItemIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearSelection,
            ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : !_hasPermission
              ? _buildPermissionDeniedView()
              : _buildDirectoryListing(),
      bottomNavigationBar:
          _selectedItemIds.isNotEmpty
              ? BottomAppBar(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_selectedItemIds.length} selected',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          // Collect selected files (excluding directories)
                          List<MediaFile> selectedFiles =
                              _currentItems
                                  .where(
                                    (item) =>
                                        _selectedItemIds.contains(item.id) &&
                                        !item.isDirectory,
                                  )
                                  .toList();

                          // Return selected files
                          Navigator.pop(context, selectedFiles);
                        },
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
              )
              : null,
    );
  }
}
