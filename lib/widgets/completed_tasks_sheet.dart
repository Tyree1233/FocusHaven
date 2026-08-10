import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';

typedef CompletedTaskRestorer = Future<void> Function(String id);

class CompletedTasksSheet extends ConsumerStatefulWidget {
  const CompletedTasksSheet({
    required this.dateLabel,
    this.restoreTask,
    super.key,
  });

  final String Function(DateTime value) dateLabel;
  final CompletedTaskRestorer? restoreTask;

  @override
  ConsumerState<CompletedTasksSheet> createState() =>
      _CompletedTasksSheetState();
}

class _CompletedTasksSheetState extends ConsumerState<CompletedTasksSheet> {
  final ScrollController _scrollController = ScrollController();
  final Set<String> _restoringTaskIds = <String>{};

  bool _beginRestore(String id) {
    if (_restoringTaskIds.contains(id)) return false;
    setState(() => _restoringTaskIds.add(id));
    return true;
  }

  void _finishRestore(String id) {
    if (!mounted) return;
    setState(() => _restoringTaskIds.remove(id));
  }

  Future<void> _restoreTask(String id) async {
    if (!_beginRestore(id)) return;
    try {
      final restoreTask = widget.restoreTask;
      if (restoreTask == null) {
        await ref.read(focusQueueServiceProvider).toggle(id);
      } else {
        await restoreTask(id);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Task could not be returned to the queue. Please try again.',
            ),
          ),
        );
      }
    } finally {
      _finishRestore(id);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final queueState = ref.watch(focusQueueStateProvider);

    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.62,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            children: [
              Container(
                height: 4,
                width: 42,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Completed tasks',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 5),
              const Text(
                'A quiet record of what you handled.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: false,
                  interactive: true,
                  child: ListView.separated(
                    controller: _scrollController,
                    itemCount: queueState.completedItems.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, color: Colors.white12),
                    itemBuilder: (context, index) {
                      final item = queueState.completedItems[index];
                      final isRestoring = _restoringTaskIds.contains(item.id);
                      return ListTile(
                        key: ValueKey<String>('completed-task-${item.id}'),
                        leading: Icon(
                          Icons.check_circle_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(item.title),
                        subtitle: Text(
                          item.completedAt == null
                              ? 'Completed'
                              : 'Completed ${widget.dateLabel(item.completedAt!)}',
                        ),
                        trailing: IconButton(
                          key: ValueKey<String>(
                            'completed-task-restore-${item.id}',
                          ),
                          tooltip: 'Return to queue',
                          icon: const Icon(Icons.undo),
                          onPressed: isRestoring
                              ? null
                              : () => _restoreTask(item.id),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
