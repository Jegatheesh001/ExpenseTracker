import 'dart:io'; // For File operations
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:share_plus/share_plus.dart';

import 'package:expense_tracker/utils/pref_keys.dart';
import 'package:expense_tracker/db/entity.dart';
import 'package:expense_tracker/db/persistence_context.dart';
import 'package:expense_tracker/db/database_helper.dart';
import 'package:expense_tracker/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DataBackup {
  bool _isLoadingDialogShowing = false;

  static bool _isAllowedPreferenceImport(String key) {
    const safeExactKeys = {
      PrefKeys.username,
      PrefKeys.isDarkMode,
      PrefKeys.showExpStatusBar,
      PrefKeys.dailyBackupReminderEnabled,
      PrefKeys.lastBackupReminderTimestamp,
      PrefKeys.lastBackupTimestamp,
      PrefKeys.balanceVisible,
      PrefKeys.profileId,
      PrefKeys.monthlyLimit,
      PrefKeys.dailyLimit,
      PrefKeys.ocrEnabled,
      PrefKeys.ocrModelName,
      PrefKeys.aiProvider,
      PrefKeys.geminiModelName,
      PrefKeys.openaiModelName,
      PrefKeys.dailyReminderEnabled,
      PrefKeys.dailyReminderHour,
      PrefKeys.dailyReminderMinute,
      PrefKeys.subscriptionRemindersEnabled,
      PrefKeys.subscriptionReminderAdvanceDays,
      PrefKeys.subscriptionReminderHour,
      PrefKeys.subscriptionReminderMinute,
    };

    if (safeExactKeys.contains(key)) return true;

    // Profile-specific keys
    if (key.startsWith('${PrefKeys.selectedCurrency}-') ||
        key.startsWith('${PrefKeys.walletAmount}-') ||
        key.startsWith('${PrefKeys.cashAmount}-') ||
        key.startsWith('${PrefKeys.bankAmount}-')) {
      return true;
    }

    return false;
  }

  static bool _isSensitivePreferenceKey(String key) {
    if (key.startsWith('${PrefKeys.lastAIInsights}_')) return true;
    if (key == PrefKeys.geminiApiKey ||
        key == PrefKeys.openaiApiKey ||
        key == PrefKeys.openaiBaseUrl ||
        key == PrefKeys.isDeveloperMode) {
      return true;
    }
    final lower = key.toLowerCase();
    if (lower.contains('apikey') ||
        lower.contains('secret') ||
        lower.contains('token') ||
        lower.contains('password')) {
      return true;
    }
    return false;
  }

  void _showLoadingDialog(BuildContext context, ValueNotifier<String> statusNotifier) {
    _isLoadingDialogShowing = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            content: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: ValueListenableBuilder<String>(
                      valueListenable: statusNotifier,
                      builder: (context, status, _) {
                        return Text(
                          status,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) {
      _isLoadingDialogShowing = false;
    });
  }

  void _hideLoadingDialog(BuildContext context) {
    if (_isLoadingDialogShowing && context.mounted) {
      _isLoadingDialogShowing = false;
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<void> importData(BuildContext context, VoidCallback refreshMainPage) async {
    // 1. Pick file before showing loader
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip', 'txt'],
    );

    if (result == null || result.files.single.path == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File selection cancelled.')),
      );
      return;
    }

    final pickedFilePath = result.files.single.path!;
    final isZip = pickedFilePath.toLowerCase().endsWith('.zip');
    final statusNotifier = ValueNotifier<String>('Reading backup file...');
    if (!context.mounted) return;
    final theme = Theme.of(context);
    _showLoadingDialog(context, statusNotifier);

    Directory? tempExtractDir;
    try {
      if (isZip) {
        statusNotifier.value = 'Extracting backup archive...';
        final tempDir = await getTemporaryDirectory();
        tempExtractDir = Directory(join(tempDir.path, 'import_${DateTime.now().millisecondsSinceEpoch}'));
        await tempExtractDir.create(recursive: true);

        await extractFileToDisk(pickedFilePath, tempExtractDir.path);

        // Find data file
        File? dataFile = File(join(tempExtractDir.path, 'backup_data.txt'));
        if (!await dataFile.exists()) {
          final txtFiles = tempExtractDir.listSync().whereType<File>().where((f) => f.path.endsWith('.txt')).toList();
          if (txtFiles.isNotEmpty) {
            dataFile = txtFiles.first;
          } else {
            dataFile = null;
          }
        }

        if (dataFile == null || !await dataFile.exists()) {
          throw Exception('No valid data file found inside the backup archive.');
        }

        statusNotifier.value = 'Restoring database records...';
        final errors = await _parseAndInsertDataStream(dataFile, statusNotifier);

        // Restore image attachments from zip
        final attachmentsDir = Directory(join(tempExtractDir.path, 'attachments'));
        if (await attachmentsDir.exists()) {
          statusNotifier.value = 'Restoring image attachments...';
          final appDocDir = await getApplicationDocumentsDirectory();
          final targetAttachmentsDir = Directory(join(appDocDir.path, 'attachments'));

          final expenseDirs = attachmentsDir.listSync().whereType<Directory>().toList();
          for (var expDir in expenseDirs) {
            final rawExpenseId = basename(expDir.path);
            final expenseId = int.tryParse(rawExpenseId);
            if (expenseId == null || expenseId <= 0) continue;

            final destExpDir = Directory(join(targetAttachmentsDir.path, expenseId.toString()));
            if (!await destExpDir.exists()) {
              await destExpDir.create(recursive: true);
            }

            final files = expDir.listSync().whereType<File>().toList();
            for (var file in files) {
              final safeFileName = basename(file.path).trim();
              if (safeFileName.isEmpty ||
                  safeFileName == '.' ||
                  safeFileName == '..' ||
                  safeFileName.contains('/') ||
                  safeFileName.contains('\\')) {
                continue;
              }
              final destFile = File(join(destExpDir.path, safeFileName));
              final canonicalDest = canonicalize(destFile.path);
              final canonicalDir = canonicalize(destExpDir.path);
              if (canonicalDest.startsWith(canonicalDir)) {
                await file.copy(destFile.path);
              }
            }
          }
        }

        try {
          await NotificationService().syncAllNotifications();
        } catch (e) {
          debugPrint('Error syncing notifications after restore: $e');
        }

        if (!context.mounted) return;
        _hideLoadingDialog(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Data imported successfully! ${errors.isEmpty ? "" : "Some records had issues."}',
            ),
          ),
        );
        refreshMainPage();
      } else {
        // Legacy .txt file (streamed line-by-line so it never exhausts memory)
        statusNotifier.value = 'Restoring database records...';
        final errors = await _parseAndInsertDataStream(File(pickedFilePath), statusNotifier);

        try {
          await NotificationService().syncAllNotifications();
        } catch (e) {
          debugPrint('Error syncing notifications after restore: $e');
        }

        if (!context.mounted) return;
        _hideLoadingDialog(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Data imported successfully! ${errors.isEmpty ? "" : "Some lines had issues."}',
            ),
          ),
        );
        refreshMainPage();
      }
    } catch (e) {
      if (!context.mounted) return;
      _hideLoadingDialog(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error importing data: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: theme.colorScheme.error,
        ),
      );
    } finally {
      if (tempExtractDir != null && await tempExtractDir.exists()) {
        try {
          await tempExtractDir.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  Future<List<String>> _parseAndInsertDataStream(
    File file,
    ValueNotifier<String>? statusNotifier,
  ) async {
    final lines = file
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    List<Category> categoriesToInsert = [];
    List<Expense> expensesToInsert = [];
    List<Tag> tagsToInsert = [];
    List<Map<String, int>> expenseTagsToInsert = [];
    List<BilledItem> billedItemsToInsert = [];
    List<Subscription> subscriptionsToInsert = [];
    List<String> errors = [];

    final prefs = await SharedPreferences.getInstance();
    final db = PersistenceContext();

    int lineCount = 0;
    await for (String line in lines) {
      lineCount++;
      if (lineCount % 200 == 0 && statusNotifier != null) {
        statusNotifier.value = 'Processed $lineCount records...';
      }

      String trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      List<String> parts = trimmedLine.split(';;');
      try {
        if (parts.length == 2) {
          // SharedPreferences: Key;;Value
          final key = parts[0];
          final valueStr = parts[1];

          if (!_isAllowedPreferenceImport(key)) continue;

          if (valueStr.toLowerCase() == 'true' || valueStr.toLowerCase() == 'false') {
            await prefs.setBool(key, valueStr.toLowerCase() == 'true');
          } else if (int.tryParse(valueStr) != null) {
            await prefs.setInt(key, int.parse(valueStr));
          } else if (double.tryParse(valueStr) != null) {
            await prefs.setDouble(key, double.parse(valueStr));
          } else {
            await prefs.setString(key, valueStr);
          }
        } else if (parts.length == 3) {
          if (parts[0] == 'CATEGORY') {
            categoriesToInsert.add(Category(int.parse(parts[1]), parts[2]));
          } else if (parts[0] == 'TAG') {
            tagsToInsert.add(Tag(int.parse(parts[1]), parts[2]));
          } else if (parts[0] == 'EXPENSE_TAG') {
            expenseTagsToInsert.add({
              'expenseId': int.parse(parts[1]),
              'tagId': int.parse(parts[2]),
            });
          }
        } else if (parts.length == 4 && parts[0] == 'IMAGE') {
          // Backward compatibility for legacy Base64 text backups
          final expenseId = int.tryParse(parts[1]);
          final rawImageName = parts[2];
          final base64String = parts[3];

          if (expenseId == null || expenseId <= 0) {
            errors.add('Invalid expenseId for image: ${parts[1]}');
            continue;
          }

          final safeImageName = basename(rawImageName).trim();
          if (safeImageName.isEmpty ||
              safeImageName == '.' ||
              safeImageName == '..' ||
              rawImageName.contains('/') ||
              rawImageName.contains('\\')) {
            errors.add('Invalid or dangerous image file name rejected: $rawImageName');
            continue;
          }

          final decodedBytes = base64Decode(base64String);
          final directory = await getApplicationDocumentsDirectory();
          final imagesDirectory = Directory(join(directory.path, 'attachments', expenseId.toString()));
          if (!await imagesDirectory.exists()) {
            await imagesDirectory.create(recursive: true);
          }

          final imageFile = File(join(imagesDirectory.path, safeImageName));
          final canonicalDest = canonicalize(imageFile.path);
          final canonicalDir = canonicalize(imagesDirectory.path);
          if (!canonicalDest.startsWith(canonicalDir)) {
            errors.add('Path traversal attempted for image: $rawImageName');
            continue;
          }

          await imageFile.writeAsBytes(decodedBytes);
        } else if (parts.length == 6 && parts[0] == 'BILLED_ITEM') {
          billedItemsToInsert.add(BilledItem(
            id: int.parse(parts[1]),
            expenseId: int.parse(parts[2]),
            itemName: parts[3],
            quantity: double.parse(parts[4]),
            price: double.parse(parts[5]),
          ));
        } else if (parts[0] == 'SUBSCRIPTION' && parts.length >= 15) {
          final subId = int.tryParse(parts[1]);
          final profileId = int.tryParse(parts[2]) ?? 0;
          final title = parts[3];
          final amount = double.tryParse(parts[4]) ?? 0.0;
          final categoryId = int.tryParse(parts[5]) ?? 0;
          final category = parts[6];
          final billingCycle = parts[7];
          final startDate = DateTime.tryParse(parts[8]) ?? DateTime.now();
          final nextBillingDate = DateTime.tryParse(parts[9]) ?? DateTime.now();
          final currency = parts[10].isNotEmpty && parts[10] != 'null' ? parts[10] : 'Rupee';
          final paymentMethod = (parts[11] != 'null' && parts[11].trim().isNotEmpty) ? parts[11] : null;
          final remarks = (parts[12] != 'null' && parts[12].trim().isNotEmpty) ? parts[12] : null;
          final isActive = parts[13] == '1';
          final autoLogExpense = parts[14] == '1';

          subscriptionsToInsert.add(Subscription(
            id: subId,
            profileId: profileId,
            title: title,
            amount: amount,
            categoryId: categoryId,
            category: category,
            billingCycle: billingCycle,
            startDate: startDate,
            nextBillingDate: nextBillingDate,
            currency: currency,
            paymentMethod: paymentMethod,
            remarks: remarks,
            isActive: isActive,
            autoLogExpense: autoLogExpense,
          ));
        } else if (parts.length == 9) {
          bool isActive = parts[6].toUpperCase() == 'Y';
          if (isActive) {
            int categoryId = int.parse(parts[1]);
            Category category = categoriesToInsert.firstWhere(
              (cat) => cat.categoryId == categoryId,
              orElse: () => Category(categoryId, 'Unknown Category'),
            );
            final expense = Expense(
              id: int.parse(parts[0]),
              categoryId: categoryId,
              category: category.category,
              amount: double.parse(parts[2]),
              expenseDate: DateTime.parse(parts[3]),
              entryDate: DateTime.parse(parts[4]),
              remarks: parts[5],
              profileId: int.parse(parts[7]),
              paymentMethod: parts[8] != 'null' ? parts[8] : null,
            );
            expensesToInsert.add(expense);
          }
        } else {
          errors.add('Skipping malformed line: $trimmedLine');
        }
      } catch (e) {
        errors.add('Error parsing line "$trimmedLine": $e');
      }
    }

    // Save entities into DB in batch
    for (Category cat in categoriesToInsert) {
      await db.saveCategory(cat);
    }
    for (Expense exp in expensesToInsert) {
      await db.saveExpense(exp);
    }
    for (Tag tag in tagsToInsert) {
      await db.saveTag(tag);
    }
    for (var et in expenseTagsToInsert) {
      await db.saveExpenseTag(et['expenseId']!, et['tagId']!);
    }
    for (BilledItem item in billedItemsToInsert) {
      await db.saveBilledItem(item);
    }
    for (Subscription sub in subscriptionsToInsert) {
      await DatabaseHelper().saveOrUpdateSubscription(sub);
    }

    return errors;
  }

  Future<void> exportData(BuildContext context, {bool includeImages = false}) async {
    final statusNotifier = ValueNotifier<String>('Preparing export...');
    final theme = Theme.of(context);
    _showLoadingDialog(context, statusNotifier);

    File? tempTextFile;
    File? tempZipFile;

    try {
      final db = PersistenceContext();
      final prefs = await SharedPreferences.getInstance();

      statusNotifier.value = 'Fetching database records...';
      List<Category> categories = await db.getCategories();
      List<Expense> expenses = await db.getExpenses();
      List<Tag> tags = await db.getAllTagsWithId();
      List<Map<String, dynamic>> expenseTags = await db.getAllExpenseTags();
      List<BilledItem> billedItems = await db.getAllBilledItems();

      final dbInstance = await DatabaseHelper().database;
      final subMaps = await dbInstance.query('subscriptions');
      final subscriptions = subMaps.map((m) => Subscription.fromMap(m)).toList();

      statusNotifier.value = 'Writing backup records...';
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      tempTextFile = File(join(tempDir.path, 'backup_data_$timestamp.txt'));
      final sink = tempTextFile.openWrite();

      try {
        final keys = prefs.getKeys();
        for (String key in keys) {
          if (_isSensitivePreferenceKey(key)) continue;
          final value = prefs.get(key);
          sink.writeln('$key;;$value');
        }

        for (Category cat in categories) {
          sink.writeln('CATEGORY;;${cat.categoryId};;${cat.category}');
        }

        for (Tag tag in tags) {
          sink.writeln('TAG;;${tag.tagId};;${tag.tagName}');
        }

        for (Expense exp in expenses) {
          sink.writeln(
            '${exp.id};;${exp.categoryId};;${exp.amount};;${exp.expenseDate.toIso8601String()};;${exp.entryDate.toIso8601String()};;${exp.remarks};;Y;;${exp.profileId};;${exp.paymentMethod}',
          );
        }

        for (var et in expenseTags) {
          sink.writeln('EXPENSE_TAG;;${et['expenseId']};;${et['tagId']}');
        }

        for (BilledItem item in billedItems) {
          sink.writeln('BILLED_ITEM;;${item.id};;${item.expenseId};;${item.itemName};;${item.quantity};;${item.price}');
        }

        for (Subscription sub in subscriptions) {
          sink.writeln(
            'SUBSCRIPTION;;${sub.id};;${sub.profileId};;${sub.title};;${sub.amount};;${sub.categoryId};;${sub.category};;${sub.billingCycle};;${sub.startDate.toIso8601String()};;${sub.nextBillingDate.toIso8601String()};;${sub.currency};;${sub.paymentMethod};;${sub.remarks};;${sub.isActive ? "1" : "0"};;${sub.autoLogExpense ? "1" : "0"}',
          );
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      if (includeImages) {
        statusNotifier.value = 'Scanning attachments...';
        final docDir = await getApplicationDocumentsDirectory();
        final attachmentsRoot = Directory(join(docDir.path, 'attachments'));

        List<File> imageFiles = [];
        if (await attachmentsRoot.exists()) {
          final expenseDirs = attachmentsRoot.listSync().whereType<Directory>().toList();
          for (var dir in expenseDirs) {
            imageFiles.addAll(dir.listSync().whereType<File>());
          }
        }

        statusNotifier.value = 'Creating zip archive...';
        final zipFileName = 'expense_backup_$timestamp.zip';
        tempZipFile = File(join(tempDir.path, zipFileName));
        if (await tempZipFile.exists()) {
          await tempZipFile.delete();
        }

        final encoder = ZipFileEncoder();
        encoder.create(tempZipFile.path);

        // Add the clean data file
        await encoder.addFile(tempTextFile, 'backup_data.txt');

        // Add image files with progress
        for (int i = 0; i < imageFiles.length; i++) {
          final file = imageFiles[i];
          statusNotifier.value = 'Archiving image ${i + 1} of ${imageFiles.length}...';
          final expenseIdStr = basename(file.parent.path);
          final fileName = basename(file.path);
          await encoder.addFile(file, 'attachments/$expenseIdStr/$fileName');
        }

        statusNotifier.value = 'Finalizing zip archive...';
        await encoder.close();

        if (!context.mounted) return;
        _hideLoadingDialog(context);

        if (Platform.isAndroid || Platform.isIOS) {
          Rect? sharePositionOrigin;
          final box = context.findRenderObject() as RenderBox?;
          if (box != null && box.hasSize) {
            sharePositionOrigin = box.localToGlobal(Offset.zero) & box.size;
          }

          await SharePlus.instance.share(
            ShareParams(
              files: [XFile(tempZipFile.path, mimeType: 'application/zip')],
              subject: 'Expense Tracker Backup ($timestamp)',
              sharePositionOrigin: sharePositionOrigin,
            ),
          );

          await prefs.setInt(PrefKeys.lastBackupTimestamp, DateTime.now().millisecondsSinceEpoch);
          await prefs.setInt(PrefKeys.lastBackupReminderTimestamp, DateTime.now().millisecondsSinceEpoch);

          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Backup ready and shared!')),
          );
        } else {
          // Desktop (Windows/macOS/Linux)
          String? outputFile = await FilePicker.platform.saveFile(
            dialogTitle: 'Export Expense Data',
            fileName: zipFileName,
            type: FileType.custom,
            allowedExtensions: ['zip'],
          );

          if (!context.mounted) return;
          if (outputFile != null) {
            await tempZipFile.copy(outputFile);
            await prefs.setInt(PrefKeys.lastBackupTimestamp, DateTime.now().millisecondsSinceEpoch);
            await prefs.setInt(PrefKeys.lastBackupReminderTimestamp, DateTime.now().millisecondsSinceEpoch);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Data exported successfully to $outputFile')),
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Export cancelled.'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: theme.colorScheme.error,
              ),
            );
          }
        }
      } else {
        // Without images
        statusNotifier.value = 'Preparing export...';

        if (!context.mounted) return;
        _hideLoadingDialog(context);

        final fileName = 'expense_data_export_$timestamp.txt';
        if (Platform.isAndroid || Platform.isIOS) {
          final bytes = await tempTextFile.readAsBytes();
          String? outputFile = await FilePicker.platform.saveFile(
            dialogTitle: 'Export Expense Data',
            fileName: fileName,
            type: FileType.custom,
            allowedExtensions: ['txt'],
            bytes: bytes,
          );

          if (!context.mounted) return;
          if (outputFile != null) {
            await prefs.setInt(PrefKeys.lastBackupTimestamp, DateTime.now().millisecondsSinceEpoch);
            await prefs.setInt(PrefKeys.lastBackupReminderTimestamp, DateTime.now().millisecondsSinceEpoch);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Data exported successfully to $outputFile')),
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Export cancelled.'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: theme.colorScheme.error,
              ),
            );
          }
        } else {
          // Desktop
          String? outputFile = await FilePicker.platform.saveFile(
            dialogTitle: 'Export Expense Data',
            fileName: fileName,
            type: FileType.custom,
            allowedExtensions: ['txt'],
          );

          if (!context.mounted) return;
          if (outputFile != null) {
            await tempTextFile.copy(outputFile);
            await prefs.setInt(PrefKeys.lastBackupTimestamp, DateTime.now().millisecondsSinceEpoch);
            await prefs.setInt(PrefKeys.lastBackupReminderTimestamp, DateTime.now().millisecondsSinceEpoch);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Data exported successfully to $outputFile')),
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Export cancelled.'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: theme.colorScheme.error,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      _hideLoadingDialog(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting data: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: theme.colorScheme.error,
        ),
      );
    } finally {
      try {
        if (tempTextFile != null && await tempTextFile.exists()) {
          await tempTextFile.delete();
        }
      } catch (_) {}
      try {
        if (!Platform.isAndroid && !Platform.isIOS && tempZipFile != null && await tempZipFile.exists()) {
          await tempZipFile.delete();
        }
      } catch (_) {}
    }
  }
}