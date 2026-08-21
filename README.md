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

## Controls

- Click a piece, then a highlighted destination.
- **New Game** resets the standard position.
- **Save Game…** writes a PGN record containing the moves, result, and current FEN.
- **Undo** takes back the latest pair of moves when playing the computer.
- **Play Computer** toggles the AI (Black by default).
- **Flip Board** changes the viewing orientation.
- Pawn promotion automatically chooses a queen.

## Source map

- `ChessGame.[hm]` — portable rules, position state, notation, and AI search.
- `ChessBoardView.[hm]` — AppKit/GNUstep rendering and mouse interaction.
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
