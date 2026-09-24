import 'package:flutter/material.dart';

import '../../util/central_ticker.dart';

/// Formats a remaining duration as `hh:mm:ss` if hours > 0, otherwise `mm:ss`.
/// Returns `'00:00'` if duration is 0 or negative.
String formatFlashCountdown(Duration remaining) {
  if (remaining.isNegative || remaining.inSeconds <= 0) {
    return '00:00';
  }
  final hours = remaining.inHours;
  final minutes = remaining.inMinutes.remainder(60);
  final seconds = remaining.inSeconds.remainder(60);

  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  } else {
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Compact badge widget for live flash sale countdowns.
/// Used in [DealCard] and [FlashDealsSection].
class FlashCountdownBadge extends StatelessWidget {
  final DateTime flashSaleEndsAt;
  final bool isLight;

  const FlashCountdownBadge({
    super.key,
    required this.flashSaleEndsAt,
    this.isLight = false,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTime>(
      valueListenable: CentralTicker.instance.nowNotifier,
      builder: (context, now, _) {
        final remaining = flashSaleEndsAt.difference(now);
        final isExpired = remaining.isNegative || remaining.inSeconds <= 0;
        final formattedText = formatFlashCountdown(remaining);

        if (isLight) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isExpired ? Colors.grey.shade200 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isExpired ? 'Expired' : formattedText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isExpired ? Colors.grey.shade700 : Colors.red.shade700,
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isExpired ? Colors.grey.shade700 : Colors.red.shade600,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isExpired) ...[
                const Icon(Icons.bolt, color: Colors.white, size: 12),
                const SizedBox(width: 2),
              ],
              Text(
                isExpired ? 'EXPIRED' : formattedText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Banner card used in [DealDetailsScreen] for flash deals.
class FlashCountdownBanner extends StatelessWidget {
  final DateTime flashSaleEndsAt;

  const FlashCountdownBanner({
    super.key,
    required this.flashSaleEndsAt,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTime>(
      valueListenable: CentralTicker.instance.nowNotifier,
      builder: (context, now, _) {
        final remaining = flashSaleEndsAt.difference(now);
        final isExpired = remaining.isNegative || remaining.inSeconds <= 0;
        final formattedText = formatFlashCountdown(remaining);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isExpired ? Colors.grey.shade100 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isExpired ? Colors.grey.shade300 : Colors.red.shade200,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.bolt,
                color: isExpired ? Colors.grey.shade600 : Colors.red.shade700,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isExpired ? 'Flash sale ended' : 'Flash sale ends in',
                    style: TextStyle(
                      fontSize: 12,
                      color: isExpired
                          ? Colors.grey.shade600
                          : Colors.red.shade900,
                    ),
                  ),
                  Text(
                    isExpired ? 'Expired' : formattedText,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isExpired
                          ? Colors.grey.shade700
                          : Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
