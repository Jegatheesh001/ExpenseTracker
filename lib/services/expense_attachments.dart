import 'dart:io';

import 'package:path/path.dart' as path;

class ExpenseAttachments {
  ExpenseAttachments(Directory documents)
    : _root = Directory(path.join(documents.path, 'attachments'));

  final Directory _root;

  Future<void> deleteForExpense(int expenseId) async {
    if (await FileSystemEntity.type(_root.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      return;
    }
    final directory = Directory(path.join(_root.path, expenseId.toString()));
    if (await FileSystemEntity.type(directory.path, followLinks: false) ==
        FileSystemEntityType.directory) {
      await directory.delete(recursive: true);
    }
  }

  Future<List<File>> filesForBackup(Iterable<int> expenseIds) async {
    final files = <File>[];
    if (await FileSystemEntity.type(_root.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      return files;
    }
    final directoryNames = expenseIds.map((id) => id.toString()).toSet();
    await for (final directory in _root.list(followLinks: false)) {
      if (directory is Directory &&
          directoryNames.contains(path.basename(directory.path))) {
        await for (final file in directory.list(followLinks: false)) {
          if (file is File) files.add(file);
        }
      }
    }
    return files;
  }
}
