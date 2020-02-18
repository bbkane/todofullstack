This is to to see how to handle html.keyed with a server app

Need to load items from file on startup too (for debugging)

Gonna use it for taggedmarks

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
