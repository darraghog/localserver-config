"""Unit tests for tic-tac-toe logic and HTTP API."""

from __future__ import annotations

import pytest

from app import app, board_full, empty_board, winner_for


def test_empty_board_no_winner() -> None:
    b = empty_board()
    assert winner_for(b) == (None, None)
    assert not board_full(b)


def test_row_win_x() -> None:
    b: list[str | None] = ["X", "X", "X", None, "O", None, None, None, None]
    w, line = winner_for(b)
    assert w == "X"
    assert line == [0, 1, 2]


def test_column_win_o() -> None:
    b: list[str | None] = ["O", "X", None, "O", "X", None, "O", None, None]
    w, line = winner_for(b)
    assert w == "O"
    assert line == [0, 3, 6]


def test_diagonal_win() -> None:
    b: list[str | None] = ["X", "O", None, None, "X", "O", None, None, "X"]
    w, line = winner_for(b)
    assert w == "X"
    assert line == [0, 4, 8]


def test_draw_full_board() -> None:
    b: list[str | None] = ["X", "O", "X", "X", "O", "O", "O", "X", "X"]
    assert winner_for(b) == (None, None)
    assert board_full(b)


@pytest.fixture()
def client():
    app.config["TESTING"] = True
    with app.test_client() as c:
        yield c


def test_health(client) -> None:
    r = client.get("/health")
    assert r.status_code == 200
    assert r.data == b"ok"


def test_reset_and_moves(client) -> None:
    r = client.post("/api/reset", json={})
    assert r.status_code == 200
    data = r.get_json()
    assert data["turn"] == "X"
    assert data["board"] == [None] * 9

    r = client.post("/api/move", json={"cell": 4})
    assert r.status_code == 200
    data = r.get_json()
    assert data["board"][4] == "X"
    assert data["turn"] == "O"

    r = client.post("/api/move", json={"cell": 0})
    assert r.status_code == 200
    data = r.get_json()
    assert data["board"][0] == "O"
