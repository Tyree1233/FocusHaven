import 'dart:async';

import 'package:flutter/material.dart';

import '../models/parked_thought.dart';
import 'text_entry_dialog.dart';

typedef ParkedThoughtAdder = FutureOr<void> Function(String thought);
typedef ParkedThoughtRecordsReader = List<ParkedThought> Function();
typedef ParkedThoughtIdAction = FutureOr<void> Function(String id);
typedef ParkedThoughtClearAction = FutureOr<void> Function();
typedef ParkedThoughtIdUpdater =
    FutureOr<void> Function(String id, String thought);

class DistractionParkingSheet extends StatefulWidget {
  const DistractionParkingSheet.withHistory({
    required this.readActiveThoughts,
    required this.readCompletedThoughts,
    required this.addThought,
    required this.renameThought,
    required this.completeThought,
    required this.reopenThought,
    required this.removeThoughtById,
    required this.clearThoughts,
    required this.clearCompletedThoughts,
    this.foregroundColor = const Color(0xFF211442),
    super.key,
  });

  final ParkedThoughtRecordsReader readActiveThoughts;
  final ParkedThoughtRecordsReader readCompletedThoughts;
  final ParkedThoughtAdder addThought;
  final ParkedThoughtIdUpdater renameThought;
  final ParkedThoughtIdAction completeThought;
  final ParkedThoughtIdAction reopenThought;
  final ParkedThoughtIdAction removeThoughtById;
  final ParkedThoughtClearAction clearThoughts;
  final ParkedThoughtClearAction clearCompletedThoughts;
  final Color foregroundColor;

  @override
  State<DistractionParkingSheet> createState() =>
      _DistractionParkingSheetState();
}

class _DistractionParkingSheetState extends State<DistractionParkingSheet> {
  bool _isEditingThought = false;
  final Set<String> _pendingThoughtIds = <String>{};
  bool _isClearingActiveThoughts = false;
  bool _isClearingCompletedThoughts = false;

