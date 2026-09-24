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
  GetX `Worker` reactive listener subscribed to `cartService.itemCount` (which is hosted on an
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
  `fetchById` fails, `isLoading` completes (`isLoading = false`) and `errorMessage` is set. The
  screen
  displays an error view with a clear message ("Deal not found" or "Failed to load deal details")
  and
  action buttons ("Go back" and "Retry") instead of remaining stuck on an indefinite loading
  indicator.
- **Preserving Analytics Parameters**: `Get.parameters['source']` is retrieved to ensure deep link
  sources (e.g., `source=push`) are accurately logged in analytics events.

Approximate timeline ===> 15 mins


-------

### F-1 · Live flash-sale countdowns

#### Requirements & Overview

- Display a live countdown (`mm:ss`, or `hh:mm:ss` above an hour) everywhere the flash deal appears:
  flash rail, home feed cards, and details screen.
- When countdown reaches zero:
    - Card switches to a disabled "Expired" state (`EXPIRED` badge, 60% opacity).
    - Deal can no longer be added to the bag (disabled button in details screen, checked in
      `addToCart` & `CartService.add`).
    - If already in bag, it is automatically removed with a visible notice (`Get.snackbar`).
- Home feed must remain smooth with 100+ visible countdowns: per-second rebuilds must be strictly
  scoped to the text node that changes, avoiding card or list re-renders.

#### Solutions & Architectural Design

1. **Central Ticker (`CentralTicker` / `CentralTickerNotifier` in `lib/util/central_ticker.dart`)**:
    - Instead of creating individual `Timer.periodic` instances for each visible card (which causes
      100+ separate timers firing asynchronously), a singleton `CentralTicker` manages a single
      1-second `Timer.periodic`.
    - `CentralTickerNotifier` extends `ValueNotifier<DateTime>`. It overrides `addListener` and
      `removeListener` so that the timer automatically starts when the first listener mounts and
      stops when all listeners unmount. This ensures zero CPU/battery drain when no countdown
      widgets are visible.

2. **Scoped Widget Rebuilds (`FlashCountdownBadge`
   in `lib/feature/shared_widget/flash_countdown_badge.dart`)**:
    - `FlashCountdownBadge` listens to `CentralTicker.instance.nowNotifier` using
      `ValueListenableBuilder<DateTime>`.
    - On each 1-second tick, `ValueListenableBuilder` only executes its builder callback, which
      formats the duration string (`formatFlashCountdown`) and updates the `Text` badge node (
      `⚡ 05:23` or `EXPIRED`).
    - In `DealCard`, the card content layout is passed to `ValueListenableBuilder`'s `child:`
      parameter. Per-second ticks verify expiration without re-instantiating or re-painting the
      inner `Card` subtree unless the expiration state actually toggles.
    - Result: 0 card rebuilds, 0 list rebuilds, 0 frame drops even with 100+ cards on screen.

3. **Expiration Handling across the App**:
    - **Flash Rail (`FlashDealsSection`)**: Replaced static `'Ends soon'` label with
      `FlashCountdownBadge(flashSaleEndsAt: deal.flashSaleEndsAt!, isLight: true)`.
    - **Deal Details Screen (`DealDetailsScreen`)**: Added `FlashCountdownBanner` for flash deals.
      The bottom sheet button uses `ValueListenableBuilder` on `CentralTicker` to immediately
      disable the button and show `'Expired'` when time runs out.
    - **Deal Details Controller (`DealDetailsController`)**: Added expiration verification in
      `addToCart()` to prevent adding expired deals if attempted.
    - **Cart Service (`CartService`)**: Registered a listener on `CentralTicker`. Every second, it
      checks cart items for expired flash deals, removes any expired items from `items`,
      recalculates totals, and notifies the user via `Get.snackbar('Item expired', '...')`.
    - **Timezone Safety (`DealModel`)**: Added `.toLocal()` to `flashSaleEndsAt` in
      `DealModel.fromJson()` so UTC API timestamps evaluate correctly against device local time.
      Added `isExpiredAt(DateTime now)` helper.

#### Alternatives Considered & Rejected

- **Per-Widget `Timer.periodic`**: Having each `DealCard` manage its own timer was rejected because
  100+ active timers in Dart's event loop cause thread contention, unaligned ticks, and memory leak
  risks on list scrolling.
- **Top-Level Reactive Stream / Obx over List**: Wrapping `SliverList` or `DealCard` in GetX `Obx`
  was rejected because per-second state changes would trigger full card/list rebuilds, causing
  DevTools frame jank.

#### Edge Cases Handled

- **Timezone Mismatch**: Backend sends UTC ISO strings (`...Z`). Converting via `.toLocal()` in
  `DealModel.fromJson` avoids negative duration bugs on different timezones.
- **Multiple Expired Items in Bag**: `CartService` filters all expired items in a single pass and
  removes them safely without index out-of-bound errors.
- **Zero Active Listeners**: When all flash sale widgets scroll off-screen, `CentralTicker` pauses
  its timer automatically to conserve battery.

#### AI Usage

Used AI to assist in designing the `CentralTickerNotifier` listener-counting lifecycle and
formatting logic, and to generate comprehensive unit tests in `test/flash_sale_test.dart`.

Approximate timeline ===> 35 mins

--------

### F-2 · Impression tracking

#### Requirements & Overview

- Log a `deal_impression` event when a deal card has been **≥50% visible for at least 1 continuous
  second**. Properties: `deal_id`, `source` (`home_feed`, `flash_rail`, or `search`), `position` (
  index in its list).
- Log at most **once per deal per app session**, across all screens.
- Batch analytics events and deliver via `FakeApiService.sendAnalyticsBatch` when either **10 events
  have accumulated** or **15 seconds have passed since the first unsent event** — whichever comes
  first.
- Scrolling performance must not regress.

#### Solutions & Architectural Design

1. **Session-Level Impression Set (`AnalyticsService` in `lib/service/analytics_service.dart`)**:
    - `AnalyticsService` maintains a `Set<int> _impressionedDealIds`.
    - Before firing an impression event, `hasImpression(dealId)` checks whether the deal was already
      recorded during the current app session.
    - If true, the impression is ignored regardless of which screen or source (`home_feed`,
      `flash_rail`, `search`) triggers it.

2. **Zero-Overhead Visibility Detection (`DealImpressionDetector`
   in `lib/feature/shared_widget/deal_impression_detector.dart`)**:
    - Built a reusable `DealImpressionDetector` widget wrapping `VisibilityDetector`.
    - **Performance Optimization**: When `analytics.hasImpression(dealId)` is `true`,
      `DealImpressionDetector` immediately returns its `child` without instantiating
      `VisibilityDetector` or subscribing to scroll/layout callbacks.
    - **Continuous 1-Second Timer**: When `visibleFraction >= 0.5`, a 1-second `Timer` is
      initialized. If the card scrolls out of view (`visibleFraction < 0.5`) or unmounts before 1
      continuous second, `_timer?.cancel()` cancels the timer immediately.
    - When the 1-second timer completes, `trackImpression()` records the event and calls
      `setState()`, which immediately unmounts the `VisibilityDetector` for that card, guaranteeing
      zero scrolling jank.

3. **Analytics Batching & Delivery (`AnalyticsService`)**:
    - Maintains a pending queue `_pendingBatch` for outgoing events.
    - **15-Second Timer**: When the first unsent event enters `_pendingBatch`, a 15-second `Timer`
      starts.
    - **Batch Threshold**: When `_pendingBatch.length >= 10`, `_flushBatch()` cancels the timer and
      delivers the 10-event batch immediately via `FakeApiService.sendAnalyticsBatch`.
    - **15-Second Flush**: If 15 seconds elapse before reaching 10 events, the timer callback
      triggers `_flushBatch()`, delivering whatever unsent events have accumulated.
    - Calls `_flushBatch()` in `onClose()` to ensure no unsent events are lost on teardown.

4. **Wired Across All Surfaces**:
    - **Home Feed (`HomeDealsSliver`)**: Passes `source: 'home_feed'` and `position: index` to
      `DealCard`.
    - **Flash Sale Rail (`FlashDealsSection`)**: Wraps cards in `DealImpressionDetector` with
      `source: 'flash_rail'` and `position: index`.
    - **Search Results (`SearchScreen`)**: Passes `source: 'search'` and `position: index` to
      `DealCard`.

#### Alternatives Considered & Rejected

- **Keeping `VisibilityDetector` Active Always**: Keeping `VisibilityDetector` attached after
  logging an impression was rejected because processing continuous scroll layout events for
  already-impression cards wastes CPU cycles during long scroll sessions.
- **Immediate Event Sending**: Sending `FakeApiService.sendAnalyticsBatch` one by one was rejected
  because it causes excessive HTTP network requests on scrolling.

#### Edge Cases Handled

- **Fast Scrolling**: Swiping past 20 items in 2 seconds cancels timers immediately as cards exit
  the viewport, logging 0 impression events for unviewed items.
- **Cross-Screen Duplicates**: Seeing a deal in `flash_rail` and then scrolling past it in
  `home_feed` records only 1 impression event in the session.
- **App Teardown**: `onClose()` flushes any remaining buffered events so no impression analytics are
  lost.

#### AI Usage

Used AI to design unit tests in `test/analytics_test.dart` for impression deduplication, 10-event
threshold batching, and 15-second timer batching.

Approximate timeline ===> 30 mins

--------

### F-3 · Stock reservations with optimistic UI

#### Requirements & Overview

- Reserve stock asynchronously when items are added or quantity is increased in the bag.
- UI must respond **optimistically** (instant feedback). If the reservation fails on backend (e.g.
  409 stock contention), reconcile by rolling back local state and notifying the user with a clear,
  non-technical message.
- Each line in the bag shows a live countdown of its 5-minute stock hold.
- Decrementing or removing a line releases or adjusts the reservation hold on the backend.
- Checkout passes reservation IDs; handle `410 reservation expired` rejections gracefully.
- Product decision for reservation expiry while browsing or mid-checkout.

#### Solutions & Architectural Design

1. **Optimistic State & Reconciliation (`CartService` in `lib/service/cart_service.dart`)**:
    - On `add(deal)` or quantity increment:
        - Instantly update local reactive list (`items`) and recount totals. The UI updates without
          delay.
        - Set `isReserving = true` on the item and initiate
          `_syncReservation(deal, targetQuantity, oldQuantity)`.
    - **Reconciliation on 409 Failure**:
        - If adding a new deal (old quantity = 0) fails with 409 (stock contended), `CartService`
          removes the item from the bag and shows a snackBar: *"Could not reserve [Name]: someone
          grabbed the last one."*
        - If incrementing quantity fails, `CartService` reverts quantity back to `oldQuantity` and
          keeps the prior valid reservation hold intact.

2. **Concurrency & Sequence Tokens (`_reservationTokens`)**:
    - To handle rapid user taps (`+`, `+`, `-`), `CartService` maintains a per-deal request counter
      `_reservationTokens[dealId]`.
    - Each reservation call captures its request token. If a newer request or removal occurs while
      the API call is in flight, the stale response is ignored and its newly issued reservation ID
      is immediately released (`releaseReservation`).

3. **Line Item Reservation Countdown (`CartScreen` & `_CartReservationBadge`)**:
    - Added `isReserving` and `reservation` fields to `CartItemModel`.
    - In `CartScreen`, `_CartReservationBadge` listens to `CentralTicker.instance.nowNotifier`.
    - Shows `"Reserving hold..."` with a spinner while in flight. Once secured, displays a live
      `"Reserved: mm:ss"` countdown.

4. **Hold Adjustment & Release**:
    - Decrementing quantity triggers `_syncReservation()` with the lower quantity. Once the new
      reservation succeeds, the older reservation ID is released.
    - Removing an item or calling `clear()` triggers `orderRepo.releaseReservation(reservation.id)`
      in the background.

5. **Product Decision & Expiry Policy (Underspecified Requirement)**:
    - **Active Auto-Extension**: When an item's 5-minute reservation expires while the user is
      active in the app, `CartService` (listening to `CentralTicker`) automatically attempts a
      background re-reservation. If stock is still available, the hold is seamlessly extended for
      another 5 minutes without disturbing the user.
    - **Fair Stock Release**: If stock was claimed by another customer during the expired window,
      the item is removed from the bag with a clear notification: *"Reservation for [Item] expired
      and stock was claimed by another customer."*
    - **Pre-Checkout & 410 Handling**: Before sending checkout, `CartController` verifies
      reservation statuses. If checkout returns a `410` status code, `CartController` catches it
      cleanly, notifies the user (*"Your stock reservation expired before payment completed.
      Refreshing your bag..."*), and refreshes cart state without crashing.

#### Alternatives Considered & Rejected

- **Hard Deletion on Expiry**: Immediately deleting items from the bag when 5 minutes elapse without
  checking stock availability was rejected because it creates extreme friction for active users
  about to check out when stock is plentiful.
- **Silent Expiry until Checkout**: Ignoring expiration on the UI and letting checkout fail with 410
  was rejected because it misleads users and leads to high cart abandonment.

#### Edge Cases Handled

- **In-Flight Reservation at Checkout**: `CartController.checkout()` checks if `item.isReserving` is
  true and asks the user to wait a moment.
- **Unit Test Overlay Context**: Created `_showSnackbar` helper so `CartService` and
  `CartController` run safely in unit test suites without an active Flutter widget overlay.

#### AI Usage

Used AI to brainstorm product trade-offs for reservation expiration and generate comprehensive unit
test coverage in `test/cart_reservation_test.dart`.

Approximate timeline ===> 35 mins

--------

## Section 2 · Overall AI Usage Log & Reflection

### AI Tools Used

- **Cursor / Claude 3.5 Sonnet**: Used for code navigation, GetX controller refactoring, layout
  construction (sliver scroll views, central countdown badges), and unit test harness generation.
- **Gemini**: Used for double-checking GetX lifecycle subtleties (`Worker` disposal vs `State`
  disposal), verifying DevTools performance profiling evidence, and refining response reports.

### Two Concrete Examples Where AI Suggestions Were Misleading or Incorrect

#### 1. Suggesting a top-level `Obx` over the home feed list for Flash Sale Countdowns (F-1)

- **Misleading AI Suggestion**: When implementing live flash sale countdown badges, an initial AI
  suggestion recommended wrapping the entire `SliverList.builder` inside a top-level `Obx`
  subscribed to a 1-second reactive ticker in `HomeController`.
- **How I Caught It**: Profiled the scrolling feed in DevTools Performance overlay. Every second,
  red frame spikes appeared during scrolling because `Obx` marked the entire 100+ item list dirty on
  every tick, causing continuous full-list rebuilds.
- **What I Did Instead**: Rejected the top-level `Obx`. Designed `CentralTickerNotifier` using
  `ValueListenableBuilder<DateTime>` and scoped the tick listener exclusively to the text node
  inside `FlashCountdownBadge`. This eliminated all list rebuilds and achieved smooth 60/90 FPS
  scrolling.

#### 2. Recommending raw `Get.snackbar` calls inside `CartService` without context checks (F-3)

- **Misleading AI Suggestion**: During optimistic reservation failure handling, the AI recommended
  calling `Get.snackbar(...)` directly inside `CartService` methods whenever a 409 status code
  occurred.
- **How I Caught It**: Running headless unit tests (`flutter test test/cart_reservation_test.dart`)
  failed with `Null check operator used on a null value` because `Get.overlayContext` is `null` when
  running tests without an active Flutter widget overlay tree.
- **What I Did Instead**: Created a safe `_showSnackBar` helper in `CartService` and
  `CartController` that verifies `Get.context != null && Get.overlayContext != null` before
  triggering `Get.snackbar`. This allowed headless CLI unit tests to pass cleanly while preserving
  user snackbars during live app execution.

--------

## Section 3 · Design Questions

### Q1: Lifecycle differences between `GetxController` and `State`, and the RES-103 Bug

A Flutter widget `State` lifecycle is bound to the widget tree's rendering lifetime (`initState`,
`build`, `dispose`), so it is initialized when a widget enters the tree and destroyed when popped.
In contrast, a `GetxController` lifecycle (`onInit`, `onReady`, `onClose`) depends on GetX
dependency injection rules (`Get.put`, `Get.lazyPut`, or permanent services); a controller can
persist across route pops if registered permanently or held by non-disposed reactive workers. *
*RES-103** occurred due to confusing these lifecycles: `DealDetailsController.onInit()` attached a
reactive `ever()` worker to the session-scoped `CartService.itemCount`, but failed to save the
worker reference and call `.dispose()` in `onClose()`. Because `CartService` lives for the entire
app session, the worker listener remained active in memory after the details screen popped, causing
leaked `GET /deals/:id` requests whenever the cart updated.

### Q2: Downsides of wrapping large subtrees in `Obx` & Reactivity Scoping

Wrapping a large subtree in a single `Obx` hurts performance whenever any reactive variable inside
it updates frequently (e.g. scroll offsets or per-second timers), forcing Flutter to mark the entire
subtree dirty and re-execute `build()` for every child widget, leading to frame drops and memory
churn. Reactivity should be scoped as tightly as possible to the leaf widgets that actually display
changing values. For high-frequency updates, extract only the text or badge node into a micro-`Obx`
or `ValueListenableBuilder`, and pass invariant layout trees via `child:` parameters to prevent
parent rebuilds.

### Q3: Automated Testing for RES-106 (Timezone Bugs) & Refactoring

To catch RES-106 before release, I would write a unit test that instantiates `PickupWindowModel`
from a raw JSON map containing a UTC ISO string ending in `Z` (e.g., `"2025-01-14T23:00:00.000Z"`),
compares formatted `label` hours against expected local wall-clock hours (e.g. `06:00` for Bangkok
UTC+7), and asserts that `isToday` evaluates to `true` when local calendar days match
`DateTime.now()`. To make such tests deterministic across CI pipelines running in different
timezones, I would refactor `PickupWindowModel` to accept an explicit `DateTime now` or inject a
`Clock` service, allowing tests to freeze `now` at specific dates and timezones without relying on
the host machine's system clock.

--------

## Section 4 · Time Spent & Next Steps

### Total Time Spent

Approximately **4 hours 15 minutes** total across all tasks, diagnosis, refactoring, profiling, unit
testing, and documentation:

- **Part A (Bug Tickets RES-101 to RES-107)**: ~2 hours 30 mins
- **Part B (Features F-1, F-2, F-3)**: ~1 hour 40 mins
- **Part C (Documentation & Design Questions)**: ~35 mins

### What I Would Do Next With One More Day

1. **Automated Integration & Golden Tests**: Write widget and golden screenshot tests for
   `CartScreen` and `DealCard` countdown/reservation states to prevent visual regressions.
2. **Offline Retry & Optimistic Queue**: Enhance `CartService` with an offline sync queue so that if
   a reservation or checkout fails due to a transient 502/network timeout, the app offers an
   explicit "Retry" action or background retry queue.
3. **GetX Binding Cleanups**: Strongly type all route arguments and ensure explicit controller
   lifecycle bindings across all feature modules.

------
