#!/usr/bin/env python
# -*- coding: utf-8 -*-

__author__ = "Benjamin Kane"
__version__ = "0.1.0"

# https://flask.palletsprojects.com/en/1.1.x/quickstart/

from flask import Flask, redirect, url_for, jsonify, request

# Global state yay!!
app = Flask(__name__)
g_state = {'todos': []}
try:
    with app.open_resource('tasks.txt', mode='r') as fp:
        i = 0
        for line in fp:
            # line = line.decode('utf-8')
            line = line.strip()
            if line:
                g_state['todos'].append({'id': i, 'text': line})
            i = i + 1
except FileNotFoundError:
    print('No tasks.txt to load')


# https://stackoverflow.com/a/59676071/2958070
# https://github.com/bbkane/taggedmarks/blob/master/server/server.go#L48
@app.after_request
def add_header(response):
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Methods'] = 'POST, GET, OPTIONS, PUT, DELETE, PATCH'
    response.headers['Access-Control-Allow-Headers'] = 'Accept, Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization'
    return response


@app.route('/')
def root():
    return redirect(url_for('items'))


# GET /api/items/  -- get all (with ids)
# {
#   response: [ { text: "", id: 1 },  ]
# }

# POST /api/items/ -- create new
# {
#   "text": "bob wuz here"
# }
@app.route('/api/items', methods=['GET', 'POST', 'OPTIONS'])
def items():
    if request.method == 'GET':
        return jsonify(g_state)
    elif request.method == 'POST':
        json_body = request.json
        text = json_body['text']
        new_item = {'id': len(g_state['todos']), 'text': text}
        g_state['todos'].append(new_item)
        return jsonify(new_item)
    elif request.method == 'OPTIONS':
        return '', 200
    else:
        raise ValueError(f"Invalid method {request.method}")

# PATCH /api/items/1 -- update item
# {
#   "text": "bob wuzn't here"
# }

# DELETE /api/items/1 -- delete
@app.route('/api/items/<int:task_id>', methods=['GET', 'PATCH', 'DELETE', 'OPTIONS'])
def item(task_id):
    if request.method == 'GET':
        return jsonify(g_state['todos'][task_id])
    elif request.method == 'PATCH':
        json_body = request.json
        text = json_body['text']
        g_state['todos'][task_id]['text'] = text
        # TODO: what's the right HTTP code for this?
        return jsonify(g_state['todos'][task_id])
    elif request.method == 'DELETE':
        del g_state['todos'][task_id]
        return '', 204
    elif request.method == 'OPTIONS':
        return '', 200
    else:
        raise ValueError(f"Invalid method {request.method}")

