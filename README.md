# Grandmaster Chess

A native Objective-C chess application that builds with either macOS AppKit or
GNUstep.  It contains a complete legal-move engine, a small alpha-beta chess AI,
undo/new-game controls, board flipping, move history, and generated artwork for
all twelve piece/color combinations.

The source intentionally uses the Objective-C 1.0 language surface and manual
reference counting for compatibility with the traditional GNU runtime. Public
APIs use autogsdoc-compatible `/** ... */` documentation comments without
documentation commands, and all Objective-C sources follow GNU formatting.

## Build and run

### macOS

```sh
make mac
open build/GrandmasterChess.app
```

The macOS target uses only the system Cocoa framework; Xcode is not required.

### GNUstep

Install GNUstep's development environment, source its shell setup script if your
distribution requires it, then run:

```sh
make gnustep
openapp GrandmasterChess.app     # or: ./GrandmasterChess.app/GrandmasterChess
```

`Makefile.gnustep` uses `gnustep-make` and the standard `application.make` rules.

## How the chess algorithm works

The rules engine stores the board as a flat 64-byte array.  A byte is `0` for an
empty square; otherwise its low three bits identify pawn/knight/bishop/rook/queen/
king and bit 3 identifies Black.  This compact representation makes copying a
position inexpensive, which matters because search creates many temporary boards.

Move generation deliberately has two stages:

1. `pseudoLegalMoves` applies each piece's geometric movement rules.  Sliding
   pieces trace rays until blocked; pawns add pushes, captures, promotions and en
   passant; the king adds ordinary moves and castling candidates.
2. `legalMoves` applies every candidate to a copy and rejects it if the moving
   side's king is attacked.  This single filter handles pins, discovered checks,
   illegal king moves and en-passant discovered checks without special cases.

Castling rights are four bits and are cleared when a king or rook moves or when a
rook is captured on its home square.  The en-passant field contains the capturable
destination square for one ply.  A four-field snapshot (board, rights, en-passant,
side-to-move) is pushed before every real move, giving exact undo.

Position history follows FIDE Laws of Chess Articles 9.2 and 9.6.1. Position
identity includes piece placement, side to move, castling rights, and en-passant
only when a legal en-passant capture exists. A third occurrence permits a player
to claim a draw under FIDE rules; the fifth occurrence ends the game automatically.
The application enforces the automatic fivefold rule, including during computer
self-play, so repeating engines cannot continue indefinitely.

The computer uses depth-limited **negamax with alpha-beta pruning**.  Negamax is
minimax written using the identity `score(position, side) = -score(position,
opponent)`, so only one maximizing routine is necessary.  Alpha and beta track the
best guaranteed score for each side.  When alpha reaches beta, remaining moves at
that node cannot affect the result and are skipped.  Moves are ordered with
promotions and captures first, which causes cutoffs earlier.

At leaf nodes, evaluation sums material (pawn 100, knight 320, bishop 330, rook
500, queen 900), modest centralization bonuses, and legal mobility.  Checkmate is
scored near ±100,000 with a ply adjustment so the engine prefers faster mates and
delays unavoidable ones.  The default depth is 3: intentionally modest so it stays
responsive on GNUstep as well as macOS.  Search runs on a background thread; UI
updates return to the main thread.

During computer self-play, the first twelve plies are selected from up to four
near-best candidates within half a pawn of the engine's top choice.  This adds
opening variety without deliberately choosing weak moves.  Player-versus-computer
games continue to use the single best move.  Self-play also pauses briefly after
each move so the resulting position can be observed before the next search.
The same observation pause follows computer moves in player-versus-computer
games.  The computer also waits briefly after the player's move before beginning
its response, and the most recent opposing move is selected in the move history.

## Controls

- Click a piece, then a highlighted destination.
- **New: Play White** resets the standard position with the player as White.
- **New: Play Black** resets the standard position with the player as Black;
  White still moves first, so the computer makes the opening move.
- **Save Game…** writes a PGN record containing the moves, result, and current FEN.
- **Undo** takes back the latest pair of moves when playing the computer.
- **Resign** ends the game and awards the win to the opposing color.
- **Play Computer** toggles the AI (the opposite of the selected player color).
- **Computer vs Computer** continuously lets the AI play both colors.
- **Sound Effects** toggles the White-move tick and Black-move tock sounds; the
  preference is enabled by default and saved between launches.
- **Flip Board** changes the viewing orientation.
- Pawn promotion automatically chooses a queen.

## Source map

- `ChessGame.[hm]` — portable rules, position state, notation, and AI search.
- `ChessBoardView.[hm]` — AppKit/GNUstep rendering and mouse interaction.
- `CapturedPiecesView.[hm]` — captured material icons and score bar.
- `AppDelegate.m` — window, controls, history, and background AI coordination.
- `Resources/pieces.png` — generated transparent 4×3 sprite sheet.
- `Resources/app-icon.png` / `.icns` — generated application icon artwork.

## Artwork

The original sprite sheet was generated for this project with OpenAI ImageGen.
Prompt: “A transparent 4×3 sprite sheet of a complete modern Staunton chess set,
warm ivory and deep slate, crisp polished 2D digital illustration, consistent
front view, scale, baseline and lighting; no board, grid, text or watermark.”

The application icon was also generated with OpenAI ImageGen: “A refined square
desktop icon with one warm-ivory chess knight over a deep slate and walnut chessboard,
dimensional modern Staunton style, subtle gold accent, no text or watermark.”
