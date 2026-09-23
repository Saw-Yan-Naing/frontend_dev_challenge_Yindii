import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescu/feature/home/home_controller.dart';
import 'package:rescu/model/deal_model.dart';
import 'package:rescu/model/paged_response_model.dart';
import 'package:rescu/repository/deal_repo.dart';

DealModel _createMockDeal(int id, String name) {
  return DealModel.fromJson({
    'id': id,
    'name': name,
    'description': 'Description $id',
    'imageUrl': 'https://example.com/$id.jpg',
    'originalPrice': 100,
    'price': 50,
    'currencyCode': 'THB',
    'quantityLeft': 5,
    'storeId': 1,
    'storeName': 'Store $id',
    'storeAddress': 'Address $id',
    'lat': 13.0,
    'lng': 100.0,
    'rating': 4.5,
    'tags': [],
    'pickupWindow': {
      'start': '2026-01-01T10:00:00.000Z',
      'end': '2026-01-01T20:00:00.000Z',
    },
    'flashSaleEndsAt': null,
  });
}

class FakeDealRepo implements DealRepo {
  Completer<PagedResponseModel<DealModel>>? page1Completer;
  Completer<PagedResponseModel<DealModel>>? page2Completer;

  @override
  Future<PagedResponseModel<DealModel>> fetchDeals({int page = 1}) {
    if (page == 1) {
      page1Completer = Completer();
      return page1Completer!.future;
    } else {
      page2Completer = Completer();
      return page2Completer!.future;
    }
  }

  @override
  Future<List<DealModel>> fetchFlashDeals() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
      'reproduces duplicate deals on loadMore and refresh race condition',
      (tester) async {
    final fakeRepo = FakeDealRepo();
    final controller = HomeController(dealRepo: fakeRepo);

    // 1. Initial refreshDeals (Page 1)
    final refreshFuture1 = controller.refreshDeals();
    fakeRepo.page1Completer!.complete(PagedResponseModel(
      items: [_createMockDeal(1, 'Deal 1'), _createMockDeal(2, 'Deal 2')],
      page: 1,
      totalPages: 2,
    ));
    await refreshFuture1;

    expect(controller.deals.length, 2);
    expect(controller.deals.map((d) => d.id), [1, 2]);

    // 2. User scrolls to bottom -> loadMore (Page 2) starts
    final loadMoreFuture1 = controller.loadMore();

    // 3. Before loadMore finishes, user pulls down to refresh -> refreshDeals starts
    final refreshFuture2 = controller.refreshDeals();

    // 4. Refresh completes first with page 1 items
    fakeRepo.page1Completer!.complete(PagedResponseModel(
      items: [_createMockDeal(1, 'Deal 1'), _createMockDeal(2, 'Deal 2')],
      page: 1,
      totalPages: 2,
    ));
    await refreshFuture2;

    // 5. Pending loadMore (page 2) completes after refresh finished
    fakeRepo.page2Completer!.complete(PagedResponseModel(
      items: [_createMockDeal(3, 'Deal 3'), _createMockDeal(4, 'Deal 4')],
      page: 2,
      totalPages: 2,
    ));
    await loadMoreFuture1;

    // 6. User scrolls down and triggers loadMore again (since _page was reset to 1)
    final loadMoreFuture2 = controller.loadMore();
    fakeRepo.page2Completer!.complete(PagedResponseModel(
      items: [_createMockDeal(3, 'Deal 3'), _createMockDeal(4, 'Deal 4')],
      page: 2,
      totalPages: 2,
    ));
    await loadMoreFuture2;

    final dealIds = controller.deals.map((d) => d.id).toList();
    debugPrint('Current deal IDs in controller: $dealIds');

    // Assert no duplicates exist in the list
    expect(dealIds, equals(dealIds.toSet().toList()),
        reason: 'Duplicate deal IDs found in home feed due to race condition!');
  });
}
