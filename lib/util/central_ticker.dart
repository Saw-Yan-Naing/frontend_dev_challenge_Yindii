import 'dart:async';
import 'package:flutter/foundation.dart';

/// Custom ValueNotifier that automatically manages a 1-second periodic Timer.
///
/// Starts the timer when the first listener attaches and cancels it when
/// the last listener detaches. This guarantees zero CPU/battery overhead
/// when no countdown widgets are visible on screen.
class CentralTickerNotifier extends ValueNotifier<DateTime> {
  Timer? _timer;
  int _listenerCount = 0;

  CentralTickerNotifier() : super(DateTime.now());

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _listenerCount++;
    if (_timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        value = DateTime.now();
      });
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    _listenerCount--;
    if (_listenerCount <= 0) {
      _listenerCount = 0;
      _timer?.cancel();
      _timer = null;
    }
  }
}

/// Singleton container for the central countdown ticker.
class CentralTicker {
  CentralTicker._();

  static final CentralTicker instance = CentralTicker._();

  final CentralTickerNotifier nowNotifier = CentralTickerNotifier();
}
