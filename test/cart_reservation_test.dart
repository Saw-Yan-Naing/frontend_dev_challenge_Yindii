import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:rescu/feature/cart/cart_controller.dart';
import 'package:rescu/model/deal_model.dart';
import 'package:rescu/model/order_model.dart';
import 'package:rescu/model/reservation_model.dart';
import 'package:rescu/repository/order_repo.dart';
import 'package:rescu/service/api_exception.dart';
import 'package:rescu/service/cart_service.dart';
import 'package:rescu/service/fake_api_service.dart';

class MockFakeApiService extends FakeApiService {}

class TestOrderRepo extends OrderRepo {
  TestOrderRepo() : super(api: Get.find());

  bool shouldFailReserve = false;
  bool shouldFailCheckoutWith410 = false;
  final List<String> releasedReservationIds = [];
  final List<Map<String, dynamic>> checkoutCallItems = [];

  @override
  Future<ReservationModel> reserve(int dealId, {int quantity = 1}) async {
    if (shouldFailReserve) {
      throw const ApiException(
        'Could not reserve: someone grabbed the last one.',
        statusCode: 409,
      );
    }
    return ReservationModel(
      id: 'res_test_${DateTime.now().millisecondsSinceEpoch}',
      dealId: dealId,
      quantity: quantity,
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
    );
  }

  @override
  Future<void> releaseReservation(String reservationId) async {
    releasedReservationIds.add(reservationId);
  }

  @override
  Future<OrderModel> checkout(items) async {
    if (shouldFailCheckoutWith410) {
      throw const ApiException(
        'Reservation expired — stock was released',
        statusCode: 410,
      );
    }
    checkoutCallItems.clear();
    for (final item in items) {
      checkoutCallItems.add({
        'dealId': item.deal.id,
        'quantity': item.quantity,
        'reservationId': item.reservation?.id,
      });
    }
    return OrderModel(
      id: 9999,
      dealId: items.isNotEmpty ? items.first.deal.id : 0,
      dealName: 'Test Order',
      storeName: 'Test Store',
      imageUrl: 'http://example.com/img.jpg',
      status: 'CONFIRMED',
      quantity: items.fold<int>(0, (a, b) => a + b.quantity),
      total: items.fold<num>(0, (a, b) => a + b.lineTotal),
      currencyCode: 'THB',
      pickupStart: DateTime.now().toUtc(),
      pickupEnd: DateTime.now().toUtc().add(const Duration(hours: 2)),
    );
  }
}

DealModel _createTestDeal({int id = 1, int quantityLeft = 5}) {
  return DealModel.fromJson({
    'id': id,
    'name': 'Test Bag $id',
    'description': 'Desc',
    'imageUrl': 'https://example.com/img.jpg',
    'originalPrice': 100,
    'price': 50,
    'currencyCode': 'THB',
    'quantityLeft': quantityLeft,
    'storeId': 1,
    'storeName': 'Test Bakery',
    'storeAddress': '123 Test St',
    'lat': 13.0,
    'lng': 100.0,
    'rating': 4.5,
    'tags': [],
    'pickupWindow': {
      'start': '2026-01-01T10:00:00.000Z',
      'end': '2026-01-01T14:00:00.000Z',
    },
    'flashSaleEndsAt': null,
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CartService cartService;
  late TestOrderRepo mockOrderRepo;

  setUp(() {
    Get.reset();
    Get.put<FakeApiService>(MockFakeApiService());
    mockOrderRepo = TestOrderRepo();
    Get.put<OrderRepo>(mockOrderRepo);
    cartService = Get.put(CartService());
  });

  tearDown(() {
    Get.reset();
  });

  group('Cart Reservation Support (F-3)', () {
    test(
        'Optimistic Add: Item added immediately and reservation reconciles on success',
        () async {
      final deal = _createTestDeal(id: 101);

      cartService.add(deal);

      expect(cartService.items.length, 1);
      expect(cartService.items.first.isReserving, isTrue);

      await Future.delayed(const Duration(milliseconds: 50));

      expect(cartService.items.first.isReserving, isFalse);
      expect(cartService.items.first.reservation, isNotNull);
      expect(cartService.items.first.reservation!.dealId, 101);
    });

    test(
        'Optimistic Add Rollback: Item removed from bag when reservation fails (409)',
        () async {
      mockOrderRepo.shouldFailReserve = true;
      final deal = _createTestDeal(id: 102);

      cartService.add(deal);

      expect(cartService.items.length, 1);

      await Future.delayed(const Duration(milliseconds: 50));

      expect(cartService.items.length, 0);
    });

    test('Removing item releases reservation hold on backend', () async {
      final deal = _createTestDeal(id: 103);
      cartService.add(deal);
      await Future.delayed(const Duration(milliseconds: 50));

      final resId = cartService.items.first.reservation!.id;
      expect(resId, isNotEmpty);

      cartService.remove(103);

      expect(cartService.items.length, 0);
      expect(mockOrderRepo.releasedReservationIds.contains(resId), isTrue);
    });

    test('Checkout passes reservation ID and handles 410 rejection gracefully',
        () async {
      final deal = _createTestDeal(id: 104);
      cartService.add(deal);
      await Future.delayed(const Duration(milliseconds: 50));

      final controller = CartController(
        cartService: cartService,
        orderRepo: mockOrderRepo,
      );

      await controller.checkout();
      expect(mockOrderRepo.checkoutCallItems.length, 1);
      expect(mockOrderRepo.checkoutCallItems.first['reservationId'], isNotNull);
      expect(cartService.items.isEmpty, isTrue);

      cartService.add(deal);
      await Future.delayed(const Duration(milliseconds: 50));
      mockOrderRepo.shouldFailCheckoutWith410 = true;

      await controller.checkout();
      expect(controller.isCheckingOut.value, isFalse);
    });
  });
}
