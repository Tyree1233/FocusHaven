import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/journal_entry.dart';
import '../providers/app_providers.dart';

typedef JournalEntryEditor = Future<void> Function(BuildContext context);
typedef SelectedJournalEntryEditor =
    Future<void> Function(BuildContext context, JournalEntry entry);
typedef JournalDateLabel = String Function(DateTime date);

class ReflectionJournalSheet extends ConsumerStatefulWidget {
  const ReflectionJournalSheet({
    required this.dateLabel,
    required this.onCreateEntry,
    required this.onEditEntry,
    super.key,
  });

  /// Opens an empty editor and appends a new reflection.
  final JournalEntryEditor onCreateEntry;

  /// Opens an editor for exactly one existing reflection.
  final SelectedJournalEntryEditor onEditEntry;
  final JournalDateLabel dateLabel;

  @override
  ConsumerState<ReflectionJournalSheet> createState() =>
      _ReflectionJournalSheetState();
}

class _ReflectionJournalSheetState
    extends ConsumerState<ReflectionJournalSheet> {
  final ScrollController _scrollController = ScrollController();
  bool _isOpeningEditor = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openEditor(Future<void> Function() editor) async {
    if (_isOpeningEditor) return;
    setState(() => _isOpeningEditor = true);
    try {
      await editor();
    } finally {
      if (mounted) setState(() => _isOpeningEditor = false);
    }
  }

  Future<void> _createEntry() async {
    await _openEditor(() => widget.onCreateEntry(context));
  }

  Future<void> _editEntry(JournalEntry entry) async {
    await _openEditor(() => widget.onEditEntry(context, entry));
  }

  @override
  Widget build(BuildContext context) {
    final journalState = ref.watch(journalStateProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              height: 4,
              width: 42,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: false,
                  interactive: true,
                  child: ListView(
                    controller: _scrollController,
                    children: [
                      Text(
                        'Reflection journal',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'A private space saved only on this device.',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 14),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            'Today’s prompt: ${journalState.dailyPrompt}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),
                      if (journalState.recentMoodCounts.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Mood snapshot',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Over the last 7 days, you most often felt '
                          '${journalState.mostCommonRecentMood?.toLowerCase()}.',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: journalState.recentMoodCounts.entries
                              .map(
                                (entry) => Chip(
                                  label: Text('${entry.key} ${entry.value}'),
                                  backgroundColor: primaryColor.withValues(
                                    alpha: 0.13,
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _isOpeningEditor ? null : _createEntry,
                        icon: _isOpeningEditor
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add_comment_outlined),
                        label: Text(
                          journalState.todayEntries.isEmpty
                              ? 'Write today’s reflection'
                              : 'Write another reflection',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: const Color(0xFF211144),
                          minimumSize: const Size.fromHeight(52),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Recent reflections',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      if (journalState.entries.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 30),
                          child: Center(
                            child: Text(
                              'Your first reflection will appear here.',
                              style: TextStyle(color: Colors.white60),
                            ),
                          ),
                        )
                      else
                        ...journalState.entries.map(
                          (entry) => ListTile(
                            key: ValueKey(entry.createdAt),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 5,
                            ),
                            leading: Icon(
                              Icons.favorite_outline,
                              color: primaryColor,
                            ),
                            title: Text(
                              '${entry.mood} • '
                              '${widget.dateLabel(entry.createdAt)}',
                            ),
                            subtitle: Text(
                              entry.reflection,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              tooltip: 'Edit reflection',
                              onPressed: _isOpeningEditor
                                  ? null
                                  : () => _editEntry(entry),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
