import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../shared_widget/deal_card.dart';
import '../home_controller.dart';

class HomeDealsSliver extends StatelessWidget {
  final HomeController controller;

  const HomeDealsSliver({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final deals = controller.visibleDeals;
      return SliverList.builder(
        itemCount: deals.length,
        itemBuilder: (context, index) {
          final deal = deals[index];
          return DealCard(
            deal: deal,
            key: ValueKey(deal.id),
          );
        },
      );
    });
  }
}
