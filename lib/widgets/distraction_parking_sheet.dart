import 'package:flutter/material.dart';

import '../models/parked_thought.dart';
import 'text_entry_dialog.dart';

typedef ParkedThoughtAdder = void Function(String thought);
typedef ParkedThoughtRecordsReader = List<ParkedThought> Function();
typedef ParkedThoughtIdAction = void Function(String id);
typedef ParkedThoughtIdUpdater = void Function(String id, String thought);

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
  final VoidCallback clearThoughts;
  final VoidCallback clearCompletedThoughts;
  final Color foregroundColor;

  @override
  State<DistractionParkingSheet> createState() =>
      _DistractionParkingSheetState();
}

class _DistractionParkingSheetState extends State<DistractionParkingSheet> {
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
                onPressed: _addThought,
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
    return ListTile(
      key: ValueKey('parked-thought-${thought.id}'),
      contentPadding: EdgeInsets.zero,
      leading: IconButton(
        tooltip: 'Mark thought complete',
        color: Theme.of(context).colorScheme.primary,
        icon: const Icon(Icons.radio_button_unchecked),
        onPressed: () {
          widget.completeThought(thought.id);
          setState(() {});
        },
      ),
      title: Text(thought.text),
      trailing: Wrap(
        spacing: 0,
        children: [
          IconButton(
            tooltip: 'Edit thought',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _editHistoryThought(thought),
          ),
          IconButton(
            tooltip: 'Remove thought',
            icon: const Icon(Icons.close),
            onPressed: () {
              widget.removeThoughtById(thought.id);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedThought(BuildContext context, ParkedThought thought) {
    final completedAt = thought.completedAt;
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
            tooltip: 'Return thought to parking lot',
            icon: const Icon(Icons.undo),
            onPressed: () {
              widget.reopenThought(thought.id);
              setState(() {});
            },
          ),
          IconButton(
            tooltip: 'Remove completed thought',
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              widget.removeThoughtById(thought.id);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _buildClearActions(
    List<ParkedThought> activeThoughts,
    List<ParkedThought> completedThoughts,
  ) {
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        if (activeThoughts.isNotEmpty)
          TextButton.icon(
            onPressed: () {
              widget.clearThoughts();
              setState(() {});
            },
            icon: const Icon(Icons.clear_all),
            label: const Text('Clear parked'),
          ),
        if (completedThoughts.isNotEmpty)
          TextButton.icon(
            onPressed: () {
              widget.clearCompletedThoughts();
              setState(() {});
            },
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text('Clear completed'),
          ),
      ],
    );
  }

  Future<void> _addThought() async {
    final thought = await _editParkedThought();
    if (thought == null) return;

    widget.addThought(thought);
    if (mounted) setState(() {});
  }

  Future<void> _editHistoryThought(ParkedThought existingThought) async {
    final thought = await _editParkedThought(
      existingThought: existingThought.text,
    );
    if (thought == null) return;

    widget.renameThought(existingThought.id, thought);
    if (mounted) setState(() {});
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
