### RES-101 · Search shows results for the wrong query

- Problem is because u always calls the query everytime user types so basically user types on the
  text-field

#### Solutions

- In this case I prefer to add debounce to wait the user action to complete for 3 millisecond before
  the search query is called and if the new query is typed before the query api call is finished
  then the _search function won't call until the user stop typing the input for 3 millisecond.

Approximate timeline ===> 15 mins

--------

### RES-102 · Crash after leaving My orders

- Problem is because even after u dispose My Orders screen,the Periodic Timer for the sub widget of
  PickUpCountDown is still running the background every 1 second. So when the pickup countdown is
  disposed but the Timer isn't.

#### Solutions

- In this case I declare variable for the timer object to be able to cancel when the widget is
  disposed.

#### AI Usage

I used Gemini to ensure for the code I fixed correct or not.

Approximate timeline ===> 15 mins

-------

### RES-103 · Requests pile up the longer you browse

- **Root Cause**: In `DealDetailsController.onInit()`, `ever(cartService.itemCount, ...)` creates a
  GetX `Worker` reactive listener subscribed to `cartService.itemCount` (which is hosted on a
  app-session-long `GetxService`). Since the `Worker` reference was not captured and `.dispose()`
  was never called in `onClose()`, every closed or previously opened deal details screen retains its
  reactive subscription active in memory. Whenever the cart item count updates, all active and
  leaked listeners trigger `_recheckAvailability()`, resulting in a burst of `GET /deals/:id`
  requests for all previously visited deals in the session.

#### Solutions

- Store the `Worker` returned by `ever()` in a variable `Worker? _cartWorker` inside
  `DealDetailsController`.
- Override `onClose()` in `DealDetailsController` and invoke `_cartWorker?.dispose()` so that when
  the controller/screen is disposed upon navigation pop, the `cartService.itemCount` subscription is
  cleanly canceled.

#### AI Usage

I used the Gemini for the Worker usage, cause GetX is not my day-to-day usage for state management
and refined for the md report.

Approximate timeline ===> 30 mins

-----

### RES-104 · Duplicate deals in the home feed

- **Root Cause**: An asynchronous race condition between `loadMore()` and `refreshDeals()`. When
  scrolling to the bottom of the feed, `loadMore()` increments `_page` to 2 and initiates an async
  call to `fetchDeals(page: 2)`. If the user immediately pulls down to refresh while that request is
  still in flight, `refreshDeals()` resets `_page = 1` and calls `fetchDeals(page: 1)`. When the
  stale `loadMore()` request completes later, it appends Page 2 items (`deals.addAll(...)`) to the
  newly refreshed Page 1 items. Because `_page` was set to 1 by `refreshDeals()`, the next scroll
  action increments `_page` to 2 again and fetches Page 2 a second time, appending duplicate deal
  cards to the list.

#### Solutions

- **Fetch Generation Counter (`_fetchId`)**: Introduced a request generation counter `_fetchId` that
  increments on every `refreshDeals()`. Before appending items in `loadMore()`, the controller
  verifies `currentFetchId == _fetchId`. If a refresh occurred while `loadMore()` was in flight, the
  stale response is safely discarded.
- **Deduplication by ID**: Filtered newly fetched deals against existing deal IDs (
  `deals.map((d) => d.id).toSet()`) before appending to ensure duplicate IDs can never enter the
  reactive list.
- **Unit Test**: Added a test case in `test/home_controller_test.dart` using a mock `DealRepo` with
  async `Completer`s to simulate in-flight race conditions and verify no duplicates occur.

#### AI Usage

Used AI to write unit test harness using `Completer` to simulate in-flight async network race
condition and write the solution md.

Approximate timeline ===> 20 mins

----

### RES-105 · Home feed is janky and memory keeps climbing

**Root Cause**

- Whole-Screen Rebuilds: The top-level Scaffold was wrapped in an Obx listening to
  controller.scrollOffset.value. Scroll updates triggered full-screen rebuilds on every frame.
- Eager Instantiation: ListView(children: [ ...controller.visibleDeals.map(...) ]) eagerly
  instantiated all deal cards in memory instead of lazily building visible items.
- Image Cache Memory Growth: CachedNetworkImage loaded full-resolution images into memory without
  cache dimensions (memCacheWidth / memCacheHeight).

#### Solutions

**Refactor Process**

- CustomScrollView with Slivers: Replace ListView with a CustomScrollView inside SmartRefresher.
- Modular Widget Separation:

    - _HomeAppBar: Scoped Obx for scroll elevation without rebuilding the body.
    - _ScrollToTopFab: Scoped Obx for FAB visibility (scrollOffset > 800).
    - home_filter_header.dart: SliverToBoxAdapter with scoped Obx for todayOnly filter chip.
    - home_deals_sliver.dart: SliverList.builder with scoped Obx for lazy, on-demand deal card
      rendering.
    - home_loading_sliver.dart: Lazy SliverList.builder for shimmer cards during initial load.


