"""Flask web app — localhost chat UI for the NASA fire-safety RAG.

Run:  python ai/web/app.py   ->  http://127.0.0.1:8000
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'scripts'))

from flask import Flask, request, jsonify, send_from_directory

import config
import rag

app = Flask(__name__)


@app.after_request
def add_cors(resp):
    resp.headers['Access-Control-Allow-Origin'] = '*'
    resp.headers['Access-Control-Allow-Headers'] = 'Content-Type'
    resp.headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
    return resp


@app.route('/')
def index():
    return jsonify({
        'service': 'FireBot RAG API',
        'status': 'online',
        'note': 'This is the backend API. The Flutter UI is hosted separately on Vercel.',
        'endpoints': {
            'GET /health': 'liveness check',
            'POST /ask': 'grounded Q&A (JSON body: question, verbosity)',
            'GET /figures/<file>': 'figure images',
        },
    })


@app.route('/health')
def health():
    return jsonify({'ok': True})


@app.route('/ask', methods=['POST', 'OPTIONS'])
def ask():
    if request.method == 'OPTIONS':
        return ('', 204)
    data = request.get_json(silent=True) or {}
    question = (data.get('question') or '').strip()
    verbosity = (data.get('verbosity') or 'long').strip()
    if not question:
        return jsonify({'error': 'empty question'}), 400
    return jsonify(rag.query(question, verbosity))


@app.route('/figures/<path:filename>')
def figure(filename):
    return send_from_directory(config.IMAGES_DIR, filename)


if __name__ == '__main__':
    # Render/Railway/Fly inject PORT; bind 0.0.0.0 so the container is reachable.
    port = int(os.environ.get('PORT', 8000))
    app.run(host='0.0.0.0', port=port, debug=False, use_reloader=False)
