import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';

class ReminderSheet extends ConsumerStatefulWidget {
  const ReminderSheet({super.key});

  @override
  ConsumerState<ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends ConsumerState<ReminderSheet> {
  static const _weekdayLabels = <int, String>{
    DateTime.monday: 'Mon',
    DateTime.tuesday: 'Tue',
    DateTime.wednesday: 'Wed',
    DateTime.thursday: 'Thu',
    DateTime.friday: 'Fri',
    DateTime.saturday: 'Sat',
    DateTime.sunday: 'Sun',
  };

  late final Set<int> _selectedWeekdays;

  @override
  void initState() {
    super.initState();
    _selectedWeekdays = ref.read(reminderStateProvider).weekdays.toSet();
  }

  Future<void> _toggleReminder(bool enabled, TimeOfDay currentTime) async {
    final reminderService = ref.read(reminderServiceProvider);

    if (!enabled) {
      await reminderService.disableDailyReminder();
      return;
    }

    final selected = await showTimePicker(
      context: context,
      initialTime: currentTime,
    );
    if (selected == null || !mounted) return;

    final scheduled = await reminderService.setDailyReminder(
      selected,
      weekdays: _selectedWeekdays,
    );
    if (!mounted || scheduled) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Allow notifications to schedule a focus time.'),
      ),
    );
  }

  Future<void> _chooseTimeAndSchedule(TimeOfDay currentTime) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: currentTime,
    );
    if (selected == null || !mounted) return;

    final scheduled = await ref
        .read(reminderServiceProvider)
        .setDailyReminder(selected, weekdays: _selectedWeekdays);
    if (!mounted) return;

    final formattedTime = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(selected);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          scheduled
              ? 'Focus time scheduled for $formattedTime.'
              : 'Allow notifications to schedule a focus time.',
        ),
      ),
    );
  }

  Future<void> _sendTestNotification() async {
    final notifications = ref.read(notificationServiceProvider);
    final permitted = await notifications.requestPermissions();
    if (!mounted) return;

    if (!permitted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Allow notifications to send a test alert.'),
        ),
      );
      return;
    }

    await notifications.showTestNotification();
  }

  void _toggleWeekday(int weekday, bool selected) {
    if (!selected && _selectedWeekdays.length == 1) return;

    setState(() {
      if (selected) {
        _selectedWeekdays.add(weekday);
      } else {
        _selectedWeekdays.remove(weekday);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final reminderState = ref.watch(reminderStateProvider);
    final scheduledDays = _weekdayLabels.entries
        .where((entry) => reminderState.weekdays.contains(entry.key))
        .map((entry) => entry.value)
        .join(', ');
    final formattedTime = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(reminderState.time);

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Scheduled focus time',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose the days and time for a gentle invitation to focus. '
                'You can change or turn it off at any time.',
                style: TextStyle(color: Colors.white70, height: 1.35),
              ),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  reminderState.isEnabled
                      ? Icons.event_available_outlined
                      : Icons.event_busy_outlined,
                ),
                title: Text(
                  reminderState.isEnabled
                      ? 'Focus time is scheduled'
                      : 'No focus time scheduled',
                ),
                subtitle: Text(
                  '$formattedTime'
                  '${reminderState.isEnabled ? ' • $scheduledDays' : ''}',
                ),
                trailing: Switch(
                  value: reminderState.isEnabled,
                  onChanged: (enabled) =>
                      _toggleReminder(enabled, reminderState.time),
                ),
              ),
              const SizedBox(height: 8),
              Text('Repeat on', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _weekdayLabels.entries
                    .map(
                      (entry) => FilterChip(
                        label: Text(entry.value),
                        selected: _selectedWeekdays.contains(entry.key),
                        onSelected: (selected) =>
                            _toggleWeekday(entry.key, selected),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose at least one day. Changes are saved when you choose '
                'a focus time.',
                style: TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _chooseTimeAndSchedule(reminderState.time),
                icon: const Icon(Icons.schedule_outlined),
                label: Text(
                  reminderState.isEnabled
                      ? 'Update focus time'
                      : 'Choose focus time',
                ),
              ),
              TextButton.icon(
                onPressed: _sendTestNotification,
                icon: const Icon(Icons.notifications_outlined),
                label: const Text('Send a test notification'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
