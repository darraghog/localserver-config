#!/usr/bin/env python3
"""Tic-tac-toe: two-player hot-seat with server-validated moves (Flask + session)."""

from __future__ import annotations

import os
from typing import Any

from flask import Flask, jsonify, render_template, request, session

app = Flask(__name__)
app.secret_key = os.environ.get("SECRET_KEY", "dev-tic-tac-toe-change-me")
# Pick up HTML edits when templates/ is bind-mounted (set TEMPLATES_AUTO_RELOAD=0 to disable).
app.config["TEMPLATES_AUTO_RELOAD"] = os.environ.get(
    "TEMPLATES_AUTO_RELOAD", "true"
).lower() in ("1", "true", "yes")


def empty_board() -> list[str | None]:
    return [None] * 9


def winner_for(board: list[str | None]) -> tuple[str | None, list[int] | None]:
    lines = (
        (0, 1, 2),
        (3, 4, 5),
        (6, 7, 8),
        (0, 3, 6),
        (1, 4, 7),
        (2, 5, 8),
        (0, 4, 8),
        (2, 4, 6),
    )
    for a, b, c in lines:
        x, y, z = board[a], board[b], board[c]
        if x and x == y == z:
            return x, [a, b, c]
    return None, None


def board_full(board: list[str | None]) -> bool:
    return all(cell is not None for cell in board)


def ensure_game() -> dict[str, Any]:
    if "board" not in session:
        session["board"] = empty_board()
        session["turn"] = "X"
        session["winner"] = None
        session["line"] = None
        session["draw"] = False
    return {
        "board": session["board"],
        "turn": session["turn"],
        "winner": session.get("winner"),
        "line": session.get("line"),
        "draw": session.get("draw", False),
    }


def state_payload() -> dict[str, Any]:
    g = ensure_game()
    return {
        "board": g["board"],
        "turn": g["turn"],
        "winner": g["winner"],
        "line": g["line"],
        "draw": bool(g["draw"]),
        "done": bool(g["winner"] or g["draw"]),
    }


@app.route("/health")
def health() -> tuple[str, int]:
    return "ok", 200


@app.route("/")
def index() -> str:
    ensure_game()
    return render_template("index.html")


@app.post("/api/reset")
def api_reset() -> Any:
    session["board"] = empty_board()
    session["turn"] = "X"
    session["winner"] = None
    session["line"] = None
    session["draw"] = False
    session.modified = True
    return jsonify(state_payload())


@app.post("/api/move")
def api_move() -> Any:
    data = request.get_json(silent=True) or {}
    try:
        cell = int(data.get("cell"))
    except (TypeError, ValueError):
        return jsonify({"error": "cell must be an integer 0-8"}), 400
    if cell < 0 or cell > 8:
        return jsonify({"error": "cell out of range"}), 400

    ensure_game()
    board: list[str | None] = list(session["board"])
    if session.get("winner") or session.get("draw"):
        return jsonify({"error": "game over", **state_payload()}), 400
    if board[cell] is not None:
        return jsonify({"error": "cell occupied", **state_payload()}), 400

    turn = session["turn"]
    board[cell] = turn
    w, line = winner_for(board)
    session["board"] = board
    if w:
        session["winner"] = w
        session["line"] = line
        session["draw"] = False
    elif board_full(board):
        session["winner"] = None
        session["line"] = None
        session["draw"] = True
    else:
        session["turn"] = "O" if turn == "X" else "X"
        session["winner"] = None
        session["line"] = None
        session["draw"] = False
    session.modified = True
    return jsonify(state_payload())


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8091"))
    app.run(host="0.0.0.0", port=port, threaded=True)
