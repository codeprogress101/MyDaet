import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class NetworkVideoPlayer extends StatefulWidget {
  const NetworkVideoPlayer({
    super.key,
    required this.url,
    this.height = 160,
    this.borderRadius = 16,
  });

  final String url;
  final double height;
  final double borderRadius;

  @override
  State<NetworkVideoPlayer> createState() => _NetworkVideoPlayerState();
}

class _NetworkVideoPlayerState extends State<NetworkVideoPlayer> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..setLooping(true)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final border = BorderRadius.circular(widget.borderRadius);
    final scheme = Theme.of(context).colorScheme;

    if (!_ready || _controller == null) {
      return Container(
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: border,
          border: Border.all(color: const Color(0xFFE5E0DA)),
          color: scheme.surface,
        ),
        child: const Center(
          child: Icon(Icons.play_circle, color: Color(0xFFE46B2C), size: 42),
        ),
      );
    }

    final controller = _controller!;

    return ClipRRect(
      borderRadius: border,
      child: GestureDetector(
        onTap: () {
          setState(() {
            controller.value.isPlaying ? controller.pause() : controller.play();
          });
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              height: widget.height,
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              ),
            ),
            AnimatedOpacity(
              opacity: controller.value.isPlaying ? 0 : 1,
              duration: const Duration(milliseconds: 200),
              child: const Icon(
                Icons.play_circle,
                color: Color(0xFFE46B2C),
                size: 54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
