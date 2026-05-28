# Lichess Board

Lichess Board is a minimal native iOS client for playing rapid Lichess games through the Board API. It is designed for normal Lichess accounts and must not provide engine analysis, hints, evaluations, opening assistance, or any other outside help during games.

## Current App Slice

The app currently includes:

- A richer iOS dashboard with play controls, following challenges, challenge inbox, activity, and Lichess account status.
- A live board UI backed by ChessKit and updated from Lichess game streams.
- Rapid-only seek presets that map to Lichess Board API seeks.
- Following list and direct challenge UI for players the user follows.
- Bot play panel for challenging online bot accounts.
- Challenge inbox preview for incoming/outgoing challenge state.
- A board screen that appears only after a search/game starts.
- Player and spectator chat UI.
- Native Lichess OAuth sign-in using the authorization code flow with PKCE and Keychain-backed session storage.
- Appearance setting for System, Light, and Dark modes.
- `THIRD_PARTY_NOTICES.md` for dependency license tracking.
- A `LichessBoardAPI` request builder for core Board API endpoints.

The app now has a mixed state:

- Live OAuth sign-in and token revocation
- Live event stream
- Live public seek requests
- Live direct challenges to followed players and online bot accounts
- Live online bot list refresh
- Live per-game board stream with clock, status, chat-line, and move-list updates
- Live move submission
- Live chat submission
- Live abort and resign actions
- Seek timeout after 90 seconds if no public match is found
- Challenge declined/canceled handling from the Lichess event stream

Some flows are still incomplete, especially draw/takeback/claim actions, promotion choice UI, stronger seek/challenge UX, and robust reconnect handling.

## Authentication

The app now uses Lichess OAuth instead of manual token entry.

- Authorization endpoint: `https://lichess.org/oauth`
- Token endpoint: `https://lichess.org/api/token`
- Flow: authorization code with PKCE (`S256`)
- Redirect URI: `app.bitrig.new.f3424c4c-db54-418d-aa5d-426ff1c3f9a7://oauth-callback`
- Scopes currently requested: `board:play`, `challenge:read`, `challenge:write`

This follows the public-client guidance used by the official Lichess API demo app.
The OAuth session is now stored in the iOS Keychain. Older `UserDefaults` sessions are migrated once and then cleared.

## Lichess Board API Constraints

This app must use the official Lichess Board API for playing moves. Lichess warns that clients not using the official Board API for board-style play can put accounts at risk.

Supported Board API time controls:

- Rapid
- Classical
- Correspondence
- Blitz only for direct challenges, games vs AI, or bulk pairing challenges

Not supported for normal public Board API seeking:

- Bullet
- UltraBullet
- General blitz pool seeking

Fair-play constraints:

- Real-time Board API games must not show engines, opening explorers, opening books, endgame tablebases, advice, evaluations, best moves, or hints.
- Correspondence Board API games may use opening books/databases and Lichess opening explorer, but not engines, tablebases, outside advice, or move recommendations.
- Programmatic moves are allowed only through the official Board API or Bot API, not browser automation.
- API clients should make one request at a time and wait a full minute after HTTP `429` before resuming.

Reference pages:

- https://lichess.org/page/eboards
- https://lichess.org/page/fair-play
- https://lichess.org/page/api-tips
- https://lichess-org.github.io/api/

Dependency notices are tracked in `THIRD_PARTY_NOTICES.md`.

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
- `GET /api/rel/following`
- `GET /api/challenge`
- `POST /api/challenge/{username}`
- `POST /api/challenge/{challengeId}/accept`
- `POST /api/challenge/{challengeId}/decline`
- `GET /api/bot/online`

The global event stream should be opened before creating real-time seeks so the app does not miss a fast game-start event.
The app now opens the event stream and transitions into a game screen on `gameStart`, then opens the per-game stream and rebuilds the board from `initialFen` plus UCI move history.

## Chess Library Research

The app should not hand-roll chess rules. We need a rules library for board state, local move validation, FEN parsing, promotion, castling, en passant, check state, and game-end state. This is not engine assistance as long as it is only used to validate and render the user’s own legal moves.

