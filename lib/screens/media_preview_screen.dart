import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/media_file.dart';

class MediaPreviewScreen extends StatefulWidget {
  final MediaFile file;

  const MediaPreviewScreen({Key? key, required this.file}) : super(key: key);

  @override
  State<MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<MediaPreviewScreen> {
  VideoPlayerController? _controller;
  bool _isVideoPlaying = false;
  bool _isVideoInitialized = false;
  bool _isControlsVisible = true;

  @override
  void initState() {
    super.initState();
    if (widget.file.isVideo) {
      _initializeVideoController();
    }

    // Auto-hide controls after a delay
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isControlsVisible = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideoController() async {
    try {
      final controller = VideoPlayerController.file(File(widget.file.path));
      await controller.initialize();
      controller.addListener(_onVideoControllerUpdate);

      if (mounted) {
        setState(() {
          _controller = controller;
          _isVideoInitialized = true;
        });
      } else {
        controller.dispose();
      }
    } catch (e) {
      debugPrint('Error initializing video: $e');
      setState(() {
        _isVideoInitialized = false;
      });
    }
  }

  void _onVideoControllerUpdate() {
    if (_controller == null) return;

    final isPlaying = _controller!.value.isPlaying;
    if (isPlaying != _isVideoPlaying) {
      setState(() {
        _isVideoPlaying = isPlaying;
      });
    }
  }

  void _toggleVideoPlayback() {
    if (_controller == null) return;

    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();

        // Auto-hide controls after a delay
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && _controller!.value.isPlaying) {
            setState(() {
              _isControlsVisible = false;
            });
          }
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _isControlsVisible = !_isControlsVisible;
    });

    if (_isControlsVisible) {
      // Auto-hide controls after a delay if video is playing
      if (_isVideoPlaying) {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && _isVideoPlaying) {
            setState(() {
              _isControlsVisible = false;
            });
          }
        });
      }
    }
  }

  Widget _buildImagePreview() {
    return GestureDetector(
      onTap: _toggleControls,
      child: Center(
        child: Hero(
          tag: widget.file.id,
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.file(
              File(widget.file.path),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.broken_image,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load image',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPreview() {
    if (!_isVideoInitialized || _controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return GestureDetector(
      onTap: _toggleControls,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video player
          Center(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            ),
          ),

          // Play/pause button
          if (_isControlsVisible)
            Center(
              child: IconButton(
                icon: Icon(
                  _isVideoPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  size: 64,
                  color: Colors.white.withOpacity(0.8),
                ),
                onPressed: _toggleVideoPlayback,
              ),
            ),

          // Video progress indicator
          if (_isControlsVisible)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                color: Colors.black45,
                child: Row(
                  children: [
                    Text(
                      _formatDuration(_controller!.value.position),
                      style: const TextStyle(color: Colors.white),
                    ),
                    Expanded(
                      child: Slider(
                        value: _controller!.value.position.inSeconds.toDouble(),
                        min: 0.0,
                        max: _controller!.value.duration.inSeconds.toDouble(),
                        onChanged: (value) {
                          _controller!.seekTo(Duration(seconds: value.toInt()));
                        },
                      ),
                    ),
                    Text(
                      _formatDuration(_controller!.value.duration),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDocumentPreview() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.file.iconData, size: 100, color: Colors.grey[700]),
          const SizedBox(height: 24),
          Text(
            widget.file.displayName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.file.extension.toUpperCase()} File · ${widget.file.formattedSize}',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open with system viewer'),
            onPressed: () {
              // In a real app, we would use url_launcher or other plugins
              // to open the document with the system viewer
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Opening document with system viewer...'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    final twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor:
            _isControlsVisible
                ? Colors.black.withOpacity(0.7)
                : Colors.transparent,
        elevation: 0,
        title: _isControlsVisible ? Text(widget.file.displayName) : null,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child:
            widget.file.isImage
                ? _buildImagePreview()
                : widget.file.isVideo
                ? _buildVideoPreview()
                : _buildDocumentPreview(),
      ),
    );
  }
}
