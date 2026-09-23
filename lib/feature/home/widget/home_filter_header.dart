import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../home_controller.dart';

class HomeFilterHeader extends StatelessWidget {
  final HomeController controller;

  const HomeFilterHeader({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(
          children: [
            const Text(
              'Nearby deals',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Obx(
              () => FilterChip(
                label: const Text('Pickup today'),
                selected: controller.todayOnly.value,
                onSelected: (v) => controller.todayOnly.value = v,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