- Image Memory Caching: Add maxWidthDiskCache to the_network_image.dart to
  constrain image memory footprint.

#### Performance Profiling Evidence

**Before Fix (Frequent Jank / Red Bars during scrolling)**
![Before Fix](assets/solution/home_screen_janking(before-fix).png)

**After Fix (Smooth 60/90 FPS scrolling with no jank frames)**
![After Fix](assets/solution/home_screen_janking(after-fix).png)

### AI Usage

I Use Gemini to implement the refactor process How I want with the prompt

Approximate Timeline ===> 40 mins

--------

### RES-106 · Wrong pickup times; "Pickup today" filter misses deals

#### Root Cause

- **Timezone Conversion Missing**: The backend sends standard ISO-8601 UTC strings ending with `Z` (
  like `"2025-01-14T23:00:00.000Z"` for a store opening at `06:00` Bangkok time UTC+7). In
  `PickupWindowModel.fromJson()`, `DateTime.parse()` parsed these into UTC `DateTime` instances (
  `isUtc = true`). When `DateFormat('HH:mm').format(start)` generated the label, it formatted UTC
  hours (`23:00`) instead of converting to local time (`06:00`).
- **Broken "Pickup Today" Filter**: `PickupWindowModel.isToday` was checking
  `start.day == DateTime.now().day`. Because `start.day` evaluated to the UTC day (14th) while
  `DateTime.now().day` evaluated to local device day (15th), stores with pickup slots today were
  filtered out. Also, comparing only `.day` didn't verify if month and year matched.

#### Solutions & Steps I Took

1. **Converted DateTime Parsing to Local Time**:
    - Added `.toLocal()` when parsing `start` and `end` inside `PickupWindowModel.fromJson()`. Now
      `start` and `end` are always stored in local device timezone.
    - Also added `.toLocal()` to `OrderModel.fromJson()` for `pickupStart` and `pickupEnd` for
      consistency.

2. **Fixed `isToday` Comparison**:
    - Updated `isToday` in `PickupWindowModel` to compare local year, month, and day against
      `DateTime.now()`:
      ```dart
      bool get isToday {
        final now = DateTime.now();
        return start.year == now.year &&
            start.month == now.month &&
            start.day == now.day;
      }
      ```

3. **Alternative Considered & Rejected**:
    - I considered keeping `start` / `end` in UTC and only calling `.toLocal()` inside the `label`
      getter.
    - I rejected this because any other widget or getter accessing `start` directly (like `isToday`
      or `untilStart`) would still receive UTC time and could easily re-introduce timezone bugs
      later.

4. **Edge Cases**:
    - Overnight stores (e.g., open 22:00 to 01:00 next day): Calling `.toLocal()` on both start and
      end handles the day rollover automatically based on device timezone.

5. **Unit Tests**:
    - Updated `test/model_test.dart` to test that UTC ISO strings convert to local time, produce
      correct formatted labels, and accurately evaluate `isToday`.

#### AI Usage

I used AI to confirm Dart's `DateTime.parse` behavior with UTC strings and generate unit test cases
for timezone parsing.

Approximate timeline ===> 20 mins


--------

### RES-107 · Deep link opens to a crash

#### Root Cause

- Previously, `DealDetailsController` assumed `Get.arguments` was always provided and held a
  `DealModel` instance (`deal = Get.arguments as DealModel;`).
- When opening a deal via deep link (e.g. `rescu://open/deal?id=42&source=push` or
  `Get.toNamed('/deal?id=42&source=push')`), `Get.arguments` is `null` because arguments are sent
  via URL query parameters (`Get.parameters['id']`) instead of memory objects.
- Attempting to cast `null` directly as `DealModel` caused a runtime type error:
  `type 'Null' is not a subtype of type 'DealModel'`.

#### Solutions

- Updated `DealDetailsController.onInit()` to inspect the type of `Get.arguments`:
    - If `Get.arguments` is a `DealModel` (in-app navigation from deal cards), use it immediately
      without network waiting.
    - If `Get.arguments` is `null` or not a `DealModel` (deep link navigation), extract the `id`
      from `Get.parameters['id']` (or `Get.arguments` if passed as an ID value), parse it to an
      integer, and set `isLoading = true`.
    - Fetch the complete `DealModel` asynchronously from the repository via
      `dealRepo.fetchById(dealId)`.
    - Upon completion, update `_deal.value`, `_quantityLeft.value`, log the `deal_details_view`
      analytics event with the source parameter (e.g., `'push'`), and initialize the cart reactive
      worker (`_setupCartWorker()`).

#### Alternatives Considered & Rejected

