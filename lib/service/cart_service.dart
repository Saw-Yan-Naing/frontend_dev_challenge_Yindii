import 'package:get/get.dart';

import '../model/cart_item_model.dart';
import '../model/deal_model.dart';
import '../repository/order_repo.dart';
import '../util/central_ticker.dart';
import '../util/log_service.dart';

/// App-wide cart. Lives for the whole session.
class CartService extends GetxService {
  final items = <CartItemModel>[].obs;
  final itemCount = 0.obs;

  final Map<int, int> _reservationTokens = {};

  @override
  void onInit() {
    super.onInit();
    CentralTicker.instance.nowNotifier.addListener(_onTickerTick);
  }

  @override
  void onClose() {
    CentralTicker.instance.nowNotifier.removeListener(_onTickerTick);
    super.onClose();
  }

  void _onTickerTick() {
    _checkExpiredFlashDeals();
    _checkExpiredReservations();
  }

  void _showSnackBar(String title, String message, {Duration? duration}) {
    if (Get.context != null && Get.overlayContext != null) {
      Get.snackbar(
        title,
        message,
        snackPosition: SnackPosition.BOTTOM,
        duration: duration ?? const Duration(seconds: 3),
      );
    }
  }

  void _checkExpiredFlashDeals() {
    if (items.isEmpty) return;
    final now = DateTime.now();
    final expiredItems = items
        .where((i) => i.deal.isFlashSale && i.deal.isExpiredAt(now))
        .toList();

    if (expiredItems.isEmpty) return;

    for (final expired in expiredItems) {
      items.remove(expired);
      _showSnackBar(
        'Item expired',
        '${expired.deal.name} was removed from your bag because the flash sale ended.',
        duration: const Duration(seconds: 4),
      );
    }
    _recount();
  }

  void _checkExpiredReservations() {
    if (items.isEmpty) return;
    final expiredItems = items
        .where((i) =>
            i.reservation != null && i.isReservationExpired && !i.isReserving)
        .toList();

    if (expiredItems.isEmpty) return;

    for (final expired in expiredItems) {
      _reReserveExpiredItem(expired);
    }
  }

  Future<void> refreshExpiredReservations() async {
    final expiredItems = items
        .where((i) =>
            i.isReservationExpired || (i.reservation == null && !i.isReserving))
        .toList();

    for (final expired in expiredItems) {
      await _reReserveExpiredItem(expired);
    }
  }

  Future<void> _reReserveExpiredItem(CartItemModel item) async {
    item.isReserving = true;
    items.refresh();

    try {
      final orderRepo = Get.find<OrderRepo>();
      final newRes =
          await orderRepo.reserve(item.deal.id, quantity: item.quantity);
      if (items.contains(item)) {
        item.reservation = newRes;
        item.isReserving = false;
        items.refresh();
        _showSnackBar(
          'Hold extended',
          'Stock hold for ${item.deal.name} was automatically extended.',
          duration: const Duration(seconds: 3),
        );
      } else {
        orderRepo.releaseReservation(newRes.id).catchError((_) {});
      }
    } catch (e) {
      LogService.log('Failed to re-reserve expired item ${item.deal.id}: $e');
      if (items.contains(item)) {
        items.remove(item);
        _recount();
        _showSnackBar(
          'Reservation expired',
          'Reservation for ${item.deal.name} expired and stock was claimed by another customer.',
          duration: const Duration(seconds: 4),
        );
      }
    }
  }

  void add(DealModel deal) {
    if (deal.isFlashSale && deal.isExpired) {
      LogService.log('cart: cannot add expired deal ${deal.id}');
      return;
    }

    final existing = items.firstWhereOrNull((i) => i.deal.id == deal.id);
    final int oldQuantity;
    final int targetQuantity;

    if (existing != null) {
      if (existing.quantity >= deal.quantityLeft) {
        LogService.log('cart: cannot add more of deal ${deal.id}');
        return;
      }
      oldQuantity = existing.quantity;
      existing.quantity++;
      targetQuantity = existing.quantity;
      existing.isReserving = true;
      items.refresh();
    } else {
      oldQuantity = 0;
      targetQuantity = 1;
      final newItem = CartItemModel(deal: deal, quantity: 1, isReserving: true);
      items.add(newItem);
    }
    _recount();

    _syncReservation(deal,
        targetQuantity: targetQuantity, oldQuantity: oldQuantity);
  }

