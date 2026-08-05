import 'package:flutter/foundation.dart';

/// A log entry captured by the debug logger.
class DebugLogEntry {
  final DateTime timestamp;
  final String level; // INFO, ERROR, HTTP
  final String source;
  final String message;
  final String? detail;

  DebugLogEntry({
    required this.level,
    required this.source,
    required this.message,
    this.detail,
  }) : timestamp = DateTime.now();

  @override
  String toString() {
    final ts =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
    final base = '[$ts] [$level] $source: $message';
    if (detail != null) return '$base\n$detail';
    return base;
  }
}

/// Singleton debug logger that captures log entries in-memory.
/// When disabled, all calls are no-ops.
class DebugLogger extends ChangeNotifier {
  static final DebugLogger _instance = DebugLogger._internal();
  factory DebugLogger() => _instance;
  DebugLogger._internal();

  bool _enabled = false;
  bool get enabled => _enabled;

  final List<DebugLogEntry> _entries = [];
  List<DebugLogEntry> get entries => List.unmodifiable(_entries);

  /// Max entries to keep in memory.
  static const int maxEntries = 500;

  void setEnabled(bool value) {
    _enabled = value;
    if (!value) {
      _entries.clear();
    }
    notifyListeners();
  }

  void info(String source, String message, {String? detail}) {
    _add('INFO', source, message, detail: detail);
  }

  void error(String source, String message, {String? detail}) {
    _add('ERROR', source, message, detail: detail);
  }

  void http(String source, String message, {String? detail}) {
    _add('HTTP', source, message, detail: detail);
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }

  void _add(String level, String source, String message, {String? detail}) {
    if (!_enabled) return;
    if (_entries.length >= maxEntries) {
      _entries.removeAt(0);
    }
    _entries.add(DebugLogEntry(
      level: level,
      source: source,
      message: message,
      detail: detail,
    ));
    notifyListeners();
  }
}
