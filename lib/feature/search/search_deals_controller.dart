import 'dart:async';

import 'package:get/get.dart';

import '../../model/deal_model.dart';
import '../../repository/deal_repo.dart';
import '../../util/log_service.dart';

class SearchDealsController extends GetxController {
  final DealRepo dealRepo;

  SearchDealsController({required this.dealRepo});

  ///Added for the debounce query for the better query performance for both backend api calls and local database
  Timer? _timer;

  final results = <DealModel>[].obs;
  final isLoading = false.obs;
  final hasSearched = false.obs;

  ///Added debounce for the better api calls to wait for the user input
  void onQueryChanged(String query) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: 300), () => _search(query));
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      results.clear();
      hasSearched.value = false;
      return;
    }
    isLoading.value = true;
    hasSearched.value = true;
    try {
      final found = await dealRepo.search(query);
      results.assignAll(found);
    } catch (e) {
      LogService.error('search failed', e);
    }
    isLoading.value = false;
  }
}
