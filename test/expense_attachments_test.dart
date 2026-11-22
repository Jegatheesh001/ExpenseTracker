import 'dart:io';

import 'package:expense_tracker/services/expense_attachments.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  test(
    'deletion removes only the selected expense attachment directory',
    () async {
      final documents = await Directory.systemTemp.createTemp(
        'expense_attachments_',
      );
      addTearDown(() => documents.delete(recursive: true));

      Future<File> receipt(int id) async {
        final file = File(
          path.join(documents.path, 'attachments', '$id', 'receipt.jpg'),
        );
        await file.parent.create(recursive: true);
        return file.writeAsString('synthetic receipt');
      }

      final deleted = await receipt(41);
      final kept = await receipt(42);
      final attachments = ExpenseAttachments(documents);
      expect(
        (await attachments.filesForBackup([42])).map((file) => file.path),
        [kept.path],
      );
      expect(await deleted.exists(), isTrue);

      await attachments.deleteForExpense(41);
      expect(await deleted.parent.exists(), isFalse);
      expect(await kept.exists(), isTrue);
      await attachments.deleteForExpense(41);
    },
  );
}
