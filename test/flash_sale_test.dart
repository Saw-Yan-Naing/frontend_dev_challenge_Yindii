import 'package:flutter_test/flutter_test.dart';
import 'package:rescu/feature/shared_widget/flash_countdown_badge.dart';
import 'package:rescu/model/deal_model.dart';
import 'package:rescu/service/cart_service.dart';
import 'package:rescu/util/central_ticker.dart';

void main() {
  group('Flash Sale Countdown Formatting', () {
    test('Formats countdown correctly for duration > 1 hour', () {
      const duration = Duration(hours: 1, minutes: 15, seconds: 30);
      expect(formatFlashCountdown(duration), '01:15:30');
    });

    test('Formats countdown correctly for duration < 1 hour', () {
      const duration = Duration(minutes: 5, seconds: 23);
      expect(formatFlashCountdown(duration), '05:23');
    });

    test('Formats countdown correctly for 0 or negative duration', () {
      expect(formatFlashCountdown(Duration.zero), '00:00');
      expect(formatFlashCountdown(const Duration(seconds: -10)), '00:00');
    });
  });

  group('DealModel Flash Sale Expiration', () {
    test('Detects active vs expired flash deals', () {
      final now = DateTime.now();
      final futureDeal = DealModel.fromJson({
        'id': 101,
        'name': 'Future Flash Deal',
        'description': 'Desc',
        'imageUrl': 'https://example.com/img.jpg',
        'originalPrice': 100,
        'price': 50,
        'currencyCode': 'THB',
        'quantityLeft': 5,
        'storeId': 1,
        'storeName': 'Test Store',
        'storeAddress': 'Address',
        'lat': 13.0,
        'lng': 100.0,
        'rating': 4.5,
        'tags': [],
        'pickupWindow': {
          'start': '2026-01-01T10:00:00.000Z',
          'end': '2026-01-01T14:00:00.000Z',
        },
        'flashSaleEndsAt':
            now.add(const Duration(minutes: 10)).toIso8601String(),
      });

      final pastDeal = DealModel.fromJson({
        'id': 102,
        'name': 'Past Flash Deal',
        'description': 'Desc',
        'imageUrl': 'https://example.com/img.jpg',
        'originalPrice': 100,
        'price': 50,
        'currencyCode': 'THB',
        'quantityLeft': 5,
        'storeId': 1,
        'storeName': 'Test Store',
        'storeAddress': 'Address',
        'lat': 13.0,
        'lng': 100.0,
        'rating': 4.5,
        'tags': [],
        'pickupWindow': {
          'start': '2026-01-01T10:00:00.000Z',
          'end': '2026-01-01T14:00:00.000Z',
        },
        'flashSaleEndsAt':
            now.subtract(const Duration(seconds: 5)).toIso8601String(),
      });

      expect(futureDeal.isFlashSale, isTrue);
      expect(futureDeal.isExpiredAt(now), isFalse);

      expect(pastDeal.isFlashSale, isTrue);
      expect(pastDeal.isExpiredAt(now), isTrue);
    });
  });

  group('CentralTicker Lifecycle', () {
    test('Starts and stops timer according to listener count', () {
      final ticker = CentralTickerNotifier();
      void listener1() {}
      void listener2() {}

      expect(ticker.hasListeners, isFalse);

      ticker.addListener(listener1);
      expect(ticker.hasListeners, isTrue);

      ticker.addListener(listener2);
      expect(ticker.hasListeners, isTrue);

      ticker.removeListener(listener1);
      expect(ticker.hasListeners, isTrue);

      ticker.removeListener(listener2);
      expect(ticker.hasListeners, isFalse);
    });
  });

  group('CartService Flash Sale Integration', () {
    test('Rejects adding expired flash deal to cart', () {
      TestWidgetsFlutterBinding.ensureInitialized();
      final cartService = CartService();
      cartService.onInit();

      final now = DateTime.now();
      final expiredDeal = DealModel.fromJson({
        'id': 201,
        'name': 'Expired Deal',
        'description': 'Desc',
        'imageUrl': 'https://example.com/img.jpg',
        'originalPrice': 100,
        'price': 50,
        'currencyCode': 'THB',
        'quantityLeft': 5,
        'storeId': 1,
        'storeName': 'Test Store',
        'storeAddress': 'Address',
        'lat': 13.0,
        'lng': 100.0,
        'rating': 4.5,
        'tags': [],
        'pickupWindow': {
          'start': '2026-01-01T10:00:00.000Z',
          'end': '2026-01-01T14:00:00.000Z',
        },
        'flashSaleEndsAt':
            now.subtract(const Duration(seconds: 10)).toIso8601String(),
      });

      cartService.add(expiredDeal);
      expect(cartService.items.length, 0);
      cartService.onClose();
    });
  });
}