- **Always fetching by ID from network**: Always fetching from `dealRepo.fetchById()` on screen
  open (ignoring `Get.arguments`) was considered to guarantee fresh data.
    - *Rejected because*: Passing the `DealModel` via arguments when tapping a deal card provides
      instant screen rendering without an extra loading spinner. The controller already refreshes
      availability via `_recheckAvailability()` when cart state changes.

#### Edge Cases

- **Missing or Invalid ID / Fetch Failures**: If `Get.parameters['id']` is missing, invalid, or
  `fetchById` fails, `isLoading` completes (`isLoading = false`) and `errorMessage` is set. The screen
  displays an error view with a clear message ("Deal not found" or "Failed to load deal details") and
  action buttons ("Go back" and "Retry") instead of remaining stuck on an indefinite loading indicator.
- **Preserving Analytics Parameters**: `Get.parameters['source']` is retrieved to ensure deep link
  sources (e.g., `source=push`) are accurately logged in analytics events.

Approximate timeline ===> 15 mins


-------

### F-1 · Live flash-sale countdowns

#### Requirements & Overview

- Display a live countdown (`mm:ss`, or `hh:mm:ss` above an hour) everywhere the flash deal appears: flash rail, home feed cards, and details screen.
- When countdown reaches zero:
  - Card switches to a disabled "Expired" state (`EXPIRED` badge, 60% opacity).
  - Deal can no longer be added to the bag (disabled button in details screen, checked in `addToCart` & `CartService.add`).
  - If already in bag, it is automatically removed with a visible notice (`Get.snackbar`).
- Home feed must remain smooth with 100+ visible countdowns: per-second rebuilds must be strictly scoped to the text node that changes, avoiding card or list re-renders.

#### Solutions & Architectural Design

1. **Central Ticker (`CentralTicker` / `CentralTickerNotifier` in `lib/util/central_ticker.dart`)**:
   - Instead of creating individual `Timer.periodic` instances for each visible card (which causes 100+ separate timers firing asynchronously), a singleton `CentralTicker` manages a single 1-second `Timer.periodic`.
   - `CentralTickerNotifier` extends `ValueNotifier<DateTime>`. It overrides `addListener` and `removeListener` so that the timer automatically starts when the first listener mounts and stops when all listeners unmount. This ensures zero CPU/battery drain when no countdown widgets are visible.

2. **Scoped Widget Rebuilds (`FlashCountdownBadge` in `lib/feature/shared_widget/flash_countdown_badge.dart`)**:
   - `FlashCountdownBadge` listens to `CentralTicker.instance.nowNotifier` using `ValueListenableBuilder<DateTime>`.
   - On each 1-second tick, `ValueListenableBuilder` only executes its builder callback, which formats the duration string (`formatFlashCountdown`) and updates the `Text` badge node (`⚡ 05:23` or `EXPIRED`).
   - In `DealCard`, the card content layout is passed to `ValueListenableBuilder`'s `child:` parameter. Per-second ticks verify expiration without re-instantiating or re-painting the inner `Card` subtree unless the expiration state actually toggles.
   - Result: 0 card rebuilds, 0 list rebuilds, 0 frame drops even with 100+ cards on screen.

3. **Expiration Handling across the App**:
   - **Flash Rail (`FlashDealsSection`)**: Replaced static `'Ends soon'` label with `FlashCountdownBadge(flashSaleEndsAt: deal.flashSaleEndsAt!, isLight: true)`.
   - **Deal Details Screen (`DealDetailsScreen`)**: Added `FlashCountdownBanner` for flash deals. The bottom sheet button uses `ValueListenableBuilder` on `CentralTicker` to immediately disable the button and show `'Expired'` when time runs out.
   - **Deal Details Controller (`DealDetailsController`)**: Added expiration verification in `addToCart()` to prevent adding expired deals if attempted.
   - **Cart Service (`CartService`)**: Registered a listener on `CentralTicker`. Every second, it checks cart items for expired flash deals, removes any expired items from `items`, recalculates totals, and notifies the user via `Get.snackbar('Item expired', '...')`.
   - **Timezone Safety (`DealModel`)**: Added `.toLocal()` to `flashSaleEndsAt` in `DealModel.fromJson()` so UTC API timestamps evaluate correctly against device local time. Added `isExpiredAt(DateTime now)` helper.

#### Alternatives Considered & Rejected

- **Per-Widget `Timer.periodic`**: Having each `DealCard` manage its own timer was rejected because 100+ active timers in Dart's event loop cause thread contention, unaligned ticks, and memory leak risks on list scrolling.
- **Top-Level Reactive Stream / Obx over List**: Wrapping `SliverList` or `DealCard` in GetX `Obx` was rejected because per-second state changes would trigger full card/list rebuilds, causing DevTools frame jank.

#### Edge Cases Handled

