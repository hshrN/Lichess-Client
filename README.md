# Lichess Board

Lichess Board is a minimal native iOS client for playing rapid Lichess games through the Board API. It is designed for normal Lichess accounts and must not provide engine analysis, hints, evaluations, opening assistance, or any other outside help during games.

## Current App Slice

The app currently includes:

- A SwiftUI dashboard for stream status and the active game.
- A tappable board UI that stages UCI moves.
- Rapid-only seek presets.
- A reduced single-screen play flow with token setup in a sheet.
- Player and spectator chat UI.
- Token entry screen for future authenticated API calls.
- A `LichessBoardAPI` request builder for core Board API endpoints.

Most UI actions currently update local preview state. Live networking is intentionally isolated behind the API layer so authentication, streaming, and state reconciliation can be added cleanly.

## Lichess Board API Scope

Primary endpoints planned for the app:

- `GET /api/stream/event`
- `POST /api/board/seek`
- `GET /api/board/game/stream/{gameId}`
- `POST /api/board/game/{gameId}/move/{move}`
- `POST /api/board/game/{gameId}/chat`
- `GET /api/board/game/{gameId}/chat`
- `POST /api/board/game/{gameId}/abort`
- `POST /api/board/game/{gameId}/resign`
- `POST /api/board/game/{gameId}/draw/{accept}`
- `POST /api/board/game/{gameId}/takeback/{accept}`
- `POST /api/board/game/{gameId}/claim-victory`
- `POST /api/board/game/{gameId}/claim-draw`

The global event stream should be opened before creating real-time seeks so the app does not miss a fast game-start event.

## Architecture

The current implementation is split into:

- `LichessClientModel`: app state, local action handlers, and preview stream behavior.
- `LichessModels`: strongly typed app models and enums.
- `LichessBoardAPI`: authenticated URL request construction for Board API calls.
- SwiftUI screen files for the board, pairing, challenges, settings, and header.

Recommended next architectural additions:

- `LichessAuthStore`: save and load API tokens from Keychain.
- `NDJSONStreamClient`: consume Lichess newline-delimited JSON streams using `URLSession`.
- `LichessEventDecoder`: decode `gameStart`, `gameFinish`, challenge, `gameFull`, `gameState`, `chatLine`, and `opponentGone` events.
- `GameStateReducer`: merge stream events into local board, clock, chat, and action state.
- `ChessPosition`: derive board position from `initialFen` plus UCI move list.

## Implementation Milestones

1. Store the user API token securely in Keychain.
2. Connect `GET /api/stream/event` and show incoming rapid games and challenges.
3. Connect `GET /api/board/game/stream/{gameId}` and reconcile `gameFull` plus `gameState`.
4. Replace the static board pieces with a FEN/move-derived board model.
5. Validate taps into legal local UCI move candidates without suggesting moves.
6. Submit moves through `POST /api/board/game/{gameId}/move/{move}`.
7. Wire chat, resign, abort, draw, takeback, and claim actions.
8. Add resilient stream reconnect behavior and clear user-facing error states.
9. Add focused unit tests for request construction, NDJSON parsing, and game-state reduction.

## Fair Play Requirements

The app must remain a Board API client only. Do not add:

- Chess engine integration.
- Evaluation bars.
- Best-move hints.
- Opening book suggestions.
- Blunder detection during live games.
- Analysis overlays while a game is active.

Post-game review can be considered later only if it is clearly separated from active play and follows Lichess rules.

## Manual QA Checklist

- Launches on iPhone without layout clipping.
- Token field accepts and hides input.
- Board taps stage a UCI move in the event feed.
- Rapid seek preset buttons add seek events.
- Chat composer adds messages to the selected room.
- Abort and resign buttons update the event feed.
