import 'package:get/get.dart';

import '../model/cart_item_model.dart';
import '../model/deal_model.dart';
import '../util/central_ticker.dart';
import '../util/log_service.dart';

/// App-wide cart. Lives for the whole session.
class CartService extends GetxService {
  final items = <CartItemModel>[].obs;
  final itemCount = 0.obs;

  @override
  void onInit() {
    super.onInit();
    CentralTicker.instance.nowNotifier.addListener(_checkExpiredFlashDeals);
  }

  @override
  void onClose() {
    CentralTicker.instance.nowNotifier.removeListener(_checkExpiredFlashDeals);
    super.onClose();
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
      Get.snackbar(
        'Item expired',
        '${expired.deal.name} was removed from your bag because the flash sale ended.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
    }
    _recount();
  }

  void add(DealModel deal) {
    if (deal.isFlashSale && deal.isExpired) {
      LogService.log('cart: cannot add expired deal ${deal.id}');
      return;
    }

    final existing = items.firstWhereOrNull((i) => i.deal.id == deal.id);
    if (existing != null) {
      if (existing.quantity >= deal.quantityLeft) {
        LogService.log('cart: cannot add more of deal ${deal.id}');
        return;
      }
      existing.quantity++;
      items.refresh();
    } else {
      items.add(CartItemModel(deal: deal));
    }
    _recount();
  }

  void decrement(int dealId) {
    final existing = items.firstWhereOrNull((i) => i.deal.id == dealId);
    if (existing == null) return;
    existing.quantity--;
    if (existing.quantity <= 0) {
      items.removeWhere((i) => i.deal.id == dealId);
    } else {
      items.refresh();
    }
    _recount();
  }

  void remove(int dealId) {
    items.removeWhere((i) => i.deal.id == dealId);
    _recount();
  }

  void clear() {
    items.clear();
    _recount();
  }

  num get total => items.fold(0, (sum, i) => sum + i.lineTotal);

  void _recount() {
    itemCount.value = items.fold(0, (sum, i) => sum + i.quantity);
  }
}
