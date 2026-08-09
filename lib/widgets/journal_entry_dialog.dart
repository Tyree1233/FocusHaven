import 'package:flutter/material.dart';

@immutable
class JournalEntryDraft {
  const JournalEntryDraft({required this.mood, required this.reflection});

  final String mood;
  final String reflection;
}

/// A lifecycle-safe editor for one journal entry.
///
/// The dialog owns its text controller and mood selection. It returns an
/// immutable draft so persistence can happen after the route closes.
class JournalEntryDialog extends StatefulWidget {
  const JournalEntryDialog({
    required this.initialMood,
    required this.initialReflection,
    required this.prompt,
    required this.moods,
    super.key,
  }) : assert(moods.length > 0, 'At least one mood is required.');

  final String initialMood;
  final String initialReflection;
  final String prompt;
  final List<String> moods;

  static Future<JournalEntryDraft?> show(
    BuildContext context, {
    required String initialMood,
    required String initialReflection,
    required String prompt,
    required List<String> moods,
  }) {
    return showDialog<JournalEntryDraft>(
      context: context,
      builder: (_) => JournalEntryDialog(
        initialMood: initialMood,
        initialReflection: initialReflection,
        prompt: prompt,
        moods: List<String>.unmodifiable(moods),
      ),
    );
  }

  @override
  State<JournalEntryDialog> createState() => _JournalEntryDialogState();
}

class _JournalEntryDialogState extends State<JournalEntryDialog> {
  late final TextEditingController _controller;
  late String _selectedMood;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialReflection);
    _selectedMood = widget.moods.contains(widget.initialMood)
        ? widget.initialMood
        : widget.moods.first;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.pop(
      context,
      JournalEntryDraft(mood: _selectedMood, reflection: _controller.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Today's reflection"),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('How are you feeling?'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final mood in widget.moods)
                    ChoiceChip(
                      label: Text(mood),
                      selected: _selectedMood == mood,
                      onSelected: (_) {
                        setState(() => _selectedMood = mood);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _controller,
                autofocus: true,
                maxLines: 5,
                maxLength: 800,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: widget.prompt,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save reflection')),
      ],
    );
  }
}
