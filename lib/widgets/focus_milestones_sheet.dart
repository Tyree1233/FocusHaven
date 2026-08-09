import 'package:flutter/material.dart';

import '../models/focus_milestone.dart';

class FocusMilestonesSheet extends StatefulWidget {
  const FocusMilestonesSheet({required this.milestones, super.key});

  final List<FocusMilestone> milestones;

  @override
  State<FocusMilestonesSheet> createState() => _FocusMilestonesSheetState();
}

class _FocusMilestonesSheetState extends State<FocusMilestonesSheet> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = widget.milestones
        .where((milestone) => milestone.unlocked)
        .length;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
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
                'Focus milestones',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 5),
              Text(
                '$unlocked of ${widget.milestones.length} unlocked',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: false,
                  interactive: true,
                  child: ListView.separated(
                    controller: _scrollController,
                    itemCount: widget.milestones.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, color: Colors.white12),
                    itemBuilder: (context, index) {
                      final milestone = widget.milestones[index];
                      final primaryColor = Theme.of(
                        context,
                      ).colorScheme.primary;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: primaryColor.withValues(
                            alpha: milestone.unlocked ? 0.22 : 0.08,
                          ),
                          child: Icon(
                            milestone.unlocked
                                ? Icons.emoji_events_outlined
                                : Icons.lock_outline,
                            color: milestone.unlocked
                                ? primaryColor
                                : Colors.white38,
                          ),
                        ),
                        title: Text(milestone.title),
                        subtitle: Text(milestone.detail),
                        trailing: Icon(
                          milestone.unlocked
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: milestone.unlocked
                              ? primaryColor
                              : Colors.white38,
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
