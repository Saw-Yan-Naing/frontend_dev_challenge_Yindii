import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../../app_config.dart';
import '../../routes/routes.dart';
import 'home_controller.dart';
import 'widget/flash_deals_section.dart';
import 'widget/home_deals_sliver.dart';
import 'widget/home_filter_header.dart';
import 'widget/home_loading_sliver.dart';

class HomeScreen extends GetView<HomeController> {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _HomeAppBar(controller: controller),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const CustomScrollView(
            slivers: [HomeLoadingSliver()],
          );
        }
        return SmartRefresher(
          controller: controller.refreshController,
          enablePullDown: true,
          enablePullUp: true,
          onRefresh: controller.refreshDeals,
          onLoading: controller.loadMore,
          child: CustomScrollView(
            controller: controller.scrollController,
            slivers: [
              Obx(() {
                if (controller.flashDeals.isEmpty) {
                  return const SliverToBoxAdapter(child: SizedBox.shrink());
                }
                return SliverToBoxAdapter(
                  child: FlashDealsSection(deals: controller.flashDeals),
                );
              }),
              HomeFilterHeader(controller: controller),
              HomeDealsSliver(controller: controller),
              const SliverToBoxAdapter(
                child: SizedBox(height: 24),
              ),
            ],
          ),
        );
      }),
      floatingActionButton: _ScrollToTopFab(controller: controller),
    );
  }
}

class _HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final HomeController controller;

  const _HomeAppBar({required this.controller});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final offset = controller.scrollOffset.value;
      return AppBar(
        elevation: offset > 4 ? 2 : 0,
        shadowColor: Colors.black26,
        title: const Row(
          children: [
            Icon(Icons.eco, color: AppConfig.primaryGreen),
            SizedBox(width: 8),
            Text(
              'Rescu',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Get.toNamed(Routes.search),
          ),
          IconButton(
            icon: const Icon(Icons.map_outlined),
            onPressed: () => Get.toNamed(Routes.map),
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => Get.toNamed(Routes.orders),
          ),
          IconButton(
            icon: const Icon(Icons.shopping_bag_outlined),
            onPressed: () => Get.toNamed(Routes.cart),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'deeplink') _showDeepLinkDialog(context);
              if (value == 'analytics') Get.toNamed(Routes.analyticsDebug);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'deeplink',
                child: Text('Simulate deep link…'),
              ),
              PopupMenuItem(
                value: 'analytics',
                child: Text('Analytics debug'),
              ),
            ],
          ),
        ],
      );
    });
  }

  void _showDeepLinkDialog(BuildContext context) {
    final textController =
        TextEditingController(text: 'rescu://open/deal?id=42&source=push');
    Get.dialog(
      AlertDialog(
        title: const Text('Simulate deep link'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            helperText: 'e.g. rescu://open/deal?id=42&source=push',
          ),
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final uri = Uri.tryParse(textController.text.trim());
              Get.back();
              if (uri == null) return;
              final route =
                  uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
              Get.toNamed(route);
            },
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }
}

class _ScrollToTopFab extends StatelessWidget {
  final HomeController controller;

  const _ScrollToTopFab({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final showFab = controller.scrollOffset.value > 800;
      if (!showFab) return const SizedBox.shrink();
      return FloatingActionButton.small(
        onPressed: controller.scrollToTop,
        child: const Icon(Icons.arrow_upward),
      );
    });
  }
}
