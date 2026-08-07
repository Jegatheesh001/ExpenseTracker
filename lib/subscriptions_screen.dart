import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'currency_symbol.dart';
import 'pref_keys.dart';
import 'db/database_helper.dart';
import 'db/entity.dart';
import 'add_subscription_dialog.dart';
import 'subscription_date_utils.dart';

class SubscriptionsScreen extends StatefulWidget {
  final int profileId;
  final String currencySymbol;
  final VoidCallback? onWalletAmountChange;

  const SubscriptionsScreen({
    super.key,
    required this.profileId,
    required this.currencySymbol,
    this.onWalletAmountChange,
  });

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  List<Subscription> _subscriptions = [];
  bool _isLoading = true;
  String _filter = 'All'; // 'All', 'Active', 'Paused'
  bool _showCurrentProfileOnly = false;
  String _profileCurrency = 'Rupee';

  @override
  void initState() {
    super.initState();
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
    }
    return list;
  }

  double get _totalMonthlySpend {
    return _profileFilteredSubscriptions
        .where((s) => s.isActive)
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

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Expense Now'),
        content: Text(
          'Create an expense entry for "${sub.title}" of $subSymbol${sub.amount.toStringAsFixed(2)} for today?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check),
            label: const Text('Log Expense'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final now = DateTime.now();
      final newExpense = Expense(
        profileId: sub.profileId,
        categoryId: sub.categoryId,
        category: sub.category,
        amount: sub.amount,
        remarks: 'Recurring Subscription: ${sub.title}',
        expenseDate: now,
        entryDate: now,
        paymentMethod: sub.paymentMethod,
        tags: ['subscription', sub.title.toLowerCase().replaceAll(' ', '_')],
      );

      await DatabaseHelper().saveOrUpdateExpense(newExpense);

      // Advance next billing date to next cycle (catching up if overdue)
      final nextDue = SubscriptionDateUtils.advanceNextBillingDate(
        SubscriptionDateUtils.catchUpNextBillingDate(sub.nextBillingDate, sub.billingCycle),
        sub.billingCycle,
      );

      final updatedSub = sub.copyWith(nextBillingDate: nextDue);
      await DatabaseHelper().saveOrUpdateSubscription(updatedSub);

      widget.onWalletAmountChange?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Logged ${sub.title} as expense! Next due date updated to ${DateFormat('MMM dd').format(nextDue)}.',
            ),
            backgroundColor: Colors.green,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayedList = _filteredSubscriptions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscriptions & Recurring'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add Subscription',
            onPressed: () => _openAddEditSheet(),
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
                        Text(
                          'Your Subscriptions',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'All', label: Text('All')),
                            ButtonSegment(value: 'Active', label: Text('Active')),
                            ButtonSegment(value: 'Paused', label: Text('Paused')),
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
                                            sub.isActive ? 'Active' : 'Paused',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          if (sub.isActive)
                                            OutlinedButton.icon(
                                              onPressed: () => _logSubscriptionAsExpense(sub),
                                              icon: const Icon(Icons.bolt, size: 16),
                                              label: const Text(
                                                'Log Expense',
                                                style: TextStyle(fontSize: 12),
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                visualDensity: VisualDensity.compact,
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 10, vertical: 4),
                                              ),
                                            ),
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, size: 20),
                                            onPressed: () => _openAddEditSheet(sub),
                                            tooltip: 'Edit',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                            onPressed: () => _deleteSubscription(sub),
                                            tooltip: 'Delete',
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
