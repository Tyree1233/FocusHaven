import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../l10n/focus_haven_localizations.dart';

class CustomDurationSheet extends StatefulWidget {
  const CustomDurationSheet({
    required this.sessionLabel,
    required this.sessionColor,
    required this.initialDuration,
    this.maximumMinutes = 180,
    this.foregroundColor = const Color(0xFF211442),
    super.key,
  });

  final String sessionLabel;
  final Color sessionColor;
  final Duration initialDuration;
  final int maximumMinutes;
  final Color foregroundColor;

  @override
  State<CustomDurationSheet> createState() => _CustomDurationSheetState();
}

class _CustomDurationSheetState extends State<CustomDurationSheet> {
  static const _favoriteMinutes = <int>[5, 10, 15, 25, 45, 60];

  late final FixedExtentScrollController _minutesController;
  late final FixedExtentScrollController _secondsController;
  late int _selectedMinutes;
  late int _selectedSeconds;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    final totalSeconds = widget.initialDuration.inSeconds.clamp(
      0,
      widget.maximumMinutes * 60 + 59,
    );
    _selectedMinutes = totalSeconds ~/ 60;
    _selectedSeconds = totalSeconds % 60;
    _minutesController = FixedExtentScrollController(
      initialItem: _selectedMinutes,
    );
    _secondsController = FixedExtentScrollController(
      initialItem: _selectedSeconds,
    );
  }

  @override
  void dispose() {
    _minutesController.dispose();
    _secondsController.dispose();
    super.dispose();
  }

  void _selectFavorite(int minutes) {
    if (_isClosing) return;
    setState(() {
      _selectedMinutes = minutes;
      _selectedSeconds = 0;
    });
    _minutesController.animateToItem(
      minutes,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
    _secondsController.animateToItem(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _selectMinutes(int minutes) {
    if (_isClosing) return;
    setState(() => _selectedMinutes = minutes);
  }

  void _selectSeconds(int seconds) {
    if (_isClosing) return;
    setState(() => _selectedSeconds = seconds);
  }

  void _adjustMinutes(int delta) {
    if (_isClosing) return;
    final next = (_selectedMinutes + delta)
        .clamp(0, widget.maximumMinutes)
        .toInt();
    if (next == _selectedMinutes) return;
    setState(() => _selectedMinutes = next);
    _minutesController.animateToItem(
      next,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _adjustSeconds(int delta) {
    if (_isClosing) return;
    final next = (_selectedSeconds + delta).clamp(0, 59).toInt();
    if (next == _selectedSeconds) return;
    setState(() => _selectedSeconds = next);
    _secondsController.animateToItem(
      next,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _submit() {
    if (_isClosing) return;
    setState(() => _isClosing = true);
    Navigator.pop(
      context,
      Duration(minutes: _selectedMinutes, seconds: _selectedSeconds),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selectedTime =
        '${_selectedMinutes.toString().padLeft(2, '0')}:'
        '${_selectedSeconds.toString().padLeft(2, '0')}';
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        key: const ValueKey<String>('custom-duration-scroll'),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4,
              width: 42,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.customDurationTitle(widget.sessionLabel),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.customDurationInstructions,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: _favoriteMinutes
                  .where((minutes) => minutes <= widget.maximumMinutes)
                  .map(
                    (minutes) => ChoiceChip(
                      key: ValueKey<String>(
                        'custom-duration-favorite-$minutes',
                      ),
                      label: Text(l10n.durationMinutesShort(minutes)),
                      selected: _selectedMinutes == minutes,
                      onSelected: _isClosing
                          ? null
                          : (_) => _selectFavorite(minutes),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 150,
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      key: const ValueKey<String>(
                        'custom-duration-minutes-semantics',
                      ),
                      container: true,
                      value: l10n.durationMinutes(_selectedMinutes),
                      increasedValue: _selectedMinutes < widget.maximumMinutes
                          ? l10n.durationMinutes(_selectedMinutes + 1)
                          : null,
                      decreasedValue: _selectedMinutes > 0
                          ? l10n.durationMinutes(_selectedMinutes - 1)
                          : null,
                      onIncrease:
                          _isClosing ||
                              _selectedMinutes >= widget.maximumMinutes
                          ? null
                          : () => _adjustMinutes(1),
                      onDecrease: _isClosing || _selectedMinutes <= 0
                          ? null
                          : () => _adjustMinutes(-1),
                      child: ExcludeSemantics(
                        child: CupertinoPicker.builder(
                          scrollController: _minutesController,
                          itemExtent: 42,
                          selectionOverlay:
                              CupertinoPickerDefaultSelectionOverlay(
                                background: widget.sessionColor.withValues(
                                  alpha: 0.15,
                                ),
                              ),
                          onSelectedItemChanged: _isClosing
                              ? null
                              : _selectMinutes,
                          childCount: widget.maximumMinutes + 1,
                          itemBuilder: (context, index) => Center(
                            child: Text(
                              l10n.durationMinutesShort(index),
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Semantics(
                      key: const ValueKey<String>(
                        'custom-duration-seconds-semantics',
                      ),
                      container: true,
                      value: l10n.durationSeconds(_selectedSeconds),
                      increasedValue: _selectedSeconds < 59
                          ? l10n.durationSeconds(_selectedSeconds + 1)
                          : null,
                      decreasedValue: _selectedSeconds > 0
                          ? l10n.durationSeconds(_selectedSeconds - 1)
                          : null,
                      onIncrease: _isClosing || _selectedSeconds >= 59
                          ? null
                          : () => _adjustSeconds(1),
                      onDecrease: _isClosing || _selectedSeconds <= 0
                          ? null
                          : () => _adjustSeconds(-1),
                      child: ExcludeSemantics(
                        child: CupertinoPicker.builder(
                          scrollController: _secondsController,
                          itemExtent: 42,
                          selectionOverlay:
                              CupertinoPickerDefaultSelectionOverlay(
                                background: widget.sessionColor.withValues(
                                  alpha: 0.15,
                                ),
                              ),
                          onSelectedItemChanged: _isClosing
                              ? null
                              : _selectSeconds,
                          childCount: 60,
                          itemBuilder: (context, index) => Center(
                            child: Text(
                              l10n.durationSecondsShort(
                                index.toString().padLeft(2, '0'),
                              ),
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey<String>('custom-duration-submit'),
                onPressed: _isClosing ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: widget.sessionColor,
                  foregroundColor: widget.foregroundColor,
                  minimumSize: const Size.fromHeight(54),
                ),
                child: Text(l10n.customDurationSet(selectedTime)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
