import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:yamata_launcher/ui/widgets/focusable_element.dart';
import 'package:yamata_launcher/ui/widgets/image_lightbox.dart';
import 'package:skeletonizer/skeletonizer.dart';

class ImagesCarousel extends StatefulWidget {
  final List<String> images;
  final double imageWidth;
  final double height;
  final double scrollAmount;

  const ImagesCarousel({
    super.key,
    required this.images,
    this.imageWidth = 300,
    this.height = 200,
    this.scrollAmount = 300,
  });

  @override
  State<ImagesCarousel> createState() => _ImagesCarouselState();
}

class _ImagesCarouselState extends State<ImagesCarousel> {
  final ScrollController _controller = ScrollController();

  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  bool get _isDesktop {
    if (kIsWeb) return true;
    return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateScrollButtons);
  }

  void _updateScrollButtons() {
    if (!_controller.hasClients) return;

    final max = _controller.position.maxScrollExtent;
    final offset = _controller.offset;

    setState(() {
      _canScrollLeft = offset > 0;
      _canScrollRight = offset < max;
    });
  }

  void _handleShow(String image) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => ImageLightbox(
        images: widget.images,
        initialIndex: widget.images.indexOf(image),
      ),
    );
  }

  void _scrollLeft() {
    _controller.animateTo(
      (_controller.offset - widget.scrollAmount).clamp(
        0.0,
        _controller.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _scrollRight() {
    _controller.animateTo(
      (_controller.offset + widget.scrollAmount).clamp(
        0.0,
        _controller.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Widget _navButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Opacity(
      opacity: 0.8,
      child: Material(
        color: Theme.of(context).colorScheme.secondary,
        shape: const CircleBorder(),
        elevation: 4,
        child: IconButton(
          icon: Icon(icon),
          color: Theme.of(context).colorScheme.onSecondary,
          iconSize: 32,
          onPressed: onPressed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: Text(
            "No images available",
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScrollButtons();
    });

    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          ListView.builder(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            itemCount: widget.images.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.all(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: FocusableElement(
                    child: GestureDetector(
                      onTap: () {
                        _handleShow(widget.images[index]);
                      },
                      child: Hero(
                        tag: widget.images[index],
                        child: Image.network(
                          widget.images[index],
                          width: widget.imageWidth,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Skeletonizer(
                              enabled: true,
                              child: Bone(
                                height: widget.height,
                                width: widget.imageWidth,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (_isDesktop && _canScrollLeft)
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: _navButton(
                  icon: Icons.chevron_left,
                  onPressed: _scrollLeft,
                ),
              ),
            ),
          if (_isDesktop && _canScrollRight)
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: _navButton(
                  icon: Icons.chevron_right,
                  onPressed: _scrollRight,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_updateScrollButtons);
    _controller.dispose();
    super.dispose();
  }
}
