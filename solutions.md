### RES-101 · Search shows results for the wrong query

- Problem is because u always calls the query everytime user types so basically user types on the
  text-field

Solutions

- In this case I prefer to add debounce to wait the user action to complete for 3 millisecond before
  the search query is called and if the new query is typed before the query api call is finished
  then the _search function won't call until the user stop typing the input for 3 millisecond.



