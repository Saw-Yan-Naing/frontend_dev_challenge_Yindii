import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../service/analytics_service.dart';

/// Wraps a widget (such as a deal card) and logs a `deal_impression` event
/// when the widget has been ≥50% visible for at least 1 continuous second.
///
/// If the deal has already been impressioned in the current session,
/// [VisibilityDetector] is bypassed entirely to preserve smooth scrolling performance.
class DealImpressionDetector extends StatefulWidget {
  final int dealId;
  final String source;
  final int position;
  final Widget child;

  const DealImpressionDetector({
    super.key,
    required this.dealId,
    required this.source,
    required this.position,
    required this.child,
  });

  @override
  State<DealImpressionDetector> createState() => _DealImpressionDetectorState();
}

class _DealImpressionDetectorState extends State<DealImpressionDetector> {
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (!Get.isRegistered<AnalyticsService>()) return;
    final analytics = Get.find<AnalyticsService>();

    if (analytics.hasImpression(widget.dealId)) {
      _timer?.cancel();
      _timer = null;
      return;
    }

    if (info.visibleFraction >= 0.5) {
      _timer ??= Timer(const Duration(seconds: 1), () {
        final logged = analytics.trackImpression(
          dealId: widget.dealId,
          source: widget.source,
          position: widget.position,
        );
        _timer = null;
        if (logged && mounted) {
          setState(() {}); // Rebuild once so VisibilityDetector is detached
        }
      });
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (Get.isRegistered<AnalyticsService>()) {
      final analytics = Get.find<AnalyticsService>();
      if (analytics.hasImpression(widget.dealId)) {
        return widget.child;
      }
    }

    return VisibilityDetector(
      key: Key(
          'impression-${widget.source}-${widget.dealId}-${widget.position}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: widget.child,
    );
  }
}