Recommended option:

- `chesskit-app/chesskit-swift`
- URL: https://github.com/chesskit-app/chesskit-swift
- Swift Package Manager compatible.
- MIT license.
- Distribution allowed, including commercial distribution, as long as the MIT copyright and permission notice are included with substantial copies of the software.
- Swift-native.
- Supports board representation, legal move validation, making moves, FEN parsing, PGN parsing, SAN parsing, promotion, castling, en passant, check, stalemate, checkmate, and draws.
- Does not require bundling Stockfish or an evaluation engine.

Secondary option:

- `aperechnev/ChessKit`
- URL: https://github.com/aperechnev/ChessKit
- Swift Package Manager compatible.
- Lightweight Swift chess framework.
- Appears useful for legal moves and FEN/PGN basics, but needs deeper API review before choosing it over `chesskit-app/chesskit-swift`.

UI-adjacent option:

- `rohanrhu/ChessboardKit`
- URL: https://github.com/rohanrhu/ChessboardKit
- SwiftUI chessboard package built around ChessKit.
- Could accelerate board interaction, but we should be careful: the app needs a custom native Lichess feel, so a full board UI dependency may be less valuable than using ChessKit for rules and keeping our own board view.

Recommended path:

1. Add `chesskit-app/chesskit-swift`. Done.
2. Replace the current static board array with a `ChessKit` position initialized from Lichess `initialFen`. Started with a standard `Board()`.
3. Replay Lichess UCI moves from `gameState.moves`.
4. Use legal moves only to drive tap targets and reject impossible input. Started.
5. Send the selected legal move to Lichess as UCI.
6. Never expose engine evaluation, best-move ranking, opening-book help, or analysis during active games.

## Architecture

The current implementation is split into:

- `LichessClientModel`: app state, OAuth session handling, live Lichess networking, and stream reconciliation.
- `LichessModels`: strongly typed app models and enums.
- `LichessBoardAPI`: authenticated URL request construction for Board API calls and challenge flows.
- Challenge/following request builders for `GET /api/rel/following`, `GET /api/challenge`, direct challenge creation, accept, and decline.
- Bot-play request builders for `GET /api/bot/online` and direct bot challenges through `POST /api/challenge/{username}`.
- SwiftUI screen files for the board, pairing, challenges, settings, and header.

Recommended next architectural additions:

- `LichessAuthStore`: Keychain-backed OAuth session storage.
- A dedicated stream client abstraction to separate `URLSession.AsyncBytes` handling from UI state.
- Stronger event decoding for the full Lichess event surface, including validation and error reporting.
- A separate game-state reducer to keep stream parsing and UI state mutation isolated.
- `ChessPosition`: derive board position from `initialFen` plus UCI move list.

## Implementation Milestones

1. Add draw, takeback, and claim action endpoints to the live game UI.
2. Add promotion choice UI instead of defaulting promotions to queen.
3. Improve seek/challenge UX so pending bot and public match flows are clearer and more actionable.
4. Improve event/game stream reconnect behavior and cancellation semantics.
5. Replace the remaining ad hoc JSON parsing with stronger typed decoding.
6. Add focused unit tests for request construction, NDJSON parsing, and game-state reduction.

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
- Lichess sign-in opens OAuth and returns to the app.
- Signing in starts the event stream without manual token entry.
- Appearance picker switches between System, Light, and Dark.
- Home screen starts with Play, not a chessboard.
- Rapid seek preset buttons create real seek requests and can be canceled.
- Public seeks stop after 90 seconds and show a failure event if no match is found.
- Bot/following challenge buttons create real challenge requests.
- Declined and canceled challenges update from the Lichess event stream.
- A `gameStart` event opens the game screen.
- `gameFull` and `gameState` update the board, clocks, and status.
- Tapping a legal move sends a real move request to Lichess.
- Chat composer sends real player/spectator chat messages.
- Abort and resign buttons send real game actions.
