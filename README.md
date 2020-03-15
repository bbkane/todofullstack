This is to to see how to handle html.keyed with a server app

- Elm with lots of HTTP interactions
- VDOM optimizing with Html.Keyed and HTML.lazy
- Need to load lots of items on startup from a file so I can see how sluggish the frontend can get

Run with ` npx elm-live src/Main.elm --open -- --debug`

# TODO

I've got keyed in there and it seems to be working, but it should be broken??? What is wrong???

## API

GET /api/items/  -- get all (with ids)

{
  response: [ { content: "", id: 1 },  ]
}


POST /api/items/ -- create new
{
  "content": "bob wuz here"
}

PATCH /api/items/1 -- update item
{
  "content": "bob wuzn't here"
}

DELETE /api/items/1 -- delete

## Data Structure for list

https://github.com/evancz/elm-todomvc/blob/master/src/Main.elm

https://github.com/bbkane/todo-list/blob/master/src/Main.elm

For the list of items I need a data structure that can:

- append at the end
- delete from the middle
- edit from middle
- remain sorted in insortion order

- Array - append, no delete (can with filter), can edit, can remain sorted
- Dict - append, delete, no remain sorted (can with separate list of sorted ids)
- List - append, no delete (can with filter - TODOMVC does this), remain sorted
- Set - append, delete, edit?, no remain sorted, doesn't work with non-primitive types (wtf?)

## Links

- https://guide.elm-lang.org/optimization/keyed.html
- https://package.elm-lang.org/packages/elm/html/latest/Html-Keyed
- https://guide.elm-lang.org/optimization/keyed.html
- https://package.elm-lang.org/packages/FabienHenon/elm-infinite-list-view/latest/