- **Timezone Mismatch**: Backend sends UTC ISO strings (`...Z`). Converting via `.toLocal()` in `DealModel.fromJson` avoids negative duration bugs on different timezones.
- **Multiple Expired Items in Bag**: `CartService` filters all expired items in a single pass and removes them safely without index out-of-bound errors.
- **Zero Active Listeners**: When all flash sale widgets scroll off-screen, `CentralTicker` pauses its timer automatically to conserve battery.

#### AI Usage

Used AI to assist in designing the `CentralTickerNotifier` listener-counting lifecycle and formatting logic, and to generate comprehensive unit tests in `test/flash_sale_test.dart`.

Approximate timeline ===> 35 mins

--------

### F-2 · Impression tracking

#### Requirements & Overview

- Log a `deal_impression` event when a deal card has been **≥50% visible for at least 1 continuous second**. Properties: `deal_id`, `source` (`home_feed`, `flash_rail`, or `search`), `position` (index in its list).
- Log at most **once per deal per app session**, across all screens.
- Batch analytics events and deliver via `FakeApiService.sendAnalyticsBatch` when either **10 events have accumulated** or **15 seconds have passed since the first unsent event** — whichever comes first.
- Scrolling performance must not regress.

#### Solutions & Architectural Design

1. **Session-Level Impression Set (`AnalyticsService` in `lib/service/analytics_service.dart`)**:
   - `AnalyticsService` maintains a `Set<int> _impressionedDealIds`.
   - Before firing an impression event, `hasImpression(dealId)` checks whether the deal was already recorded during the current app session.
   - If true, the impression is ignored regardless of which screen or source (`home_feed`, `flash_rail`, `search`) triggers it.

2. **Zero-Overhead Visibility Detection (`DealImpressionDetector` in `lib/feature/shared_widget/deal_impression_detector.dart`)**:
   - Built a reusable `DealImpressionDetector` widget wrapping `VisibilityDetector`.
   - **Performance Optimization**: When `analytics.hasImpression(dealId)` is `true`, `DealImpressionDetector` immediately returns its `child` without instantiating `VisibilityDetector` or subscribing to scroll/layout callbacks.
   - **Continuous 1-Second Timer**: When `visibleFraction >= 0.5`, a 1-second `Timer` is initialized. If the card scrolls out of view (`visibleFraction < 0.5`) or unmounts before 1 continuous second, `_timer?.cancel()` cancels the timer immediately.
   - When the 1-second timer completes, `trackImpression()` records the event and calls `setState()`, which immediately unmounts the `VisibilityDetector` for that card, guaranteeing zero scrolling jank.

3. **Analytics Batching & Delivery (`AnalyticsService`)**:
   - Maintains a pending queue `_pendingBatch` for outgoing events.
   - **15-Second Timer**: When the first unsent event enters `_pendingBatch`, a 15-second `Timer` starts.
   - **Batch Threshold**: When `_pendingBatch.length >= 10`, `_flushBatch()` cancels the timer and delivers the 10-event batch immediately via `FakeApiService.sendAnalyticsBatch`.
   - **15-Second Flush**: If 15 seconds elapse before reaching 10 events, the timer callback triggers `_flushBatch()`, delivering whatever unsent events have accumulated.
   - Calls `_flushBatch()` in `onClose()` to ensure no unsent events are lost on teardown.

4. **Wired Across All Surfaces**:
   - **Home Feed (`HomeDealsSliver`)**: Passes `source: 'home_feed'` and `position: index` to `DealCard`.
   - **Flash Sale Rail (`FlashDealsSection`)**: Wraps cards in `DealImpressionDetector` with `source: 'flash_rail'` and `position: index`.
   - **Search Results (`SearchScreen`)**: Passes `source: 'search'` and `position: index` to `DealCard`.

#### Alternatives Considered & Rejected

- **Keeping `VisibilityDetector` Active Always**: Keeping `VisibilityDetector` attached after logging an impression was rejected because processing continuous scroll layout events for already-impressioned cards wastes CPU cycles during long scroll sessions.
- **Immediate Event Sending**: Sending `FakeApiService.sendAnalyticsBatch` one by one was rejected because it causes excessive HTTP network requests on scrolling.

#### Edge Cases Handled

- **Fast Scrolling**: Swiping past 20 items in 2 seconds cancels timers immediately as cards exit the viewport, logging 0 impression events for unviewed items.
- **Cross-Screen Duplicates**: Seeing a deal in `flash_rail` and then scrolling past it in `home_feed` records only 1 impression event in the session.
- **App Teardown**: `onClose()` flushes any remaining buffered events so no impression analytics are lost.

#### AI Usage

Used AI to design unit tests in `test/analytics_test.dart` for impression deduplication, 10-event threshold batching, and 15-second timer batching.

Approximate timeline ===> 30 mins
