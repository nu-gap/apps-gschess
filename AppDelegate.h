#import <AppKit/AppKit.h>
@class ChessBoardView, ChessGame;
@interface AppDelegate : NSObject <NSApplicationDelegate>
{
  NSWindow *_window;
  ChessBoardView *_board;
  ChessGame *_game;
  NSTextField *_status;
  NSTextView *_history;
  NSButton *_computer;
  NSMenuItem *_computerMenu;
  NSPanel *_infoPanel;
  BOOL _thinking;
}
@end