  void _showEditorFailure(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final activeThoughts = widget.readActiveThoughts();
    final completedThoughts = widget.readCompletedThoughts();
    final hasThoughts =
        activeThoughts.isNotEmpty || completedThoughts.isNotEmpty;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
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
                'Distraction parking lot',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              const Text(
                'Save distractions for later and keep a private history of what you handled.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const ValueKey<String>('add-parked-thought'),
                onPressed: _isEditingThought ? null : _addThought,
                icon: const Icon(Icons.add),
                label: const Text('Add a thought'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: widget.foregroundColor,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: hasThoughts
                    ? _buildHistoryList(
                        context,
                        activeThoughts,
                        completedThoughts,
                      )
                    : const Center(
                        child: Text(
                          'Nothing parked yet. Keep your attention where you want it.',
                          textAlign: TextAlign.center,
                        ),
                      ),
              ),
              if (hasThoughts)
                _buildClearActions(activeThoughts, completedThoughts),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryList(
    BuildContext context,
    List<ParkedThought> activeThoughts,
    List<ParkedThought> completedThoughts,
  ) {
    return ListView(
      children: [
        if (activeThoughts.isNotEmpty) ...[
          _SectionLabel(label: 'Parked (${activeThoughts.length})'),
          for (final thought in activeThoughts)
            _buildActiveThought(context, thought),
        ],
        if (activeThoughts.isNotEmpty && completedThoughts.isNotEmpty)
          const Divider(height: 24, color: Colors.white12),
        if (completedThoughts.isNotEmpty) ...[
          _SectionLabel(label: 'Completed (${completedThoughts.length})'),
          for (final thought in completedThoughts)
            _buildCompletedThought(context, thought),
        ],
      ],
    );
  }

  Widget _buildActiveThought(BuildContext context, ParkedThought thought) {
    final actionsDisabled =
        _pendingThoughtIds.contains(thought.id) || _isClearingActiveThoughts;
    return ListTile(
      key: ValueKey('parked-thought-${thought.id}'),
      contentPadding: EdgeInsets.zero,
      leading: IconButton(
        key: ValueKey<String>('complete-parked-thought-${thought.id}'),
        tooltip: 'Mark thought complete',
        color: Theme.of(context).colorScheme.primary,
        icon: const Icon(Icons.radio_button_unchecked),
        onPressed: actionsDisabled
            ? null
            : () => _runThoughtAction(
                thought.id,
                widget.completeThought,
                'Thought could not be completed. Please try again.',
              ),
      ),
      title: Text(thought.text),
      trailing: Wrap(
        spacing: 0,
        children: [
          IconButton(
            key: ValueKey<String>('edit-parked-thought-${thought.id}'),
            tooltip: 'Edit thought',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _isEditingThought || actionsDisabled
                ? null
                : () => _editHistoryThought(thought),
          ),
          IconButton(
            key: ValueKey<String>('remove-parked-thought-${thought.id}'),
            tooltip: 'Remove thought',
            icon: const Icon(Icons.close),
            onPressed: actionsDisabled
                ? null
                : () => _runThoughtAction(
                    thought.id,
                    widget.removeThoughtById,
                    'Thought could not be removed. Please try again.',
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedThought(BuildContext context, ParkedThought thought) {
    final completedAt = thought.completedAt;
    final actionsDisabled =
        _pendingThoughtIds.contains(thought.id) || _isClearingCompletedThoughts;
    return ListTile(
      key: ValueKey('completed-thought-${thought.id}'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        Icons.check_circle,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(
        thought.text,
        style: const TextStyle(
          color: Colors.white70,
          decoration: TextDecoration.lineThrough,
        ),
      ),
      subtitle: completedAt == null
          ? null
          : Text(
              'Completed ${MaterialLocalizations.of(context).formatShortDate(completedAt.toLocal())}',
              style: const TextStyle(color: Colors.white54),
            ),
      trailing: Wrap(
        spacing: 0,
        children: [
          IconButton(
            key: ValueKey<String>('reopen-parked-thought-${thought.id}'),
            tooltip: 'Return thought to parking lot',
            icon: const Icon(Icons.undo),
            onPressed: actionsDisabled
                ? null
                : () => _runThoughtAction(
                    thought.id,
                    widget.reopenThought,
                    'Thought could not be returned to the parking lot. Please try again.',
                  ),
          ),
          IconButton(
            key: ValueKey<String>('remove-completed-thought-${thought.id}'),
            tooltip: 'Remove completed thought',
            icon: const Icon(Icons.delete_outline),
            onPressed: actionsDisabled
                ? null
                : () => _runThoughtAction(
                    thought.id,
                    widget.removeThoughtById,
                    'Thought could not be removed. Please try again.',
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildClearActions(
    List<ParkedThought> activeThoughts,
    List<ParkedThought> completedThoughts,
  ) {
    final activeActionsPending = activeThoughts.any(
      (thought) => _pendingThoughtIds.contains(thought.id),
    );
    final completedActionsPending = completedThoughts.any(
      (thought) => _pendingThoughtIds.contains(thought.id),
    );
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        if (activeThoughts.isNotEmpty)
          TextButton.icon(
            key: const ValueKey<String>('clear-parked-thoughts'),
            onPressed: _isClearingActiveThoughts || activeActionsPending
                ? null
                : () => _runClearAction(
                    completed: false,
                    action: widget.clearThoughts,
                    failureMessage:
                        'Parked thoughts could not be cleared. Please try again.',
                  ),
            icon: const Icon(Icons.clear_all),
            label: const Text('Clear parked'),
          ),
        if (completedThoughts.isNotEmpty)
          TextButton.icon(
            key: const ValueKey<String>('clear-completed-thoughts'),
            onPressed: _isClearingCompletedThoughts || completedActionsPending
                ? null
                : () => _runClearAction(
                    completed: true,
                    action: widget.clearCompletedThoughts,
                    failureMessage:
                        'Completed thoughts could not be cleared. Please try again.',
                  ),
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text('Clear completed'),
          ),
      ],
    );
  }

  Future<void> _runThoughtAction(
    String id,
    ParkedThoughtIdAction action,
    String failureMessage,
  ) async {
    if (_pendingThoughtIds.contains(id)) return;
    setState(() => _pendingThoughtIds.add(id));
    try {
      await action(id);
    } catch (_) {
      _showEditorFailure(failureMessage);
    } finally {
      _pendingThoughtIds.remove(id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _runClearAction({
    required bool completed,
    required ParkedThoughtClearAction action,
    required String failureMessage,
  }) async {
    if (completed ? _isClearingCompletedThoughts : _isClearingActiveThoughts) {
      return;
    }
    setState(() {
      if (completed) {
        _isClearingCompletedThoughts = true;
      } else {
        _isClearingActiveThoughts = true;
      }
    });
    try {
      await action();
    } catch (_) {
      _showEditorFailure(failureMessage);
    } finally {
      if (completed) {
        _isClearingCompletedThoughts = false;
      } else {
        _isClearingActiveThoughts = false;
      }
      if (mounted) setState(() {});
    }
  }

  Future<void> _addThought() async {
    if (_isEditingThought) return;
    setState(() => _isEditingThought = true);
    try {
      final thought = await _editParkedThought();
      if (thought == null) return;

      await widget.addThought(thought);
    } catch (_) {
      _showEditorFailure('Thought could not be added. Please try again.');
    } finally {
      if (mounted) setState(() => _isEditingThought = false);
    }
  }

  Future<void> _editHistoryThought(ParkedThought existingThought) async {
    if (_isEditingThought) return;
    setState(() => _isEditingThought = true);
    try {
      final thought = await _editParkedThought(
        existingThought: existingThought.text,
      );
      if (thought == null) return;

      await widget.renameThought(existingThought.id, thought);
    } catch (_) {
      _showEditorFailure('Thought could not be updated. Please try again.');
    } finally {
      if (mounted) setState(() => _isEditingThought = false);
    }
  }

  Future<String?> _editParkedThought({String? existingThought}) async {
    return TextEntryDialog.show(
      context,
      title: existingThought == null
          ? 'Add a parked thought'
          : 'Edit parked thought',
      confirmLabel: existingThought == null ? 'Add thought' : 'Save changes',
      initialValue: existingThought ?? '',
      hintText: 'Example: Reply to Jordan after this session',
      maxLength: 140,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}
