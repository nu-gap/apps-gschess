#import "ChessGame.h"
#import <AppKit/AppKit.h>

@class ChessBoardView;
@protocol ChessBoardViewDelegate <NSObject>
- (void)boardView:(ChessBoardView *)view requestedMove:(GCMove)move;
@end

@interface ChessBoardView : NSView
{
  ChessGame *_game;
  id _delegate;
  BOOL _flippedBoard;
  NSInteger _selected;
  NSArray *_targets;
  NSImage *_pieces;
}
/** Sets the chess position displayed by the board. */
- (void)setGame:(ChessGame *)game;
/** Returns the displayed chess position. */
- (ChessGame *)game;
/** Sets the receiver notified when the user requests a move. */
- (void)setDelegate:(id)delegate;
/** Returns the receiver notified when the user requests a move. */
- (id)delegate;
/** Changes the board orientation. */
- (void)setFlippedBoard:(BOOL)flipped;
/** Returns whether Black is displayed at the bottom. */
- (BOOL)flippedBoard;
/** Clears the selection and legal-move markers. */
- (void)clearSelection;
@end
