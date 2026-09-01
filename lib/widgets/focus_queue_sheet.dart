import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/focus_haven_localizations.dart';
import '../providers/app_providers.dart';
import '../services/focus_queue_service.dart';

typedef FocusQueueTaskSelected = Future<bool> Function(FocusQueueItem item);
typedef FocusQueueTaskEditor = Future<void> Function(FocusQueueItem item);
typedef FocusQueueTitleAction = Future<void> Function(String title);
typedef FocusQueueItemAction = Future<void> Function(String id);

class FocusQueueSheet extends ConsumerStatefulWidget {
  const FocusQueueSheet({
    required this.onTaskSelected,
    required this.onEditTask,
    required this.onShowCompleted,
    this.addTask,
    this.completeTask,
    this.removeTask,
    super.key,
  });

  final FocusQueueTaskSelected onTaskSelected;
  final FocusQueueTaskEditor onEditTask;
  final VoidCallback onShowCompleted;
  final FocusQueueTitleAction? addTask;
  final FocusQueueItemAction? completeTask;
  final FocusQueueItemAction? removeTask;

  @override
  ConsumerState<FocusQueueSheet> createState() => _FocusQueueSheetState();
}

class _FocusQueueSheetState extends ConsumerState<FocusQueueSheet> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Set<String> _busyItemIds = <String>{};
  bool _isAdding = false;

  void _showActionFailure(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _addTask() async {
    final title = _textController.text;
    if (_isAdding || title.trim().isEmpty) return;
    final l10n = context.l10n;

    setState(() => _isAdding = true);
    try {
      final addTask = widget.addTask;
      if (addTask == null) {
        await ref.read(focusQueueServiceProvider).add(title);
      } else {
        await addTask(title);
      }
      if (mounted) _textController.clear();
    } catch (_) {
      _showActionFailure(l10n.focusQueueAddError);
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  bool _beginItemAction(String id) {
    if (_busyItemIds.contains(id)) return false;
    setState(() => _busyItemIds.add(id));
    return true;
  }

  void _finishItemAction(String id) {
    if (!mounted) return;
    setState(() => _busyItemIds.remove(id));
  }

  Future<void> _completeTask(FocusQueueItem item) async {
    if (!_beginItemAction(item.id)) return;
    final l10n = context.l10n;
    try {
      final completeTask = widget.completeTask;
      if (completeTask == null) {
        await ref.read(focusQueueServiceProvider).toggle(item.id);
      } else {
        await completeTask(item.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.focusQueueCompleteReceipt)));
      }
    } catch (_) {
      _showActionFailure(l10n.focusQueueCompleteError);
    } finally {
      _finishItemAction(item.id);
    }
  }

  Future<void> _removeTask(FocusQueueItem item) async {
    if (!_beginItemAction(item.id)) return;
    final l10n = context.l10n;
    try {
      final removeTask = widget.removeTask;
      if (removeTask == null) {
        await ref.read(focusQueueServiceProvider).remove(item.id);
      } else {
        await removeTask(item.id);
      }
    } catch (_) {
      _showActionFailure(l10n.focusQueueRemoveError);
    } finally {
      _finishItemAction(item.id);
    }
  }

  Future<void> _editTask(FocusQueueItem item) async {
    if (!_beginItemAction(item.id)) return;
    final l10n = context.l10n;
    try {
      await widget.onEditTask(item);
    } catch (_) {
      _showActionFailure(l10n.focusQueueUpdateError);
    } finally {
      _finishItemAction(item.id);
    }
  }

  Future<void> _selectTask(FocusQueueItem item) async {
    if (!_beginItemAction(item.id)) return;
    final l10n = context.l10n;
    try {
      final selected = await widget.onTaskSelected(item);
      if (!mounted) return;
      if (selected) {
        Navigator.pop(context);
      } else {
        _showActionFailure(l10n.focusQueueChangedError);
      }
    } catch (_) {
      _showActionFailure(l10n.focusQueueSelectError);
    } finally {
      _finishItemAction(item.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final queueState = ref.watch(focusQueueStateProvider);
    final l10n = context.l10n;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: false,
            interactive: true,
            child: ListView(
              controller: _scrollController,
              children: [
                Center(
                  child: Container(
                    height: 4,
                    width: 42,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  l10n.focusQueueSheetTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 5),
                Text(
                  l10n.focusQueueSheetDescription,
                  style: const TextStyle(color: Colors.white70),
                ),
                if (queueState.completedToday > 0) ...[
                  const SizedBox(height: 5),
                  Text(
                    l10n.focusQueueCompletedToday(queueState.completedToday),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        maxLength: 100,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _addTask(),
                        decoration: InputDecoration(
                          hintText: l10n.focusQueueAddHint,
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      key: const ValueKey<String>('focus-queue-add-task'),
                      onPressed: _isAdding ? null : _addTask,
                      icon: const Icon(Icons.add),
                      tooltip: l10n.focusQueueAddTooltip,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (queueState.activeItems.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 34),
                    child: Center(
                      child: Text(
                        l10n.focusQueueEmpty,
                        style: const TextStyle(color: Colors.white60),
                      ),
                    ),
                  )
                else
                  ...queueState.activeItems.map((item) {
                    final isBusy = _busyItemIds.contains(item.id);
                    return ListTile(
                      key: ValueKey<String>('focus-queue-task-${item.id}'),
                      onTap: isBusy ? null : () => _selectTask(item),
                      leading: Checkbox(
                        key: ValueKey<String>(
                          'focus-queue-checkbox-${item.id}',
                        ),
                        value: false,
                        onChanged: isBusy
                            ? null
                            : (isChecked) {
                                if (isChecked == true) _completeTask(item);
                              },
                      ),
                      title: Text(item.title),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            key: ValueKey<String>(
                              'focus-queue-edit-${item.id}',
                            ),
                            onPressed: isBusy ? null : () => _editTask(item),
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: l10n.focusQueueEditTooltip,
                          ),
                          IconButton(
                            key: ValueKey<String>(
                              'focus-queue-remove-${item.id}',
                            ),
                            onPressed: isBusy ? null : () => _removeTask(item),
                            icon: const Icon(Icons.close),
                            tooltip: l10n.focusQueueRemoveTooltip,
                          ),
                        ],
                      ),
                    );
                  }),
                if (queueState.completedItems.isNotEmpty)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: widget.onShowCompleted,
                      icon: const Icon(Icons.history_outlined),
                      label: Text(
                        l10n.focusQueueCompletedCount(
                          queueState.completedItems.length,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
