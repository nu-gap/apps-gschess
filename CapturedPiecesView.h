#import <AppKit/AppKit.h>
@class ChessGame;

/** Displays captured material and the resulting material advantage. */
@interface CapturedPiecesView : NSView
{
  ChessGame *_game;
  NSImage *_pieces;
}
- (void)setGame:(ChessGame *)game;
@end
