import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:rxdart/rxdart.dart';

import '../models.dart';

/// Watches the OS audio routing (speaker / wired / Bluetooth / cast) and
/// emits an [OutputRoute] whenever the route changes.
///
/// Implements requirement #4: show the correct output icon and "follow the
/// user" when they change audio destination.
class RouteWatcher {
  RouteWatcher() {
    _init();
  }

  final BehaviorSubject<OutputRoute> _current =
      BehaviorSubject<OutputRoute>.seeded(OutputRoute.speaker);

  Stream<OutputRoute> get stream => _current.stream;
  OutputRoute get value => _current.value;

  StreamSubscription<AudioDevicesChangedEvent>? _sub;
  StreamSubscription<AudioInterruptionEvent>? _interruptSub;
  StreamSubscription<void>? _noisySub;

  Future<void> _init() async {
    final session = await AudioSession.instance;

    // Initial state from currently active output(s).
    await _refresh(session);

    _sub = session.devicesChangedEventStream.listen((_) => _refresh(session));

    // BECOMING_NOISY (Android) / route change (iOS): headphones unplugged or
    // BT disconnect — pause out of courtesy per platform guidelines.
    _noisySub = session.becomingNoisyEventStream.listen((_) {
      _current.add(OutputRoute.speaker);
    });

    _interruptSub = session.interruptionEventStream.listen((_) {});
  }

  Future<void> _refresh(AudioSession session) async {
    final devices = await session.getDevices(includeInputs: false);
    if (devices.isEmpty) {
      _current.add(OutputRoute.speaker);
      return;
    }

    // Priority: cast > bluetooth > wired > speaker.
    AudioDevice? pick;
    for (final d in devices) {
      switch (d.type) {
        case AudioDeviceType.bluetoothA2dp:
        case AudioDeviceType.bluetoothLe:
        case AudioDeviceType.bluetoothSco:
          pick = d;
          break;
        case AudioDeviceType.wiredHeadphones:
        case AudioDeviceType.wiredHeadset:
          pick ??= d;
          break;
        default:
          break;
      }
    }
    pick ??= devices.first;

    final kind = switch (pick.type) {
      AudioDeviceType.bluetoothA2dp ||
      AudioDeviceType.bluetoothLe ||
      AudioDeviceType.bluetoothSco =>
        OutputRouteKind.bluetooth,
      AudioDeviceType.wiredHeadphones ||
      AudioDeviceType.wiredHeadset =>
        OutputRouteKind.wired,
      AudioDeviceType.builtInSpeaker ||
      AudioDeviceType.builtInEarpiece =>
        OutputRouteKind.speaker,
      _ => OutputRouteKind.unknown,
    };
    _current.add(OutputRoute(kind: kind, deviceName: pick.name));
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _noisySub?.cancel();
    await _interruptSub?.cancel();
    await _current.close();
  }
}
