This is to to see how to handle html.keyed with a server app

- Elm with lots of HTTP interactions
- VDOM optimizing with Html.Keyed and HTML.lazy
- Need to load lots of items on startup from a file so I can see how sluggish the frontend can get

Run with ` npx elm-live src/Main.elm --open -- --debug`

# TODO

I've got keyed in there and it seems to be working, but it should be broken??? What is wrong??? - https://elmlang.slack.com/archives/C192T0Q1E/p1584290188196500

User can only edit one thing at a time so use a shared editing instance to save memory (so we don't have 1000 elements and their usually empty edited copies)

learn how to test...

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

## Data Structure for complex todos

### Need
- edit todoToAdd from from at top
- edit todo from any index in Todos
- cancel edit todo from any index in Todos (i.e., replace it with previous content)
  - I think I want to implement this by having a scratch Todo that doesn't write over previous indexed one

Scenario:
- Todo has many ^common^ fields ( say text, priority, tags, url) and some fields for some specific scenario (like a server id). How can I work with that data structure in one place?

- Use extensible records? https://medium.com/@ckoster22/advanced-types-in-elm-extensible-records-67e9d804030d

```
-- this will be contained in model
type alias Todo t = { t | text : String, priority: Int, .. }

TodoFromServer = { id: Id, text: String, ... }
TodoEditing = { id: Id, index: Index, text: String, ... }
```

What if I want 2 Todos in the top level model?

or something like:

```
type alias Model =
    { text: String
    , priority: Int
    , todoEditing: Maybe TodoEditing
    , todos: Array.Array TodoFromServer
    }

```
- use a piping API to set?
- Use a custom message type to set core values?

```
UpdateTodo = UpdateText newText | UpdatePriority newPriority...
```

## Links

- https://guide.elm-lang.org/optimization/keyed.html
- https://package.elm-lang.org/packages/elm/html/latest/Html-Keyed
- https://guide.elm-lang.org/optimization/keyed.html
- https://package.elm-lang.org/packages/FabienHenon/elm-infinite-list-view/latest/

