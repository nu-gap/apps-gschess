#import <AppKit/AppKit.h>
@class ChessBoardView, ChessGame, CapturedPiecesView;
@interface AppDelegate : NSObject <NSApplicationDelegate>
{
  NSWindow *_window;
  ChessBoardView *_board;
  CapturedPiecesView *_captured;
  ChessGame *_game;
  NSTextField *_status;
  NSTextView *_history;
  NSButton *_computer;
  NSMenuItem *_computerMenu;
  NSButton *_selfPlayButton;
  NSMenuItem *_selfPlayMenu;
  NSMenuItem *_soundEffectsMenu;
  NSButton *_speechButton;
  NSMenuItem *_speechMenu;
  NSMenuItem *_teachingThreatsMenu;
  id _speechSynthesizer;
  NSMutableArray *_speechQueue;
  NSTask *_speechTask;
  NSSound *_whiteMoveSound;
  NSSound *_blackMoveSound;
  NSPanel *_infoPanel;
  BOOL _thinking;
  BOOL _playerBlack;
  BOOL _varyComputerMove;
  BOOL _soundEffects;
  BOOL _speechEnabled;
  BOOL _teachingThreatsEnabled;
  BOOL _speechActive;
  BOOL _observingComputerMove;
  BOOL _waitingForComputer;
}
@end
