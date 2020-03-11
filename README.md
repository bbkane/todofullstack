This is to to see how to handle html.keyed with a server app

Focuses: Elm with lots of HTTP interactions
VDOM optimizing with Html.Keyed and HTML.lazy
Need to load items from file on startup too (for debugging)
Gonna use it for taggedmarks

Run with ` npx elm-live src/Main.elm --open -- --debug`

# TODO

make it show stuff - I think I need to account for PATCH in the server? see network reqeusts from elm app
Use a html.lazy div to hold the list of items. Use id + editstring as key for html.key. Something like:

```
viewTodos =
    Html.lazy div [] (Html.keyed (list.map (.id ++ .editSText) todos)) todos)
```

viewTodo = if editString show editStringAndButton else show prod+EditButton


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

## TODO Data Structure

https://github.com/evancz/elm-todomvc/blob/master/src/Main.elm

https://github.com/bbkane/todo-list/blob/master/src/Main.elm

For the list of items I need a data structure that can:

- append at the end
- delete from the middle
- edit from middle
- remain sorted in insortion order

Array - append, no delete (can with filter), can edit, can remain sorted
Dict - append, delete, no remain sorted (can with separate list of sorted ids)
List - append, no delete (can with filter - TODOMVC does this), remain sorted
Set - append, delete, edit?, no remain sorted, doesn't work with non-primitive types (wtf?)


## Model



Item : {id : int, editText: String, text: Sring}

{
    nextItem : String
    -- I do need ordering
    -- items : id : Dict (id: String -> Item

    -- items : id : List Item
}

https://guide.elm-lang.org/optimization/keyed.html

https://package.elm-lang.org/packages/elm/html/latest/Html-Keyed
node :
    String
    -> List (Attribute msg)
    -> List ( String, Html msg )
    -> Html msg

https://guide.elm-lang.org/optimization/keyed.html

Also see https://package.elm-lang.org/packages/FabienHenon/elm-infinite-list-view/latest/ for :q

