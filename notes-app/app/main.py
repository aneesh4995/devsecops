from flask import Flask, jsonify, request, abort
from prometheus_client import Counter, generate_latest

app = Flask(__name__)
notes = {}
REQ_COUNTER = Counter('notes_requests_total', 'Total API requests', ['method'])

@app.before_request
def before():
    REQ_COUNTER.labels(method=request.method).inc()

@app.route("/notes", methods=["GET"])
def list_notes():
    return jsonify(notes)

@app.route("/notes/<note_id>", methods=["GET"])
def get_note(note_id):
    note = notes.get(note_id)
    if not note:
        abort(404)
    return jsonify({note_id: note})

@app.route("/notes", methods=["POST"])
def create_note():
    data = request.get_json()
    note_id = str(len(notes) + 1)
    notes[note_id] = data.get("text", "")
    return jsonify({note_id: notes[note_id]}), 201

@app.route("/notes/<note_id>", methods=["PUT"])
def update_note(note_id):
    if note_id not in notes:
        abort(404)
    notes[note_id] = request.get_json().get("text", "")
    return jsonify({note_id: notes[note_id]})

@app.route("/notes/<note_id>", methods=["DELETE"])
def delete_note(note_id):
    if notes.pop(note_id, None) is None:
        abort(404)
    return "", 204

@app.route("/metrics")
def metrics():
    return generate_latest(), 200, {'Content-Type': 'text/plain; version=0.0.4'}

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
