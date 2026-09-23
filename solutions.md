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

####