  void decrement(int dealId) {
    final existing = items.firstWhereOrNull((i) => i.deal.id == dealId);
    if (existing == null) return;

    if (existing.quantity - 1 <= 0) {
      remove(dealId);
      return;
    }

    final oldQuantity = existing.quantity;
    existing.quantity--;
    final targetQuantity = existing.quantity;
    existing.isReserving = true;
    items.refresh();
    _recount();

    _syncReservation(existing.deal,
        targetQuantity: targetQuantity, oldQuantity: oldQuantity);
  }

  void remove(int dealId) {
    _reservationTokens[dealId] = (_reservationTokens[dealId] ?? 0) + 1;
    final existing = items.firstWhereOrNull((i) => i.deal.id == dealId);
    if (existing != null) {
      if (existing.reservation != null) {
        Get.find<OrderRepo>()
            .releaseReservation(existing.reservation!.id)
            .catchError((e) {
          LogService.log('Failed releasing reservation on remove: $e');
        });
      }
      items.removeWhere((i) => i.deal.id == dealId);
      _recount();
    }
  }

  void clear() {
    _reservationTokens.clear();
    for (final item in items) {
      if (item.reservation != null) {
        Get.find<OrderRepo>()
            .releaseReservation(item.reservation!.id)
            .catchError((e) {
          LogService.log('Failed releasing reservation on clear: $e');
        });
      }
    }
    items.clear();
    _recount();
  }

  Future<void> _syncReservation(
    DealModel deal, {
    required int targetQuantity,
    required int oldQuantity,
  }) async {
    final dealId = deal.id;
    final token = (_reservationTokens[dealId] ?? 0) + 1;
    _reservationTokens[dealId] = token;

    final oldRes =
        items.firstWhereOrNull((i) => i.deal.id == dealId)?.reservation;

    try {
      final orderRepo = Get.find<OrderRepo>();
      final newRes = await orderRepo.reserve(dealId, quantity: targetQuantity);

      final currentItem = items.firstWhereOrNull((i) => i.deal.id == dealId);
      if (_reservationTokens[dealId] == token &&
          currentItem != null &&
          currentItem.quantity == targetQuantity) {
        currentItem.reservation = newRes;
        currentItem.isReserving = false;
        items.refresh();

        if (oldRes != null && oldRes.id != newRes.id) {
          orderRepo.releaseReservation(oldRes.id).catchError((e) {
            LogService.log('Failed releasing old reservation ${oldRes.id}: $e');
          });
        }
      } else {
        orderRepo.releaseReservation(newRes.id).catchError((e) {
          LogService.log(
              'Failed releasing superseded reservation ${newRes.id}: $e');
        });
      }
    } catch (e) {
      LogService.log(
          'Reservation failed for deal $dealId (target $targetQuantity): $e');

      if (_reservationTokens[dealId] == token) {
        final currentItem = items.firstWhereOrNull((i) => i.deal.id == dealId);
        if (currentItem != null) {
          if (oldQuantity <= 0) {
            items.remove(currentItem);
            _recount();
            _showSnackBar(
              'Stock unavailable',
              'Could not reserve ${deal.name}: someone grabbed the last one.',
              duration: const Duration(seconds: 4),
            );
          } else {
            currentItem.quantity = oldQuantity;
            currentItem.isReserving = false;
            items.refresh();
            _recount();
            _showSnackBar(
              'Stock unavailable',
              'Could not reserve additional quantity for ${deal.name}.',
              duration: const Duration(seconds: 4),
            );
          }
        }
      }
    }
  }

  num get total => items.fold(0, (sum, i) => sum + i.lineTotal);

  void _recount() {
    itemCount.value = items.fold(0, (sum, i) => sum + i.quantity);
  }
}
