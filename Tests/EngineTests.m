#import "ChessGame.h"
#import <Foundation/Foundation.h>

static void
require (BOOL condition, NSString *message)
{
  if (!condition)
    {
      NSLog (@"FAIL: %@", message);
      exit (1);
    }
}
static GCMove
move (ChessGame *g, int from, int to)
{
  NSEnumerator *enumerator = [[g legalMovesFrom:from] objectEnumerator];
  NSValue *v;
  while ((v = [enumerator nextObject]))
    {
      GCMove m = GCMoveFromValue (v);
      if (m.to == to)
        return m;
    }
  GCMove none = { -1, -1, 0, 0 };
  return none;
}
int
main (void)
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  ChessGame *g = [[ChessGame alloc] init];
  require ([[g legalMoves] count] == 20,
           @"initial position has 20 legal moves");
  require ([g makeMove:move (g, 12, 28)], @"e2-e4 is legal");
  require ([g blackToMove], @"turn changes after a move");
  require ([g makeMove:move (g, 52, 36)], @"e7-e5 is legal");
  require ([g makeMove:move (g, 6, 21)], @"g1-f3 is legal");
  require ([[g history] count] == 3, @"history records moves");
  NSString *pgn = [g PGNString];
  require ([pgn containsString:@"[CurrentFEN "] &&
               [pgn containsString:@"1. e4 e5"],
           @"PGN save contains position and moves");
  [g undo];
  require ([[g history] count] == 2, @"undo restores history and state");
  GCMove ai = [g bestMoveAtDepth:2];
  require (ai.from >= 0 && ai.to >= 0, @"AI returns a legal move");
  require ([g makeMove:ai], @"AI move can be applied");
  NSLog (@"PASS: rules, undo, notation, and AI smoke tests");
  [g release];
  [pool drain];
  return 0;
}
