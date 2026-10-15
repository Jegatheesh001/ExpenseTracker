import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracker/utils/currency_symbol.dart';
import 'package:expense_tracker/utils/pref_keys.dart';
import 'package:expense_tracker/db/database_helper.dart';
import 'package:expense_tracker/db/entity.dart';
import 'package:expense_tracker/widgets/add_subscription_dialog.dart';
import 'package:expense_tracker/utils/subscription_date_utils.dart';
import 'package:expense_tracker/services/notification_service.dart';

class SubscriptionsScreen extends StatefulWidget {
  final int profileId;
  final String currencySymbol;
  final VoidCallback? onWalletAmountChange;
  final String initialFilter;

  const SubscriptionsScreen({
    super.key,
    required this.profileId,
    required this.currencySymbol,
    this.onWalletAmountChange,
    this.initialFilter = 'All',
  });

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  List<Subscription> _subscriptions = [];
  bool _isLoading = true;
  late String _filter; // 'All', 'Active', 'Paused', 'Due'
  bool _showCurrentProfileOnly = false;
  String _profileCurrency = 'Rupee';

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _loadSubscriptions();
  }

  Future<void> _loadSubscriptions() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentCurrency =
          prefs.getString('${PrefKeys.selectedCurrency}-${widget.profileId}') ??
              'Rupee';
      final subs = await DatabaseHelper().getSubscriptions();
      if (mounted) {
        setState(() {
          _profileCurrency = currentCurrency;
          _subscriptions = subs;
          _isLoading = false;
        });
      }
      // Reschedule subscription notifications whenever subscription data updates
      NotificationService().rescheduleAllSubscriptionReminders();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<Subscription> get _profileFilteredSubscriptions {
    if (_showCurrentProfileOnly) {
      return _subscriptions.where((s) => s.profileId == widget.profileId).toList();
    }
    return _subscriptions;
  }

  List<Subscription> get _filteredSubscriptions {
    final list = _profileFilteredSubscriptions;
    if (_filter == 'Active') {
      return list.where((s) => s.isActive).toList();
    } else if (_filter == 'Paused') {
      return list.where((s) => !s.isActive).toList();
    } else if (_filter == 'Due') {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final in7Days = today.add(const Duration(days: 7));
      final dueList = list.where((s) {
        if (!s.isActive) return false;
        final due = DateTime(
            s.nextBillingDate.year, s.nextBillingDate.month, s.nextBillingDate.day);
        return !due.isAfter(in7Days);
      }).toList();
      dueList.sort((a, b) => a.nextBillingDate.compareTo(b.nextBillingDate));
      return dueList;
    }
    return list;
  }

  double get _totalMonthlySpend {
    return _subscriptions
        .where((s) => s.profileId == widget.profileId && s.isActive)
        .fold(0.0, (sum, item) => sum + item.monthlyAmount);
  }

  int get _dueWithinSevenDaysCount {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final in7Days = today.add(const Duration(days: 7));
    return _profileFilteredSubscriptions.where((s) {
      if (!s.isActive) return false;
      final due = DateTime(
          s.nextBillingDate.year, s.nextBillingDate.month, s.nextBillingDate.day);
      return !due.isAfter(in7Days);
    }).length;
  }

  Future<void> _openAddEditSheet([Subscription? editSub]) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AddSubscriptionSheet(
        profileId: widget.profileId,
        currencySymbol: widget.currencySymbol,
        currentCurrency: _profileCurrency,
        subscriptionToEdit: editSub,
      ),
    );

    if (result == true) {
      _loadSubscriptions();
    }
  }

  Future<void> _toggleActive(Subscription sub) async {
    final newStatus = !sub.isActive;
    await DatabaseHelper().toggleSubscriptionStatus(sub.id!, newStatus);
    _loadSubscriptions();
  }

  Future<void> _deleteSubscription(Subscription sub) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Subscription'),
        content: Text('Are you sure you want to delete "${sub.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && sub.id != null) {
      await DatabaseHelper().deleteSubscription(sub.id!);
      await NotificationService().cancelSubscriptionReminder(sub.id!);
      _loadSubscriptions();
    }
  }

  Future<void> _logSubscriptionAsExpense(Subscription sub) async {
    final subSymbol = CurrencySymbol().getSymbol(sub.currency);
    final profileSymbol = CurrencySymbol().getSymbol(_profileCurrency);

    // Validate currency against current profile's currency
    if (sub.currency != _profileCurrency) {
      final shouldProceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Currency Mismatch'),
            ],
          ),
          content: Text(
            'This subscription is in ${sub.currency} ($subSymbol), but Profile #${widget.profileId} uses $_profileCurrency ($profileSymbol).\n\n'
            'Logging this will record $subSymbol${sub.amount.toStringAsFixed(2)} directly into Profile #${widget.profileId} expenses.\n\n'
            'Do you want to proceed?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Proceed Logging'),
            ),
          ],
        ),
      );

      if (shouldProceed != true) return;
    }

    if (!mounted) return;

    final selectedDate = await showDialog<DateTime>(
      context: context,
      builder: (context) {
        DateTime chosenDate = sub.nextBillingDate;
        String mode = 'subscription'; // 'subscription', 'today', 'custom'

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final subDateStr = DateFormat('MMM dd, yyyy').format(sub.nextBillingDate);
            final todayStr = DateFormat('MMM dd, yyyy').format(DateTime.now());
            final chosenStr = DateFormat('MMM dd, yyyy').format(chosenDate);

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.receipt_long, color: Colors.teal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Log Expense',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sub.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                sub.category,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).textTheme.bodySmall?.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '$subSymbol${sub.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Expense Date:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () {
                      setDialogState(() {
                        mode = 'subscription';
                        chosenDate = sub.nextBillingDate;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: mode == 'subscription'
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade400,
                          width: mode == 'subscription' ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: mode == 'subscription'
                            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            mode == 'subscription'
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: mode == 'subscription'
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Subscription Due Date',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                Text(
                                  subDateStr,
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Auto-Deducted',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      setDialogState(() {
                        mode = 'today';
                        chosenDate = DateTime.now();
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: mode == 'today'
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade400,
                          width: mode == 'today' ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: mode == 'today'
                            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            mode == 'today'
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: mode == 'today'
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Today',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                Text(
                                  todayStr,
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: chosenDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          mode = 'custom';
                          chosenDate = picked;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: mode == 'custom'
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade400,
                          width: mode == 'custom' ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: mode == 'custom'
                            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            mode == 'custom'
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: mode == 'custom'
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Custom Date',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                Text(
                                  mode == 'custom' ? chosenStr : 'Pick a date...',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.calendar_month, size: 18, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, chosenDate),
                  icon: const Icon(Icons.check),
                  label: const Text('Log Expense'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selectedDate != null) {
      final now = DateTime.now();
      final newExpense = Expense(
        profileId: sub.profileId,
        categoryId: sub.categoryId,
        category: sub.category,
        amount: sub.amount,
        remarks: 'Recurring Subscription: ${sub.title}',
        expenseDate: selectedDate,
        entryDate: now,
        paymentMethod: sub.paymentMethod,
        tags: ['subscription', sub.title.toLowerCase().replaceAll(' ', '_')],
      );

      await DatabaseHelper().saveOrUpdateExpense(newExpense);

      // Advance next billing date to next upcoming cycle
      final nextDue = SubscriptionDateUtils.getNextRenewalDate(
        sub.nextBillingDate,
        sub.billingCycle,
        anchorDay: sub.startDate.day,
      );

      final updatedSub = sub.copyWith(nextBillingDate: nextDue);
      await DatabaseHelper().saveOrUpdateSubscription(updatedSub);

      widget.onWalletAmountChange?.call();

      if (mounted) {
        final formattedDate = DateFormat('MMM dd, yyyy').format(selectedDate);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Logged ${sub.title} expense for $formattedDate! Next due date updated to ${DateFormat('MMM dd').format(nextDue)}.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        _loadSubscriptions();
      }
    }
  }

  Future<void> _skipSubscription(Subscription sub) async {
    final nextDue = SubscriptionDateUtils.getNextRenewalDate(
      sub.nextBillingDate,
      sub.billingCycle,
      anchorDay: sub.startDate.day,
    );

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.skip_next, color: Colors.blue),
            SizedBox(width: 8),
            Text('Skip Subscription'),
          ],
        ),
        content: Text(
          'Are you sure you want to skip the current due date for "${sub.title}"?\n\n'
          'The next due date will be set to ${DateFormat('MMM dd, yyyy').format(nextDue)} without recording an expense.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Skip'),
          ),
        ],
      ),
    );

    if (confirm == true && sub.id != null) {
      final updatedSub = sub.copyWith(nextBillingDate: nextDue);
      await DatabaseHelper().saveOrUpdateSubscription(updatedSub);

      if (mounted) {
        final formattedDate = DateFormat('MMM dd, yyyy').format(nextDue);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Skipped ${sub.title}. Next due date updated to $formattedDate.',
            ),
            backgroundColor: Colors.blue,
          ),
        );
        _loadSubscriptions();
      }
    }
  }

  Widget _buildSummaryCard(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estimated Monthly Recurring',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onPrimary.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${widget.currencySymbol}${_totalMonthlySpend.toStringAsFixed(2)}',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatChip(
                theme,
                Icons.subscriptions,
                '${_subscriptions.where((s) => s.isActive).length} Active',
              ),
              const SizedBox(width: 12),
              _buildStatChip(
                theme,
                Icons.notifications_active,
                '$_dueWithinSevenDaysCount Due soon',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(ThemeData theme, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.onPrimary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onPrimary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDueBadge(DateTime nextBillingDate, bool isActive) {
    if (!isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'Paused',
          style: TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(
        nextBillingDate.year, nextBillingDate.month, nextBillingDate.day);
    final difference = due.difference(today).inDays;

    Color bg;
    Color fg;
    String text;

    if (difference < 0) {
      bg = Colors.red.shade100;
      fg = Colors.red.shade900;
      text = 'Overdue (${difference.abs()}d)';
    } else if (difference == 0) {
      bg = Colors.orange.shade100;
      fg = Colors.orange.shade900;
      text = 'Due Today';
    } else if (difference <= 7) {
      bg = Colors.amber.shade100;
      fg = Colors.amber.shade900;
      text = 'Due in ${difference}d';
    } else {
      bg = Colors.green.shade100;
      fg = Colors.green.shade900;
      text = 'Due ${DateFormat('MMM dd').format(nextBillingDate)}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _showQuickNotificationConfigDialog() async {
    final prefs = await SharedPreferences.getInstance();
    bool enabled = prefs.getBool(PrefKeys.subscriptionRemindersEnabled) ?? true;
    int advanceDays = prefs.getInt(PrefKeys.subscriptionReminderAdvanceDays) ?? 1;

    if (!mounted) return;

    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.notifications_active, color: Colors.teal),
                  SizedBox(width: 8),
                  Text('Renewal Reminders'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enable Renewal Alerts',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Get notified before subscriptions renew'),
                      value: enabled,
                      onChanged: (val) {
                        setDialogState(() => enabled = val);
                      },
                    ),
                    if (enabled) ...[
                      const Divider(),
                      const Text(
                        'Remind me:',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      RadioListTile<int>(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('On renewal day (9:00 AM)'),
                        value: 0,
                        groupValue: advanceDays,
                        onChanged: (val) => setDialogState(() => advanceDays = val!),
                      ),
                      RadioListTile<int>(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('1 day before renewal (9:00 AM)'),
                        value: 1,
                        groupValue: advanceDays,
                        onChanged: (val) => setDialogState(() => advanceDays = val!),
                      ),
                      RadioListTile<int>(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('2 days before renewal (9:00 AM)'),
                        value: 2,
                        groupValue: advanceDays,
                        onChanged: (val) => setDialogState(() => advanceDays = val!),
                      ),
                      RadioListTile<int>(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('3 days before renewal (9:00 AM)'),
                        value: 3,
                        groupValue: advanceDays,
                        onChanged: (val) => setDialogState(() => advanceDays = val!),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true) {
      await prefs.setBool(PrefKeys.subscriptionRemindersEnabled, enabled);
      await prefs.setInt(PrefKeys.subscriptionReminderAdvanceDays, advanceDays);
      if (enabled) {
        await NotificationService().requestPermissions();
      }
      await NotificationService().rescheduleAllSubscriptionReminders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(enabled
                ? 'Subscription renewal alerts active!'
                : 'Subscription alerts disabled'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayedList = _filteredSubscriptions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscriptions & Recurring'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Renewal Reminder Settings',
            onPressed: _showQuickNotificationConfigDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSubscriptions,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryCard(theme),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'All', label: Text('All')),
                            ButtonSegment(value: 'Active', label: Text('Active')),
                            ButtonSegment(value: 'Paused', label: Text('Paused')),
                            ButtonSegment(value: 'Due', label: Text('Due')),
                          ],
                          selected: {_filter},
                          onSelectionChanged: (set) {
                            setState(() {
                              _filter = set.first;
                            });
                          },
                          style: ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FilterChip(
                      avatar: Icon(
                        _showCurrentProfileOnly ? Icons.person : Icons.public,
                        size: 16,
                        color: _showCurrentProfileOnly
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      label: Text(
                        _showCurrentProfileOnly
                            ? 'Current Profile Only (Profile #${widget.profileId})'
                            : 'Show Current Profile Only',
                        style: const TextStyle(fontSize: 12),
                      ),
                      selected: _showCurrentProfileOnly,
                      onSelected: (val) {
                        setState(() {
                          _showCurrentProfileOnly = val;
                        });
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(height: 12),
                    if (displayedList.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.subscriptions_outlined,
                              size: 48,
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _filter == 'All'
                                  ? 'No subscriptions added yet'
                                  : _filter == 'Due'
                                      ? 'No subscriptions due soon'
                                      : 'No $_filter subscriptions found',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () => _openAddEditSheet(),
                              icon: const Icon(Icons.add),
                              label: const Text('Add First Subscription'),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: displayedList.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final sub = displayedList[index];
                          return Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: sub.isActive
                                    ? Colors.transparent
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: theme.colorScheme.primaryContainer,
                                        child: Icon(
                                          Icons.repeat,
                                          color: theme.colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              sub.title,
                                              style: theme.textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                decoration: sub.isActive
                                                    ? null
                                                    : TextDecoration.lineThrough,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: theme.colorScheme.surfaceContainerHighest,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    sub.category,
                                                    style: const TextStyle(fontSize: 10),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: theme.colorScheme.secondaryContainer,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    sub.billingCycle,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: theme.colorScheme.onSecondaryContainer,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                                if (sub.currency != _profileCurrency)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.orange.shade100,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      CurrencySymbol().getLabel(sub.currency),
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.orange.shade900,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                if (sub.profileId != widget.profileId)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: theme.colorScheme.tertiaryContainer,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      'Profile #${sub.profileId}',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: theme.colorScheme.onTertiaryContainer,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${CurrencySymbol().getSymbol(sub.currency)}${sub.amount.toStringAsFixed(2)}',
                                            style: theme.textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: sub.isActive
                                                  ? theme.colorScheme.primary
                                                  : Colors.grey,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          _buildDueBadge(
                                            sub.nextBillingDate,
                                            sub.isActive,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Switch(
                                            value: sub.isActive,
                                            onChanged: (val) => _toggleActive(sub),
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          Text(
                                            sub.isActive ? '' : 'Paused',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Wrap(
                                            spacing: 4,
                                            runSpacing: 4,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              if (sub.isActive) ...[
                                                OutlinedButton.icon(
                                                  onPressed: () => _logSubscriptionAsExpense(sub),
                                                  icon: const Icon(Icons.bolt, size: 16),
                                                  label: const Text(
                                                    'Log',
                                                    style: TextStyle(fontSize: 12),
                                                  ),
                                                  style: OutlinedButton.styleFrom(
                                                    visualDensity: VisualDensity.compact,
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 8, vertical: 4),
                                                  ),
                                                ),
                                                OutlinedButton.icon(
                                                  onPressed: () => _skipSubscription(sub),
                                                  icon: const Icon(Icons.skip_next, size: 16),
                                                  label: const Text(
                                                    'Skip',
                                                    style: TextStyle(fontSize: 12),
                                                  ),
                                                  style: OutlinedButton.styleFrom(
                                                    visualDensity: VisualDensity.compact,
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 8, vertical: 4),
                                                  ),
                                                ),
                                              ],
                                              IconButton(
                                                icon: const Icon(Icons.edit_outlined, size: 20),
                                                onPressed: () => _openAddEditSheet(sub),
                                                tooltip: 'Edit',
                                                visualDensity: VisualDensity.compact,
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                                onPressed: () => _deleteSubscription(sub),
                                                tooltip: 'Delete',
                                                visualDensity: VisualDensity.compact,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddEditSheet(),
        icon: const Icon(Icons.add),
        label: const Text('Add Subscription'),
      ),
    );
  }
}
