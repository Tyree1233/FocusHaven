import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/haven_plan.dart';
import '../providers/app_providers.dart';

/// A private, ephemeral check-in that previews a local Haven Plan.
///
/// The sheet never starts a timer or persists the user's selections. It only
/// returns a plan after the user explicitly accepts the recommendation.
class HavenPlanSheet extends ConsumerStatefulWidget {
  const HavenPlanSheet({super.key});

  @override
  ConsumerState<HavenPlanSheet> createState() => _HavenPlanSheetState();
}

class _HavenPlanSheetState extends ConsumerState<HavenPlanSheet> {
  static const _timeOptions = [15, 30, 60, 90];

  HavenEnergy _energy = HavenEnergy.steady;
  int _availableMinutes = 30;

  String _energyLabel(HavenEnergy energy) => switch (energy) {
    HavenEnergy.low => 'Low',
    HavenEnergy.steady => 'Steady',
    HavenEnergy.strong => 'Strong',
  };

  IconData _energyIcon(HavenEnergy energy) => switch (energy) {
    HavenEnergy.low => Icons.spa_outlined,
    HavenEnergy.steady => Icons.wb_sunny_outlined,
    HavenEnergy.strong => Icons.bolt_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(
      havenPlanProvider((energy: _energy, availableMinutes: _availableMinutes)),
    );
    final colors = Theme.of(context).colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_outlined, color: colors.primary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Plan a gentle start',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Close Haven Plan',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Choose what you have right now. FocusHaven will suggest—not decide—your next session.',
              style: TextStyle(color: Colors.white70, height: 1.35),
            ),
            const SizedBox(height: 22),
            const Text(
              'How is your energy?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final energy in HavenEnergy.values)
                  ChoiceChip(
                    avatar: Icon(_energyIcon(energy), size: 18),
                    label: Text(_energyLabel(energy)),
                    selected: _energy == energy,
                    onSelected: (selected) {
                      if (selected) setState(() => _energy = energy);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'How much time do you have?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final minutes in _timeOptions)
                  ChoiceChip(
                    label: Text('$minutes min'),
                    selected: _availableMinutes == minutes,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _availableMinutes = minutes);
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: 22),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.32),
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'YOUR HAVEN PLAN',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      plan.taskTitle,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      plan.firstStep,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        _PlanDetail(
                          icon: Icons.timer_outlined,
                          label: '${plan.focusMinutes} min focus',
                        ),
                        _PlanDetail(
                          icon: Icons.self_improvement_outlined,
                          label: plan.breakMinutes == 0
                              ? 'Break when ready'
                              : '${plan.breakMinutes} min break',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      plan.explanation,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline, size: 17, color: Colors.white60),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Private and temporary. This plan is built on this device and is not saved.',
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const ValueKey('haven-plan-start'),
              onPressed: () => Navigator.of(context).pop(plan),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text('Start ${plan.focusMinutes}-minute focus'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Not right now'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanDetail extends StatelessWidget {
  const _PlanDetail({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 17), const SizedBox(width: 6), Text(label)],
      ),
    ),
  );
}
