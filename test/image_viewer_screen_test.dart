import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:expense_tracker/screens/media/image_viewer_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// 1x1 transparent PNG so Image.file / PhotoView decodes cleanly without network or assets.
final Uint8List _validPngBytes = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, //
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, //
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, //
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, //
  0x42, 0x60, 0x82,
]);

class _FakeFilePickerPlatform extends FilePickerPlatform {
  _FakeFilePickerPlatform(this.onSaveFile);

  final Future<Uri?> Function({
    required String fileName,
    required Uint8List bytes,
  })
  onSaveFile;

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) {
    return onSaveFile(fileName: fileName, bytes: bytes);
  }
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var i = 0; i < 40 && !condition(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump();
  }
  expect(condition(), isTrue);
}

void main() {
  late FilePickerPlatform originalPlatform;
  late Directory tempDir;
  late File imageFile;

  setUp(() async {
    originalPlatform = FilePickerPlatform.instance;
    tempDir = await Directory.systemTemp.createTemp('image_viewer_test_');
    imageFile = File('${tempDir.path}${Platform.pathSeparator}receipt.png');
    await imageFile.writeAsBytes(_validPngBytes);
  });

  tearDown(() async {
    FilePickerPlatform.instance = originalPlatform;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    if (await tempDir.exists()) {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  });

  testWidgets('ignores save error after ImageViewerScreen is unmounted', (
    tester,
  ) async {
    final saveStarted = Completer<void>();
    final saveCompleter = Completer<Uri?>();
    FilePickerPlatform.instance = _FakeFilePickerPlatform(({
      required fileName,
      required bytes,
    }) {
      if (!saveStarted.isCompleted) {
        saveStarted.complete();
      }
      return saveCompleter.future;
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ImageViewerScreen(imageFile: imageFile),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    // Let the route transition finish without waiting on FileImage's spinner.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byIcon(Icons.download));
    await _pumpUntil(tester, () => saveStarted.isCompleted);

    // Pop the viewer while saveFile is still in flight.
    final navigatorState = tester.state<NavigatorState>(find.byType(Navigator));
    navigatorState.pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(ImageViewerScreen), findsNothing);

    saveCompleter.completeError(Exception('disk full'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Error saving image'), findsNothing);
  });

  testWidgets('shows error snackbar when saveFile fails while mounted', (
    tester,
  ) async {
    final saveAttempted = Completer<void>();
    FilePickerPlatform.instance = _FakeFilePickerPlatform(({
      required fileName,
      required bytes,
    }) async {
      saveAttempted.complete();
      throw Exception('permission denied');
    });

    await tester.pumpWidget(
      MaterialApp(home: ImageViewerScreen(imageFile: imageFile)),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.download));
    await _pumpUntil(tester, () => saveAttempted.isCompleted);
    await tester.pump();

    expect(
      find.textContaining('Error saving image: Exception: permission denied'),
      findsOneWidget,
    );
  });
}
