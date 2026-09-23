import 'package:flutter/material.dart';

import '../../shared_widget/shimmer_deal_card.dart';

class HomeLoadingSliver extends StatelessWidget {
  final int itemCount;

  const HomeLoadingSliver({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    return SliverList.builder(
      itemCount: itemCount,
      itemBuilder: (context, index) => const ShimmerDealCard(),
    );
  }
}
