import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class ImageViewerScreen extends StatefulWidget {
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
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex ?? (widget.imageList?.indexOf(widget.imageFile) ?? 0);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Viewer'),
        backgroundColor: Colors.black, // Darker theme for image viewing
        elevation: 0, // Remove shadow for a cleaner look
      ),
      backgroundColor: Colors.black, // Set background color for the body as well
      body: Stack(
        children: [
          widget.imageList != null && widget.imageList!.isNotEmpty
              ? PhotoViewGallery.builder(
                  itemCount: widget.imageList!.length,
                  builder: (context, index) {
                    return PhotoViewGalleryPageOptions(
                      imageProvider: FileImage(widget.imageList![index]),
                      initialScale: PhotoViewComputedScale.contained,
                      heroAttributes:
                          PhotoViewHeroAttributes(tag: widget.imageList![index].path),
                      minScale: PhotoViewComputedScale.contained * 0.8,
                      maxScale: PhotoViewComputedScale.covered *
                          2.5, // Increased max zoom slightly
                    );
                  },
                  scrollPhysics: const BouncingScrollPhysics(),
                  backgroundDecoration: const BoxDecoration(
                    color: Colors.black,
                  ),
                  pageController: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  loadingBuilder: (context, event) =>
                      _buildLoadingIndicator(event),
                )
              : PhotoView(
                  imageProvider: FileImage(widget.imageFile),
                  initialScale: PhotoViewComputedScale.contained,
                  heroAttributes: PhotoViewHeroAttributes(tag: widget.imageFile.path),
                  minScale: PhotoViewComputedScale.contained * 0.8,
                  maxScale: PhotoViewComputedScale.covered *
                      2.5, // Increased max zoom slightly
                  backgroundDecoration: const BoxDecoration(
                    color: Colors.black,
                  ),
                  loadingBuilder: (context, event) =>
                      _buildLoadingIndicator(event),
                ),
          Positioned(
            bottom: 20,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.download, color: Colors.white),
              onPressed: _saveImage,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator(ImageChunkEvent? event) {
    return Center(
      child: CircularProgressIndicator(
        value: event == null || event.expectedTotalBytes == null
            ? null
            : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
      ),
    );
  }

  Future<void> _saveImage() async {
    try {
      final fileToSave = widget.imageList != null && widget.imageList!.isNotEmpty
          ? widget.imageList![_currentIndex]
          : widget.imageFile;
      final bytes = await fileToSave.readAsBytes();
      final fileName = fileToSave.path.split(Platform.pathSeparator).last;
      await FilePicker.platform.saveFile(
        fileName: fileName,
        bytes: bytes,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image saved successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving image: $e')),
      );
    }
  }
}