enum HavenWindowHoldStatus { empty, held, arrived }

/// One private, user-created reminder for an optional Haven Window.
///
/// The hold stores only bounded UTC boundaries. It contains no calendar,
/// event, task, account, or notification content and is not a calendar event.
class HavenWindowHold {
  const HavenWindowHold._({
    required this.status,
    this.startsAtUtc,
    this.endsAtUtc,
  });

  const HavenWindowHold.empty() : this._(status: HavenWindowHoldStatus.empty);

  factory HavenWindowHold.held({
    required DateTime startsAtUtc,
    required DateTime endsAtUtc,
  }) {
    assert(startsAtUtc.isUtc);
    assert(endsAtUtc.isUtc);
    assert(startsAtUtc.isBefore(endsAtUtc));
    return HavenWindowHold._(
      status: HavenWindowHoldStatus.held,
      startsAtUtc: startsAtUtc,
      endsAtUtc: endsAtUtc,
    );
  }

  factory HavenWindowHold.arrived({
    required DateTime startsAtUtc,
    required DateTime endsAtUtc,
  }) {
    assert(startsAtUtc.isUtc);
    assert(endsAtUtc.isUtc);
    assert(startsAtUtc.isBefore(endsAtUtc));
    return HavenWindowHold._(
      status: HavenWindowHoldStatus.arrived,
      startsAtUtc: startsAtUtc,
      endsAtUtc: endsAtUtc,
    );
  }

  final HavenWindowHoldStatus status;
  final DateTime? startsAtUtc;
  final DateTime? endsAtUtc;

  bool get isHeld =>
      status != HavenWindowHoldStatus.empty &&
      startsAtUtc != null &&
      endsAtUtc != null;

  bool get hasArrived => status == HavenWindowHoldStatus.arrived && isHeld;
}
