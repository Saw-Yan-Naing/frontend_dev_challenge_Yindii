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