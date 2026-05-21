import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class AmpliableImage extends StatelessWidget {
  final String url;
  final double? height;
  final double? width;
  final BoxFit? fit;
  final ImageErrorWidgetBuilder? errorBuilder;

  const AmpliableImage(
    this.url, {
    super.key,
    this.height,
    this.width,
    this.fit,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (url.trim().isEmpty) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FullscreenImageViewer(imageUrl: url),
          ),
        );
      },
      child: Stack(
        children: [
          Image.network(
            url,
            height: height,
            width: width,
            fit: fit,
            errorBuilder: errorBuilder,
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.zoom_in, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class FullscreenImageViewer extends StatelessWidget {
  final String imageUrl;

  const FullscreenImageViewer({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Imagen'),
      ),
      body: PhotoView(
        imageProvider: NetworkImage(imageUrl),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 4,
        loadingBuilder: (context, event) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Text(
            'No se pudo cargar la imagen',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
