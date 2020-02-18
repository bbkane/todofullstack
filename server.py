#!/usr/bin/env python
# -*- coding: utf-8 -*-

__author__ = "Benjamin Kane"
__version__ = "0.1.0"

# https://flask.palletsprojects.com/en/1.1.x/quickstart/

from flask import Flask, redirect, url_for, jsonify, request

# Global state yay!!
app = Flask(__name__)
g_state = {'tasks': []}
with app.open_resource('tasks.txt', mode='r') as fp:
    i = 0
    for line in fp:
        # line = line.decode('utf-8')
        line = line.strip()
        if line:
            g_state['tasks'].append({'id': i, 'content': line})


@app.route('/')
def root():
    return redirect(url_for('items'))


# GET /api/items/  -- get all (with ids)
# {
#   response: [ { content: "", id: 1 },  ]
# }

# POST /api/items/ -- create new
# {
#   "content": "bob wuz here"
# }
@app.route('/api/items', methods=['GET', 'POST'])
def items():
    if request.method == 'GET':
        return jsonify(g_state)
    elif request.method == 'POST':
        json_body = request.json
        content = json_body['content']
        new_item = {'id': len(g_state['tasks']), 'content': content}
        g_state['tasks'].append(new_item)
        return jsonify(new_item)
    else:
        raise ValueError(f"Invalid method {request.method}")

# PATCH /api/items/1 -- update item
# {
#   "content": "bob wuzn't here"
# }

# DELETE /api/items/1 -- delete
@app.route('/api/items/<int:task_id>', methods=['GET', 'PATCH', 'DELETE'])
def item(task_id):
    if request.method == 'GET':
        return jsonify(g_state['tasks'][task_id])
    elif request.method == 'PATCH':
        json_body = request.json
        content = json_body['content']
        g_state['tasks'][task_id]['content'] = content
        # TODO: what's the right HTTP code for this?
        return jsonify(g_state['tasks'][task_id])
    elif request.method == 'DELETE':
        del g_state['tasks'][task_id]
        return '', 204
    else:
        raise ValueError(f"Invalid method {request.method}")

