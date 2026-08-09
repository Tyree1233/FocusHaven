import 'package:flutter/material.dart';

import 'text_entry_dialog.dart';

typedef ParkedThoughtsReader = List<String> Function();
typedef ParkedThoughtAdder = void Function(String thought);
typedef ParkedThoughtUpdater = void Function(int index, String thought);
typedef ParkedThoughtRemover = void Function(int index);

class DistractionParkingSheet extends StatefulWidget {
  const DistractionParkingSheet({
    required this.readThoughts,
    required this.addThought,
    required this.updateThought,
    required this.removeThought,
    required this.clearThoughts,
    this.foregroundColor = const Color(0xFF211442),
    super.key,
  });

  final ParkedThoughtsReader readThoughts;
  final ParkedThoughtAdder addThought;
  final ParkedThoughtUpdater updateThought;
  final ParkedThoughtRemover removeThought;
  final VoidCallback clearThoughts;
  final Color foregroundColor;

  @override
  State<DistractionParkingSheet> createState() =>
      _DistractionParkingSheetState();
}

class _DistractionParkingSheetState extends State<DistractionParkingSheet> {
  @override
  Widget build(BuildContext context) {
    final thoughts = widget.readThoughts();

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
                'Distraction parking lot',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              const Text(
                'Your saved thoughts stay on this device until you clear them.',
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
                child: thoughts.isEmpty
                    ? const Center(
                        child: Text(
                          'Nothing parked yet. Keep your attention where you want it.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.separated(
                        itemCount: thoughts.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1, color: Colors.white12),
                        itemBuilder: (context, index) => ListTile(
                          leading: Icon(
                            Icons.bookmark_outline,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(thoughts[index]),
                          trailing: Wrap(
                            spacing: 0,
                            children: [
                              IconButton(
                                tooltip: 'Edit thought',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () =>
                                    _editThought(index, thoughts[index]),
                              ),
                              IconButton(
                                tooltip: 'Remove thought',
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  widget.removeThought(index);
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              if (thoughts.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    widget.clearThoughts();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Clear parking lot'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addThought() async {
    final thought = await _editParkedThought();
    if (thought == null) return;

    widget.addThought(thought);
    if (mounted) setState(() {});
  }

  Future<void> _editThought(int index, String existingThought) async {
    final thought = await _editParkedThought(existingThought: existingThought);
    if (thought == null) return;

    widget.updateThought(index, thought);
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
