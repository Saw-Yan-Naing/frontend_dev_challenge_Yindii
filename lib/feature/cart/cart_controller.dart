import 'package:get/get.dart';

import '../../repository/order_repo.dart';
import '../../service/api_exception.dart';
import '../../service/cart_service.dart';
import '../../util/log_service.dart';

class CartController extends GetxController {
  final CartService cartService;
  final OrderRepo orderRepo;

  CartController({required this.cartService, required this.orderRepo});

  final isCheckingOut = false.obs;

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

  Future<void> checkout() async {
    if (cartService.items.isEmpty || isCheckingOut.value) return;

    // Check if any items are currently in flight reserving
    final isReservingInFlight = cartService.items.any((i) => i.isReserving);
    if (isReservingInFlight) {
      _showSnackBar(
        'Please wait',
        'Stock reservation is in progress. Please try again in a moment.',
      );
      return;
    }

    // Check if any items have expired reservations before checkout
    final hasExpired = cartService.items.any((i) => i.isReservationExpired);
    if (hasExpired) {
      _showSnackBar(
        'Reservation expired',
        'Updating stock hold for items in your bag...',
      );
      await cartService.refreshExpiredReservations();
      if (cartService.items.isEmpty) return;
    }

    isCheckingOut.value = true;
    try {
      final order = await orderRepo.checkout(cartService.items.toList());
      cartService.clear();
      _showSnackBar(
        'Order confirmed',
        'Order #${order.id} — pick up soon!',
      );
    } on ApiException catch (e) {
      LogService.error('checkout failed', e);
      if (e.statusCode == 410) {
        _showSnackBar(
          'Checkout failed',
          'Your stock reservation expired before payment completed. Refreshing your bag...',
          duration: const Duration(seconds: 4),
        );
        await cartService.refreshExpiredReservations();
      } else {
        _showSnackBar(
          'Checkout failed',
          e.message,
        );
      }
    } finally {
      isCheckingOut.value = false;
    }
  }
}
