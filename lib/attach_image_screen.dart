import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'image_viewer_screen.dart'; // Import the new image viewer screen

class AttachImageScreen extends StatefulWidget {
  final int expenseId;

  const AttachImageScreen({Key? key, required this.expenseId}) : super(key: key);

  @override
  _AttachImageScreenState createState() => _AttachImageScreenState();
}

class _AttachImageScreenState extends State<AttachImageScreen> {
  final ImagePicker _picker = ImagePicker();
  List<File> _attachedImages = [];

  @override
  void initState() {
    super.initState();
    _listImages();
  }

  // Picks an image from the gallery and saves it to the application's document directory.
  Future<void> _pickAndSaveImage(BuildContext context) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        final directory = await getApplicationDocumentsDirectory();
        final imagesDirectory = Directory(join(directory.path, 'attachments', widget.expenseId.toString()));
        if (!await imagesDirectory.exists()) {
          await imagesDirectory.create(recursive: true);
        }

        final String fileName = basename(pickedFile.path);
        final String newPath = join(imagesDirectory.path, fileName);

        await pickedFile.saveTo(newPath);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image saved successfully!')),
        );

        _listImages(); // Refresh the list of images
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving image: $e')),
      );
    }
  }

  // Deletes an image file from the specified path.
  Future<void> _deleteImage(BuildContext context, String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        _listImages(); // Refresh the list
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image deleted successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting image: $e')),
      );
    }
  }

  // Lists all images attached to the current expense.
  Future<void> _listImages() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagesDirectory = Directory(join(directory.path, 'attachments', widget.expenseId.toString()));

      if (await imagesDirectory.exists()) {
        final files = imagesDirectory.listSync().whereType<File>().toList();
        setState(() {
          _attachedImages = files;
        });
      } else {
        setState(() {
          _attachedImages = [];
        });
      }
    } catch (e) {
      // Avoid using context in initState
      print('Error listing images: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Attach Image to Expense ${widget.expenseId}'),
      ),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: () {
              _pickAndSaveImage(context);
            },
            child: const Text('Attach Image'),
          ),
          Expanded(
            child: _attachedImages.isEmpty
                ? const Center(child: Text('No images attached yet.'))
                : ListView.builder(
                    itemCount: _attachedImages.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: InkWell( // Changed to InkWell for tap feedback
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ImageViewerScreen(
                                  imageFile: _attachedImages[index],
                                  imageList: _attachedImages, // Pass the whole list for gallery view
                                  initialIndex: index,        // Pass the current index
                                ),
                              ),
                            );
                          },
                          onLongPress: () {
                            showDialog(
                              context: context,
                              builder: (BuildContext dialogContext) { // Renamed context to avoid conflict
                                return AlertDialog(
                                  title: const Text('Delete Image'),
                                  content: const Text('Are you sure you want to delete this image?'),
                                  actions: <Widget>[
                                    TextButton(
                                      child: const Text('Cancel'),
                                      onPressed: () {
                                        Navigator.of(dialogContext).pop(); // Use dialogContext
                                      },
                                    ),
                                    TextButton(
                                      child: const Text('Delete'),
                                      onPressed: () {
                                        _deleteImage(context, _attachedImages[index].path);
                                        Navigator.of(dialogContext).pop(); // Use dialogContext
                                      },
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                          child: Hero( // Added Hero for smooth transition
                            tag: _attachedImages[index].path, // Unique tag for Hero animation
                            child: Image.file(
                              _attachedImages[index],
                              height: 150,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ); 
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
