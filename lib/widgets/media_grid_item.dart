import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/media_file.dart';

class MediaGridItem extends StatefulWidget {
  final MediaFile file;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const MediaGridItem({
    Key? key,
    required this.file,
    this.isSelected = false,
    required this.onTap,
    required this.onLongPress,
  }) : super(key: key);

  @override
  State<MediaGridItem> createState() => _MediaGridItemState();
}

class _MediaGridItemState extends State<MediaGridItem> {
  VideoPlayerController? _controller;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.file.isVideo) {
      _initializeVideoController();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MediaGridItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.id != widget.file.id && widget.file.isVideo) {
      _initializeVideoController();
    }
  }

  Future<void> _initializeVideoController() async {
    _controller?.dispose();
    try {
      final controller = VideoPlayerController.file(File(widget.file.path));
      await controller.initialize();
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

  // Get color based on file type
  Color _getFileTypeColor() {
    if (widget.file.isDirectory) {
      return Colors.amber[700]!;
    }

    final ext = widget.file.extension.toLowerCase();

    // Document colors
    if (['pdf'].contains(ext)) {
      return Colors.red[700]!;
    } else if (['doc', 'docx', 'odt', 'rtf', 'txt'].contains(ext)) {
      return Colors.blue[700]!;
    } else if (['xls', 'xlsx', 'csv', 'ods'].contains(ext)) {
      return Colors.green[700]!;
    } else if (['ppt', 'pptx', 'odp'].contains(ext)) {
      return Colors.orange[700]!;
    } else if (['zip', 'rar', '7z', 'tar', 'gz'].contains(ext)) {
      return Colors.purple[700]!;
    } else if (['epub', 'mobi', 'azw', 'azw3'].contains(ext)) {
      return Colors.teal[700]!;
    }

    return Colors.grey[700]!;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Media thumbnail/preview
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            color: Colors.grey[200],
            child: _buildMediaPreview(),
          ),
        ),

        // Selection indicator overlay
        if (widget.isSelected)
          Container(
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
          ),

        // Selection checkbox
        Positioned(
          top: 4,
          right: 4,
          child: Container(
            decoration: BoxDecoration(
              color: widget.isSelected ? Colors.blue : Colors.black45,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: const EdgeInsets.all(2.0),
              child:
                  widget.isSelected
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : const SizedBox(width: 16, height: 16),
            ),
          ),
        ),

        // Video duration
        if (widget.file.isVideo && !widget.file.isDirectory)
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_arrow, size: 12, color: Colors.white),
                  const SizedBox(width: 2),
                  Text(
                    _formatDuration(widget.file.assetEntity?.duration ?? 0),
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),

        // Document type indicator
        if (widget.file.isDocument && !widget.file.isDirectory)
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                widget.file.extension.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

        // Directory indicator
        if (widget.file.isDirectory)
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'FOLDER',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

        // Tap detector
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            splashColor: Colors.white24,
          ),
        ),
      ],
    );
  }

  Widget _buildMediaPreview() {
    if (widget.file.isDirectory) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder, size: 48, color: Colors.amber[700]),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                widget.file.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    } else if (widget.file.isImage) {
      return Image.file(
        File(widget.file.path),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorPlaceholder();
        },
      );
    } else if (widget.file.isVideo &&
        _isVideoInitialized &&
        _controller != null) {
      return AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: VideoPlayer(_controller!),
      );
    } else if (widget.file.isDocument) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.file.iconData, size: 48, color: _getFileTypeColor()),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                widget.file.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return _buildErrorPlaceholder();
    }
  }

  Widget _buildErrorPlaceholder() {
    return Center(
      child: Icon(Icons.broken_image, size: 48, color: Colors.grey[400]),
    );
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    final twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}
