import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/haven_loop_state.dart';
import 'focus_queue_service.dart';
import 'timer_service.dart';

enum HavenLoopResolution { completed, keptForLater, unavailable }

/// An opaque, single-use capability for one reviewed Smart Reset transition.
///
/// It contains only the selected queue-item identity. Task text remains owned
/// by [FocusQueueService] and is revalidated through the owning services when
/// the capability is consumed.
final class HavenLoopRecoveryTicket {
  const HavenLoopRecoveryTicket._(this._generation, this._selectedItemId);

  final int _generation;
  final String _selectedItemId;
}

/// Coordinates one explicitly selected queue item with the existing timer.
///
/// Only the queue-item ID is stored. The queue remains the source of task text,
/// and every mutation is delegated to the service that already owns it.
class HavenLoopService extends ChangeNotifier {
  HavenLoopService({
    required TimerService timerService,
    required FocusQueueService focusQueueService,
  }) : _timer = timerService,
       _queue = focusQueueService {
    _timer.addListener(_reconcile);
    _queue.addListener(_reconcile);
    initialized = _load();
  }

  static const storageKey = 'havenLoopSelectedQueueItemId';

  final TimerService _timer;
  final FocusQueueService _queue;
  String? _selectedItemId;
  HavenLoopState _state = const HavenLoopState.empty();
  bool _isDisposed = false;
  bool _hasLoaded = false;
  int _nextRecoveryGeneration = 0;
  int? _activeRecoveryGeneration;

  late final Future<void> initialized;

  HavenLoopState get state => _state;

  /// Begins one fail-closed Smart Reset continuity check.
  ///
  /// No capability is issued unless the exact selected queue item still owns
  /// the current Focus intention and the timer can currently offer recovery.
  HavenLoopRecoveryTicket? beginSmartResetRecovery() {
    if (_isDisposed ||
        !_hasLoaded ||
        !_timer.canOfferSmartReset ||
        !_selectionMatchesOwners()) {
      return null;
    }
    final selectedItemId = _selectedItemId;
    if (selectedItemId == null) return null;

    final generation = ++_nextRecoveryGeneration;
    _activeRecoveryGeneration = generation;
    return HavenLoopRecoveryTicket._(generation, selectedItemId);
  }

  /// Consumes one Smart Reset continuity check after the explicit choice.
  ///
  /// A stale, superseded, replayed, renamed, removed, completed, or otherwise
  /// mismatched selection returns false and gains no queue mutation authority.
  bool finishSmartResetRecovery(HavenLoopRecoveryTicket ticket) {
    if (_isDisposed || _activeRecoveryGeneration != ticket._generation) {
      return false;
    }
    _activeRecoveryGeneration = null;
    final preserved =
        _selectedItemId == ticket._selectedItemId && _selectionMatchesOwners();
    _refreshState();
    return preserved;
  }

  Future<bool> selectQueueItem(FocusQueueItem item) async {
    await initialized;
    if (_isDisposed || _timer.sessionType != SessionType.focus) return false;
    final current = _activeItem(item.id);
    if (current == null || current.title != item.title) return false;

    _invalidateRecovery();
    _selectedItemId = current.id;
    _timer.setFocusTask(current.title);
    await _saveSelection();
    _refreshState();
    return true;
  }

  Future<bool> selectQueueItemById(String id) async {
    await initialized;
    final item = _activeItem(id);
    if (item == null) return false;
    return selectQueueItem(item);
  }

  Future<void> setManualFocusTask(String task) async {
    await initialized;
    if (_isDisposed) return;
    _invalidateRecovery();
    await _clearSelection();
    _timer.setFocusTask(task);
    _refreshState();
  }

  Future<HavenLoopResolution> markSelectedTaskComplete() async {
    await initialized;
    if (_isDisposed || !_canResolveCompletion()) {
      return HavenLoopResolution.unavailable;
    }
    final item = _activeItem(_selectedItemId!);
    if (item == null) return HavenLoopResolution.unavailable;

    await _queue.toggle(item.id);
    await _clearSelection();
    _timer.setFocusTask('');
    _refreshState();
    return HavenLoopResolution.completed;
  }

  Future<HavenLoopResolution> keepSelectedTaskForLater() async {
    await initialized;
    if (_isDisposed || !_canResolveCompletion()) {
      return HavenLoopResolution.unavailable;
    }
    await _clearSelection();
    _timer.setFocusTask('');
    _refreshState();
    return HavenLoopResolution.keptForLater;
  }

  Future<void> clearLocalData() async {
    await initialized;
    if (_isDisposed) return;
    _invalidateRecovery();
    _selectedItemId = null;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(storageKey);
    _refreshState();
  }

  Future<void> _load() async {
    await Future.wait([_timer.initialized, _queue.initialized]);
    if (_isDisposed) return;
    final preferences = await SharedPreferences.getInstance();
    _selectedItemId = preferences.getString(storageKey);
    _hasLoaded = true;
    if (!_selectionMatchesOwners()) {
      await _clearSelection();
    }
    _refreshState();
  }

  FocusQueueItem? _activeItem(String id) {
    for (final item in _queue.items) {
      if (item.id == id && !item.isComplete) return item;
    }
    return null;
  }

  bool _selectionMatchesOwners() {
    final id = _selectedItemId;
    if (id == null) return true;
    final item = _activeItem(id);
    return _timer.sessionType == SessionType.focus &&
        item != null &&
        item.title == _timer.focusTask;
  }

  bool _canResolveCompletion() {
    final id = _selectedItemId;
    if (id == null ||
        _timer.sessionType != SessionType.focus ||
        !_timer.isComplete) {
      return false;
    }
    final item = _activeItem(id);
    return item != null && item.title == _timer.focusTask;
  }

  void _reconcile() {
    if (!_hasLoaded || _isDisposed) return;
    if (!_selectionMatchesOwners()) {
      _invalidateRecovery();
      final invalidatedId = _selectedItemId;
      _selectedItemId = null;
      unawaited(_removeStoredSelectionIfUnchanged(invalidatedId));
    }
    _refreshState();
  }

  Future<void> _removeStoredSelectionIfUnchanged(String? invalidatedId) async {
    if (invalidatedId == null) return;
    final preferences = await SharedPreferences.getInstance();
    if (_selectedItemId != null ||
        preferences.getString(storageKey) != invalidatedId) {
      return;
    }
    await preferences.remove(storageKey);
  }

  Future<void> _clearSelection() async {
    _invalidateRecovery();
    _selectedItemId = null;
    await _removeStoredSelection();
  }

  Future<void> _removeStoredSelection() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(storageKey);
  }

  Future<void> _saveSelection() async {
    final id = _selectedItemId;
    if (id == null) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(storageKey, id);
  }

  void _refreshState() {
    if (_isDisposed) return;
    final id = _selectedItemId;
    final next = HavenLoopState(
      selectedItem: id == null ? null : _activeItem(id),
      phase: HavenLoopState.phaseFor(_timer),
      canResolveCompletion: _canResolveCompletion(),
      isInitialized: _hasLoaded,
    );
    if (next == _state) return;
    _state = next;
    notifyListeners();
  }

  void _invalidateRecovery() {
    _activeRecoveryGeneration = null;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _invalidateRecovery();
    _timer.removeListener(_reconcile);
    _queue.removeListener(_reconcile);
    super.dispose();
  }
}
