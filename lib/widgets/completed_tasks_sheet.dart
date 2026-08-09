import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';

class CompletedTasksSheet extends ConsumerStatefulWidget {
  const CompletedTasksSheet({required this.dateLabel, super.key});

  final String Function(DateTime value) dateLabel;

  @override
  ConsumerState<CompletedTasksSheet> createState() =>
      _CompletedTasksSheetState();
}

class _CompletedTasksSheetState extends ConsumerState<CompletedTasksSheet> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final queueState = ref.watch(focusQueueStateProvider);
    final queue = ref.read(focusQueueServiceProvider);

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
                      return ListTile(
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
                          tooltip: 'Return to queue',
                          icon: const Icon(Icons.undo),
                          onPressed: () => queue.toggle(item.id),
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
