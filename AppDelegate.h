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
  NSButton *_selfPlayButton;
  NSMenuItem *_selfPlayMenu;
  NSPanel *_infoPanel;
  BOOL _thinking;
  BOOL _playerBlack;
  BOOL _varyComputerMove;
}
@end
