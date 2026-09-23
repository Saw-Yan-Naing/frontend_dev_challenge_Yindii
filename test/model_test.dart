import 'package:flutter_test/flutter_test.dart';
import 'package:rescu/model/deal_model.dart';

void main() {
  test('DealModel parses API json', () {
    final deal = DealModel.fromJson({
      'id': 7,
      'name': 'Surprise Bakery Bag',
      'description': 'Assorted pastries',
      'imageUrl': 'https://example.com/img.jpg',
      'originalPrice': 150,
      'price': 49,
      'currencyCode': 'THB',
      'quantityLeft': 3,
      'storeId': 2,
      'storeName': 'Sunrise Bakehouse',
      'storeAddress': '1 Sukhumvit Soi 1, Bangkok',
      'lat': 13.75,
      'lng': 100.5,
      'rating': null,
      'tags': ['bestseller'],
      'pickupWindow': {
        'start': '2026-01-01T10:30:00.000Z',
        'end': '2026-01-01T14:00:00.000Z',
      },
      'flashSaleEndsAt': null,
    });

    expect(deal.id, 7);
    expect(deal.rating, isNull);
    expect(deal.discountPercent, 67);
    expect(deal.isFlashSale, isFalse);
    expect(deal.pickupWindow.start.isUtc, isFalse);
  });

  test(
      'PickupWindowModel converts UTC to local time and formats label correctly',
      () {
    final now = DateTime.now();
    // Construct an ISO UTC string corresponding to today in local time
    final todayUtcStart =
        DateTime(now.year, now.month, now.day, 10, 0).toUtc().toIso8601String();
    final todayUtcEnd = DateTime(now.year, now.month, now.day, 14, 30)
        .toUtc()
        .toIso8601String();

    final deal = DealModel.fromJson({
      'id': 1,
      'name': 'Test Deal',
      'description': 'Desc',
      'imageUrl': 'https://example.com/img.jpg',
      'originalPrice': 100,
      'price': 50,
      'currencyCode': 'THB',
      'quantityLeft': 5,
      'storeId': 1,
      'storeName': 'Test Bakery',
      'storeAddress': '123 Test St',
      'lat': 13.0,
      'lng': 100.0,
      'rating': 5.0,
      'tags': [],
      'pickupWindow': {
        'start': todayUtcStart,
        'end': todayUtcEnd,
      },
      'flashSaleEndsAt': null,
    });

    expect(deal.pickupWindow.isToday, isTrue);
    expect(deal.pickupWindow.label, '10:00 – 14:30');
  });
}
