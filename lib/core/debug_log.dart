// #region agent log
// Debug-session logger with an on-screen HUD overlay.
// Keeps a small in-memory ring buffer of recent log lines and broadcasts
// them so a widget can subscribe and render them on top of the app.
//
// This file is only used during debug-mode instrumentation and can be
// deleted once the session is closed.
import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';

class DebugLogEntry {
  DebugLogEntry({
    required this.timestamp,
    required this.location,
    required this.message,
    this.data,
    this.hypothesisId,
    this.runId,
  });

  final int timestamp;
  final String location;
  final String message;
  final Map<String, dynamic>? data;
  final String? hypothesisId;
  final String? runId;

  String get shortTime {
    final d = DateTime.fromMillisecondsSinceEpoch(timestamp);
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.hour)}:${p(d.minute)}:${p(d.second)}';
  }

  String toShortLine() {
    final tag = hypothesisId != null ? '[$hypothesisId]' : '';
    final loc = location.split(':').last;
    final dataStr = data == null ? '' : ' ${jsonEncode(data)}';
    return '$shortTime $tag $loc → $message$dataStr';
  }
}

class DebugLog {
  DebugLog._();

  static const int _maxEntries = 60;
  static final Queue<DebugLogEntry> _buffer = Queue<DebugLogEntry>();
  static final StreamController<List<DebugLogEntry>> _controller =
      StreamController<List<DebugLogEntry>>.broadcast();

  static Stream<List<DebugLogEntry>> get stream => _controller.stream;
  static List<DebugLogEntry> get snapshot => _buffer.toList(growable: false);

  static void log(String location, String message,
      {Map<String, dynamic>? data, String? hypothesisId, String? runId}) {
    final entry = DebugLogEntry(
      timestamp: DateTime.now().millisecondsSinceEpoch,
      location: location,
      message: message,
      data: data,
      hypothesisId: hypothesisId,
      runId: runId,
    );
    _buffer.addLast(entry);
    while (_buffer.length > _maxEntries) {
      _buffer.removeFirst();
    }
    _controller.add(snapshot);
    debugPrint('GAAYANA_DBG ${entry.toShortLine()}');
  }
}

/// Wrap the app root in this to get a floating, draggable-to-dismiss HUD
/// that shows the most recent debug events.
class DebugHudOverlay extends StatefulWidget {
  const DebugHudOverlay({required this.child, super.key});
  final Widget child;

  @override
  State<DebugHudOverlay> createState() => _DebugHudOverlayState();
}

class _DebugHudOverlayState extends State<DebugHudOverlay> {
  List<DebugLogEntry> _entries = DebugLog.snapshot;
  bool _expanded = true;
  StreamSubscription<List<DebugLogEntry>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = DebugLog.stream.listen((e) => setState(() => _entries = e));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          widget.child,
          Positioned(
            top: MediaQuery.of(context).padding.top + 4,
            left: 8,
            right: 8,
            child: SafeArea(
              child: Material(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  onLongPress: () => setState(() {
                    DebugLog._buffer.clear();
                    _entries = const [];
                  }),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.bug_report,
                                color: Colors.orangeAccent, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'DEBUG HUD (${_entries.length}) — tap to '
                              '${_expanded ? "collapse" : "expand"}, '
                              'long-press to clear',
                              style: const TextStyle(
                                  color: Colors.orangeAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        if (_expanded)
                          ConstrainedBox(
                            constraints: BoxConstraints(
                                maxHeight:
                                    MediaQuery.of(context).size.height * 0.45),
                            child: SingleChildScrollView(
                              reverse: true,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: _entries
                                    .map((e) => Text(
                                          e.toShortLine(),
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontFamily: 'monospace',
                                              height: 1.2),
                                        ))
                                    .toList(),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
// #endregion
