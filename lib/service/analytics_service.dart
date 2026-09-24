import 'dart:async';

import 'package:get/get.dart';

import 'fake_api_service.dart';
import '../util/log_service.dart';

class AnalyticsEvent {
  final String name;
  final Map<String, dynamic> properties;
  final DateTime at;

  AnalyticsEvent(this.name, this.properties) : at = DateTime.now();

  Map<String, dynamic> toJson() => {
        'name': name,
        'properties': properties,
        'at': at.toIso8601String(),
      };
}

/// In-memory analytics sink and batching service.
/// Events are visible on the debug screen (overflow menu on Home -> "Analytics debug")
/// and delivered in batches via [FakeApiService.sendAnalyticsBatch].
class AnalyticsService extends GetxService {
  final events = <AnalyticsEvent>[].obs;

  /// Track impressioned deal IDs to ensure at most once per deal per app session across screens.
  final Set<int> _impressionedDealIds = {};

  /// Pending batch buffer for outgoing analytics events.
  final List<AnalyticsEvent> _pendingBatch = [];
  Timer? _batchTimer;

  bool hasImpression(int dealId) => _impressionedDealIds.contains(dealId);

  /// Logs a deal_impression event if the deal has not been impressioned in this session.
  /// Returns true if the impression was recorded, false if already tracked.
  bool trackImpression({
    required int dealId,
    required String source,
    required int position,
  }) {
    if (_impressionedDealIds.contains(dealId)) {
      return false;
    }
    _impressionedDealIds.add(dealId);
    logEvent('deal_impression', {
      'deal_id': dealId,
      'source': source,
      'position': position,
    });
    return true;
  }

  void logEvent(String name, [Map<String, dynamic> properties = const {}]) {
    final event = AnalyticsEvent(name, properties);
    events.add(event);
    LogService.log('analytics: $name $properties');

    _queueForBatch(event);
  }

  void _queueForBatch(AnalyticsEvent event) {
    _pendingBatch.add(event);

    // If this is the first unsent event, start the 15-second timer
    if (_pendingBatch.length == 1) {
      _batchTimer = Timer(const Duration(seconds: 15), () {
        _flushBatch();
      });
    }

    // Deliver immediately when 10 events accumulate
    if (_pendingBatch.length >= 10) {
      _flushBatch();
    }
  }

  void _flushBatch() {
    _batchTimer?.cancel();
    _batchTimer = null;

    if (_pendingBatch.isEmpty) return;

    final batchToSend = List<AnalyticsEvent>.from(_pendingBatch);
    _pendingBatch.clear();

    final payload = batchToSend.map((e) => e.toJson()).toList();
    LogService.log(
        'AnalyticsService: flushing batch of ${payload.length} events');

    try {
      if (Get.isRegistered<FakeApiService>()) {
        Get.find<FakeApiService>().sendAnalyticsBatch(payload);
      }
    } catch (e) {
      LogService.log('Failed to send analytics batch: $e');
    }
  }

  @override
  void onClose() {
    _flushBatch();
    super.onClose();
  }
}
