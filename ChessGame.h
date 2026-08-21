#import <Foundation/Foundation.h>

typedef enum
{
  GCEmpty = 0,
  GCPawn = 1,
  GCKnight = 2,
  GCBishop = 3,
  GCRook = 4,
  GCQueen = 5,
  GCKing = 6,
  GCBlack = 8
} GCPiece;

typedef struct
{
  int8_t from, to, promotion;
  uint8_t flags;
} GCMove;
enum
{
  GCCapture = 1,
  GCEnPassant = 2,
  GCCastle = 4,
  GCPromotion = 8
};
typedef struct
{
  uint8_t board[64], rights;
  int8_t ep;
  BOOL black;
} GCPosition;

static inline NSValue *
GCMoveValue (GCMove m)
{
  return [NSValue value:&m withObjCType:@encode (GCMove)];
}
static inline GCMove
GCMoveFromValue (NSValue *v)
{
  GCMove m;
  [v getValue:&m];
  return m;
}

/** A complete mutable chess position and its move history.

    Legal moves are produced in two stages. Piece geometry first creates
    candidates, then each candidate is applied to a copy and rejected if it
    leaves its own king attacked.
 */
@interface ChessGame : NSObject <NSCopying>
{
  GCPosition _p;
  NSMutableArray *_undo;
  NSMutableArray *_mutableHistory;
}
/** Returns whether Black is the side to move. */
- (BOOL)blackToMove;
/** Returns whether the current game has ended. */
- (BOOL)gameOver;
/** Returns a human-readable description of the current state. */
- (NSString *)status;
/** Returns an immutable copy of the algebraic move history. */
- (NSArray *)history;
/** Returns the piece byte stored at a square numbered from zero to 63. */
- (uint8_t)pieceAt:(NSInteger)square;
/** Returns every legal move for the side to move. */
- (NSArray *)legalMoves;
/** Returns every legal move beginning on the supplied square. */
- (NSArray *)legalMovesFrom:(NSInteger)square;
/** Applies a legal move and records it for undo and PGN export. */
- (BOOL)makeMove:(GCMove)move;
/** Restores the position preceding the latest move. */
- (void)undo;
/** Restores the standard initial chess position. */
- (void)reset;
/** Searches using depth-limited negamax with alpha-beta pruning. */
- (GCMove)bestMoveAtDepth:(NSInteger)depth;
/** Returns a PGN record containing moves, result, and current FEN. */
- (NSString *)PGNString;
@end
