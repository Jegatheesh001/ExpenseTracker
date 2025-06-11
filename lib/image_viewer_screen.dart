import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class ImageViewerScreen extends StatelessWidget {
  final File imageFile;
  final List<File>? imageList; // Optional: for gallery view
  final int? initialIndex; // Optional: for gallery view

  const ImageViewerScreen({
    Key? key,
    required this.imageFile,
    this.imageList,
    this.initialIndex,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Viewer'),
        backgroundColor: Colors.black, // Darker theme for image viewing
        elevation: 0, // Remove shadow for a cleaner look
      ),
      backgroundColor: Colors.black, // Set background color for the body as well
      body: imageList != null && imageList!.isNotEmpty
          ? PhotoViewGallery.builder(
              itemCount: imageList!.length,
              builder: (context, index) {
                return PhotoViewGalleryPageOptions(
                  imageProvider: FileImage(imageList![index]),
                  initialScale: PhotoViewComputedScale.contained,
                  heroAttributes: PhotoViewHeroAttributes(tag: imageList![index].path),
                  minScale: PhotoViewComputedScale.contained * 0.8,
                  maxScale: PhotoViewComputedScale.covered * 2.5, // Increased max zoom slightly
                );
              },
              scrollPhysics: const BouncingScrollPhysics(),
              backgroundDecoration: const BoxDecoration(
                color: Colors.black,
              ),
              pageController: PageController(initialPage: initialIndex ?? imageList!.indexOf(imageFile)),
              loadingBuilder: (context, event) => _buildLoadingIndicator(event),
            )
          : PhotoView(
              imageProvider: FileImage(imageFile),
              initialScale: PhotoViewComputedScale.contained,
              heroAttributes: PhotoViewHeroAttributes(tag: imageFile.path),
              minScale: PhotoViewComputedScale.contained * 0.8,
              maxScale: PhotoViewComputedScale.covered * 2.5, // Increased max zoom slightly
              backgroundDecoration: const BoxDecoration(
                color: Colors.black,
              ),
              loadingBuilder: (context, event) => _buildLoadingIndicator(event),
            ),
    );
  }

  Widget _buildLoadingIndicator(ImageChunkEvent? event) {
    return Center(
      child: CircularProgressIndicator(
        value: event == null || event.expectedTotalBytes == null ? null : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
      ),
    );
  }
}