import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app_config.dart';
import '../../model/cart_item_model.dart';
import '../../util/central_ticker.dart';
import '../shared_widget/flash_countdown_badge.dart';
import '../shared_widget/the_network_image.dart';
import 'cart_controller.dart';

class CartScreen extends GetView<CartController> {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = controller.cartService;
    return Scaffold(
      appBar: AppBar(title: const Text('My bag')),
      body: Obx(() {
        if (cart.items.isEmpty) {
          return const Center(child: Text('Your bag is empty'));
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: cart.items.length,
          itemBuilder: (context, index) {
            final item = cart.items[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: Colors.white,
              elevation: 0.5,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    TheNetworkImage(
                      url: item.deal.imageUrl,
                      width: 64,
                      height: 64,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.deal.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14.5, fontWeight: FontWeight.w600)),
                          Text(item.deal.storeName,
                              style: TextStyle(
                                  fontSize: 12.5, color: Colors.grey.shade600)),
                          Text('฿${item.deal.price.toStringAsFixed(0)} each',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppConfig.primaryGreen,
                                  fontWeight: FontWeight.w600)),
                          _CartReservationBadge(item: item),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => cart.decrement(item.deal.id),
                        ),
                        Text('${item.quantity}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => cart.add(item.deal),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
      bottomNavigationBar: Obx(() {
        if (cart.items.isEmpty) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          color: Colors.white,
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Total', style: TextStyle(fontSize: 13)),
                  Text('฿${cart.total.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(width: 24),
              Expanded(
                child: FilledButton(
                  onPressed: controller.isCheckingOut.value
                      ? null
                      : controller.checkout,
                  child: controller.isCheckingOut.value
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Checkout'),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _CartReservationBadge extends StatelessWidget {
  final CartItemModel item;

  const _CartReservationBadge({required this.item});

  @override
  Widget build(BuildContext context) {
    if (item.isReserving) {
      return const Padding(
        padding: EdgeInsets.only(top: 4),
        child: Row(
          children: [
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            ),
            SizedBox(width: 6),
            Text(
              'Reserving hold...',
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    final res = item.reservation;
    if (res == null) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<DateTime>(
      valueListenable: CentralTicker.instance.nowNotifier,
      builder: (context, now, _) {
        final remaining = res.expiresAt.difference(now.toUtc());
        final isExpired = remaining.isNegative || remaining.inSeconds <= 0;
        final formattedText = formatFlashCountdown(remaining);

        if (isExpired) {
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(Icons.timer_off_outlined,
                    size: 13, color: Colors.red.shade700),
                const SizedBox(width: 4),
                Text(
                  'Hold expired',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              const Icon(Icons.timer_outlined,
                  size: 13, color: AppConfig.primaryGreen),
              const SizedBox(width: 4),
              Text(
                'Reserved: $formattedText',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppConfig.primaryGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
