import 'package:flutter/material.dart';

class ExpenseActionMenu extends StatefulWidget {
  const ExpenseActionMenu({
    super.key,
    required this.onAdd,
    required this.onSearch,
    required this.onFilter,
    this.activeCategoryName,
  });

  final VoidCallback onAdd;
  final VoidCallback onSearch;
  final VoidCallback onFilter;
  final String? activeCategoryName;

  @override
  State<ExpenseActionMenu> createState() => _ExpenseActionMenuState();
}

class _ExpenseActionMenuState extends State<ExpenseActionMenu> {
  static const double _swipeThreshold = 24;

  bool _showSecondaryActions = false;
  double _verticalDragDistance = 0;

  void _handleDragStart(DragStartDetails details) {
    _verticalDragDistance = 0;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    _verticalDragDistance += details.primaryDelta ?? 0;
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final shouldShow =
        _verticalDragDistance <= -_swipeThreshold || velocity < -200;
    final shouldHide =
        _verticalDragDistance >= _swipeThreshold || velocity > 200;

    if (shouldShow && !_showSecondaryActions) {
      setState(() => _showSecondaryActions = true);
    } else if (shouldHide && _showSecondaryActions) {
      setState(() => _showSecondaryActions = false);
    }
  }

  void _runSecondaryAction(VoidCallback action) {
    setState(() => _showSecondaryActions = false);
    action();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryName = widget.activeCategoryName;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          reverseDuration: const Duration(milliseconds: 160),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0, 0.45),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                child: child,
              ),
            );
          },
          child: _showSecondaryActions
              ? Column(
                  key: const ValueKey('expense_secondary_actions'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton(
                      key: const Key('expense_category_filter_action'),
                      heroTag: 'expenses_category_filter_fab',
                      tooltip: categoryName == null
                          ? 'Filter by category'
                          : 'Category: $categoryName',
                      onPressed: () => _runSecondaryAction(widget.onFilter),
                      backgroundColor: categoryName == null
                          ? theme.colorScheme.secondaryContainer
                          : theme.colorScheme.primaryContainer,
                      foregroundColor: categoryName == null
                          ? theme.colorScheme.onSecondaryContainer
                          : theme.colorScheme.onPrimaryContainer,
                      child: Icon(
                        categoryName == null
                            ? Icons.filter_alt_outlined
                            : Icons.filter_alt,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FloatingActionButton(
                      key: const Key('expense_search_action'),
                      heroTag: 'expenses_search_fab',
                      tooltip: 'Search expenses',
                      onPressed: () => _runSecondaryAction(widget.onSearch),
                      backgroundColor: theme.colorScheme.secondaryContainer,
                      foregroundColor: theme.colorScheme.onSecondaryContainer,
                      child: const Icon(Icons.search),
                    ),
                    const SizedBox(height: 12),
                  ],
                )
              : const SizedBox.shrink(
                  key: ValueKey('expense_secondary_actions_hidden'),
                ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: _showSecondaryActions
              ? const SizedBox.shrink(
                  key: ValueKey('expense_menu_swipe_hint_hidden'),
                )
              : Icon(
                  Icons.keyboard_arrow_up,
                  key: const Key('expense_menu_swipe_hint'),
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
        ),
        GestureDetector(
          key: const Key('expense_add_swipe_target'),
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: _handleDragStart,
          onVerticalDragUpdate: _handleDragUpdate,
          onVerticalDragEnd: _handleDragEnd,
          child: Semantics(
            container: true,
            button: true,
            label: 'Add expense',
            hint: 'Swipe up to show search and filter actions',
            onTap: widget.onAdd,
            child: ExcludeSemantics(
              child: FloatingActionButton(
                heroTag: 'expenses_add_fab',
                onPressed: widget.onAdd,
                tooltip: 'Add expense. Swipe up for search and filter.',
                child: const Icon(Icons.add),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
