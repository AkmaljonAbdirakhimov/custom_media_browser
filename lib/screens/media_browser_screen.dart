import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/media_file.dart';
import '../services/media_service.dart';
import '../widgets/media_grid_item.dart';
import 'media_preview_screen.dart';

class MediaBrowserScreen extends StatefulWidget {
  const MediaBrowserScreen({super.key});

  @override
  State<MediaBrowserScreen> createState() => _MediaBrowserScreenState();
}

class _MediaBrowserScreenState extends State<MediaBrowserScreen>
    with SingleTickerProviderStateMixin {
  final MediaService _mediaService = MediaService();

  late TabController _tabController;
  int _currentTab = 0;

  List<AssetPathEntity> _imageAlbums = [];
  List<AssetPathEntity> _videoAlbums = [];
  AssetPathEntity? _selectedImageAlbum;
  AssetPathEntity? _selectedVideoAlbum;

  List<MediaFile> _images = [];
  List<MediaFile> _videos = [];
  List<MediaFile> _documents = [];

  bool _isLoading = true;
  bool _hasPermission = false;
  bool _hasMoreImages = true;
  bool _hasMoreVideos = true;
  bool _hasMoreDocuments = true;
  int _imagesPage = 0;
  int _videosPage = 0;
  int _documentsPage = 0;
  final int _pageSize = 30;

  final Set<String> _selectedMediaIds = <String>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _checkPermissionAndLoadMedia();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.index != _currentTab) {
      setState(() {
        _currentTab = _tabController.index;
      });
    }
  }

  Future<void> _checkPermissionAndLoadMedia() async {
    setState(() {
      _isLoading = true;
    });

    final hasPermission = await _mediaService.requestPermission();

    setState(() {
      _hasPermission = hasPermission;
      _isLoading = false;
    });

    if (hasPermission) {
      await _loadAlbums();
    }
  }

  Future<void> _loadAlbums() async {
    try {
      // Load image albums
      final imageAlbums = await _mediaService.getAlbums(
        type: RequestType.image,
      );
      if (imageAlbums.isNotEmpty) {
        setState(() {
          _imageAlbums = imageAlbums;
          _selectedImageAlbum = imageAlbums.first;
        });
        await _loadImages();
      }

      // Load video albums
      final videoAlbums = await _mediaService.getAlbums(
        type: RequestType.video,
      );
      if (videoAlbums.isNotEmpty) {
        setState(() {
          _videoAlbums = videoAlbums;
          _selectedVideoAlbum = videoAlbums.first;
        });
        await _loadVideos();
      }

      // Load documents (doesn't require albums)
      await _loadDocuments();
    } catch (e) {
      debugPrint('Error loading albums: $e');
    }
  }

  Future<void> _loadImages() async {
    if (_selectedImageAlbum == null || !_hasMoreImages) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final newImages = await _mediaService.getAssetsFromAlbum(
        _selectedImageAlbum!,
        page: _imagesPage,
        size: _pageSize,
      );

      setState(() {
        if (_imagesPage == 0) {
          _images = newImages;
        } else {
          _images.addAll(newImages);
        }
        _hasMoreImages = newImages.length >= _pageSize;
        _imagesPage++;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading images: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadVideos() async {
    if (_selectedVideoAlbum == null || !_hasMoreVideos) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final newVideos = await _mediaService.getAssetsFromAlbum(
        _selectedVideoAlbum!,
        page: _videosPage,
        size: _pageSize,
      );

      setState(() {
        if (_videosPage == 0) {
          _videos = newVideos;
        } else {
          _videos.addAll(newVideos);
        }
        _hasMoreVideos = newVideos.length >= _pageSize;
        _videosPage++;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading videos: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDocuments() async {
    if (!_hasMoreDocuments) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final newDocuments = await _mediaService.getDocuments(
        page: _documentsPage,
        size: _pageSize,
      );

      setState(() {
        if (_documentsPage == 0) {
          _documents = newDocuments;
        } else {
          _documents.addAll(newDocuments);
        }
        _hasMoreDocuments = newDocuments.length >= _pageSize;
        _documentsPage++;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading documents: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _reloadDocuments() async {
    setState(() {
      _documentsPage = 0;
      _hasMoreDocuments = true;
      _documents.clear();
    });

    await _loadDocuments();
  }

  Future<void> _refreshMedia() async {
    setState(() {
      _imagesPage = 0;
      _videosPage = 0;
      _documentsPage = 0;
      _hasMoreImages = true;
      _hasMoreVideos = true;
      _hasMoreDocuments = true;
      _selectedMediaIds.clear();
    });

    switch (_currentTab) {
      case 0:
        await _loadImages();
        break;
      case 1:
        await _loadVideos();
        break;
      case 2:
        await _loadDocuments();
        break;
    }
  }

  void _toggleSelection(MediaFile file) {
    setState(() {
      if (_selectedMediaIds.contains(file.id)) {
        _selectedMediaIds.remove(file.id);
      } else {
        _selectedMediaIds.add(file.id);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedMediaIds.clear();
    });
  }

  void _changeAlbum(AssetPathEntity? album, MediaType type) {
    setState(() {
      if (type == MediaType.image) {
        _selectedImageAlbum = album;
        _imagesPage = 0;
        _hasMoreImages = true;
        _images.clear();
      } else if (type == MediaType.video) {
        _selectedVideoAlbum = album;
        _videosPage = 0;
        _hasMoreVideos = true;
        _videos.clear();
      }
    });

    if (type == MediaType.image) {
      _loadImages();
    } else if (type == MediaType.video) {
      _loadVideos();
    }
  }

  Future<void> _openMediaPreview(MediaFile file) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MediaPreviewScreen(file: file)),
    );
  }

  Widget _buildAlbumSelector(MediaType type) {
    final albums = type == MediaType.image ? _imageAlbums : _videoAlbums;
    final selectedAlbum =
        type == MediaType.image ? _selectedImageAlbum : _selectedVideoAlbum;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DropdownButton<AssetPathEntity>(
        value: selectedAlbum,
        isExpanded: true,
        underline: Container(height: 1, color: Colors.grey[300]),
        onChanged: (album) {
          if (album != null) {
            _changeAlbum(album, type);
          }
        },
        items:
            albums.map((album) {
              return DropdownMenuItem<AssetPathEntity>(
                value: album,
                child: Text(
                  album.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildGridView(
    List<MediaFile> files,
    bool hasMore,
    Function() loadMore,
  ) {
    if (files.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No files found',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),

            // Only show for the Files tab
            if (_currentTab == 2)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: ElevatedButton.icon(
                  onPressed: _reloadDocuments,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Scan for Files'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (scrollInfo.metrics.pixels >=
            scrollInfo.metrics.maxScrollExtent * 0.8) {
          if (!_isLoading && hasMore) {
            loadMore();
          }
        }
        return true;
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 1,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: files.length + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= files.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final file = files[index];
          final isSelected = _selectedMediaIds.contains(file.id);

          return MediaGridItem(
            file: file,
            isSelected: isSelected,
            onTap: () {
              if (_selectedMediaIds.isNotEmpty) {
                _toggleSelection(file);
              } else {
                _openMediaPreview(file);
              }
            },
            onLongPress: () {
              _toggleSelection(file);
            },
          );
        },
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_currentTab) {
      case 0:
        return Column(
          children: [
            _buildAlbumSelector(MediaType.image),
            Expanded(
              child: _buildGridView(_images, _hasMoreImages, _loadImages),
            ),
          ],
        );
      case 1:
        return Column(
          children: [
            _buildAlbumSelector(MediaType.video),
            Expanded(
              child: _buildGridView(_videos, _hasMoreVideos, _loadVideos),
            ),
          ],
        );
      case 2:
        return Column(
          children: [
            if (_documents.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Rescan for files',
                      onPressed: _reloadDocuments,
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _buildGridView(
                _documents,
                _hasMoreDocuments,
                _loadDocuments,
              ),
            ),
          ],
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildPermissionDeniedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.no_photography, size: 72, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'Permission Denied',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'This app needs access to your media to display and select files.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                await _mediaService.openSettings();
              },
              child: const Text('Open Settings'),
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
        title: const Text('Media Browser'),
        actions: [
          if (_selectedMediaIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearSelection,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Photos'),
            Tab(text: 'Videos'),
            Tab(text: 'Files'),
          ],
        ),
      ),
      body:
          _isLoading &&
                  (_images.isEmpty && _videos.isEmpty && _documents.isEmpty)
              ? const Center(child: CircularProgressIndicator())
              : !_hasPermission
              ? _buildPermissionDeniedView()
              : RefreshIndicator(
                onRefresh: _refreshMedia,
                child: _buildTabContent(),
              ),
      bottomNavigationBar:
          _selectedMediaIds.isNotEmpty
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
                        '${_selectedMediaIds.length} selected',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          // Collect selected files
                          List<MediaFile> selectedFiles = [];
                          for (var id in _selectedMediaIds) {
                            if (_currentTab == 0) {
                              selectedFiles.addAll(
                                _images.where((file) => file.id == id),
                              );
                            } else if (_currentTab == 1) {
                              selectedFiles.addAll(
                                _videos.where((file) => file.id == id),
                              );
                            } else {
                              selectedFiles.addAll(
                                _documents.where((file) => file.id == id),
                              );
                            }
                          }

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
