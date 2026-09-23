### RES-101 · Search shows results for the wrong query

- Problem is because u always calls the query everytime user types so basically user types on the
  text-field

#### Solutions

- In this case I prefer to add debounce to wait the user action to complete for 3 millisecond before
  the search query is called and if the new query is typed before the query api call is finished
  then the _search function won't call until the user stop typing the input for 3 millisecond.

Approximate timeline ===> 15 mins

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




