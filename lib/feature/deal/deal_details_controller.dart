import 'package:get/get.dart';

import '../../model/deal_model.dart';
import '../../repository/deal_repo.dart';
import '../../service/analytics_service.dart';
import '../../service/cart_service.dart';
import '../../util/log_service.dart';

class DealDetailsController extends GetxController {
  final DealRepo dealRepo;
  final CartService cartService;
  final AnalyticsService analytics;

  DealDetailsController({
    required this.dealRepo,
    required this.cartService,
    required this.analytics,
  });

  final _deal = Rxn<DealModel>();

  DealModel? get deal => _deal.value;

  final isLoading = false.obs;
  final errorMessage = RxnString();

  Worker? _cartWorker;

  final _quantityLeft = RxnInt();

  int? get quantityLeft => _quantityLeft.value;

  @override
  void onInit() {
    super.onInit();

    if (Get.arguments is DealModel) {
      _deal.value = Get.arguments as DealModel;
      _quantityLeft.value = _deal.value!.quantityLeft;
      _logViewEvent(_deal.value!.id);
      _setupCartWorker();
    } else {
      final idStr = Get.parameters['id'] ??
          (Get.arguments is int || Get.arguments is String
              ? Get.arguments.toString()
              : null);
      final dealId = int.tryParse(idStr ?? '');
      if (dealId != null) {
        _loadDeal(dealId);
      } else {
        errorMessage.value = 'Invalid deal link';
      }
    }
  }

  Future<void> _loadDeal(int id) async {
    try {
      isLoading.value = true;
      errorMessage.value = null;
      final fetched = await dealRepo.fetchById(id);
      _deal.value = fetched;
      _quantityLeft.value = fetched.quantityLeft;
      _logViewEvent(fetched.id);
      _setupCartWorker();
    } catch (e) {
      LogService.log('Error loading deal by id $id: $e');
      errorMessage.value = 'Failed to load deal details';
    } finally {
      isLoading.value = false;
    }
  }

  void retryLoad() {
    final idStr = Get.parameters['id'] ??
        (Get.arguments is int || Get.arguments is String
            ? Get.arguments.toString()
            : null);
    final dealId = int.tryParse(idStr ?? '');
    if (dealId != null) {
      _loadDeal(dealId);
    }
  }

  void _logViewEvent(int dealId) {
    analytics.logEvent('deal_details_view', {
      'deal_id': dealId,
      'source': Get.parameters['source'] ?? 'unknown',
    });
  }

  void _setupCartWorker() {
    _cartWorker?.dispose();
    _cartWorker = ever(cartService.itemCount, (_) => _recheckAvailability());
  }

  @override
  void onClose() {
    _cartWorker?.dispose();
    super.onClose();
  }

  Future<void> _recheckAvailability() async {
    final currentDeal = _deal.value;
    if (currentDeal == null) return;
    LogService.log('re-checking availability for deal ${currentDeal.id}');
    try {
      final fresh = await dealRepo.fetchById(currentDeal.id);
      _quantityLeft.value = fresh.quantityLeft;
    } catch (e) {
      LogService.log(
          'Failed to recheck availability for deal ${currentDeal.id}: $e');
    }
  }

  void addToCart() {
    final currentDeal = _deal.value;
    if (currentDeal == null) return;
    if (currentDeal.isFlashSale && currentDeal.isExpired) {
      Get.snackbar(
        'Deal expired',
        'This flash sale has ended and can no longer be added to your bag.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    cartService.add(currentDeal);
    Get.snackbar(
      'Added to bag',
      '${currentDeal.name} — pick up ${currentDeal.pickupWindow.label}',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }
}
