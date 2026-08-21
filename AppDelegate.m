#import "AppDelegate.h"
#import "ChessBoardView.h"
#if defined(__APPLE__)
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#endif

#if defined(GNUSTEP)
#define GC_BUTTON_STYLE NSRoundedBezelStyle
#define GC_WINDOW_STYLE                                                       \
  (NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask     \
   | NSResizableWindowMask)
#define GC_PANEL_STYLE (NSTitledWindowMask | NSClosableWindowMask)
#define GC_ON_STATE NSOnState
#define GC_OFF_STATE NSOffState
#else
#define GC_BUTTON_STYLE NSBezelStylePush
#define GC_WINDOW_STYLE                                                       \
  (NSWindowStyleMaskTitled | NSWindowStyleMaskClosable                        \
   | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable)
#define GC_PANEL_STYLE (NSWindowStyleMaskTitled | NSWindowStyleMaskClosable)
#define GC_ON_STATE NSControlStateValueOn
#define GC_OFF_STATE NSControlStateValueOff
#endif

@implementation AppDelegate
- (NSButton *)button:(NSString *)title action:(SEL)action frame:(NSRect)frame
{
  NSButton *b = [[[NSButton alloc] initWithFrame:frame] autorelease];
  [b setTitle:title];
  [b setTarget:self];
  [b setAction:action];
  [b setBezelStyle:GC_BUTTON_STYLE];
  return b;
}
- (NSMenuItem *)menuItem:(NSString *)title
                  action:(SEL)action
                     key:(NSString *)key
{
  NSMenuItem *item = [[[NSMenuItem alloc] initWithTitle:title
                                                 action:action
                                          keyEquivalent:key] autorelease];
  [item setTarget:self];
  return item;
}
- (void)buildMenu
{
  NSMenu *bar = [[NSMenu alloc] initWithTitle:@"Main Menu"];
  NSMenuItem *appRoot = [[NSMenuItem alloc] initWithTitle:@"Grandmaster Chess"
                                                   action:NULL
                                            keyEquivalent:@""];
  [bar addItem:appRoot];
  NSMenu *app = [[NSMenu alloc] initWithTitle:@"Grandmaster Chess"];
  [app addItem:[self menuItem:@"About Grandmaster Chess"
                       action:@selector (showInfo:)
                          key:@""]];
  [app addItem:[NSMenuItem separatorItem]];
  [app addItem:[self menuItem:@"Quit Grandmaster Chess"
                       action:@selector (terminate:)
                          key:@"q"]];
  [appRoot setSubmenu:app];
  NSMenuItem *gameRoot = [[NSMenuItem alloc] initWithTitle:@"Game"
                                                    action:NULL
                                             keyEquivalent:@""];
  [bar addItem:gameRoot];
  NSMenu *game = [[NSMenu alloc] initWithTitle:@"Game"];
  [game addItem:[self menuItem:@"New Game — Play White"
                        action:@selector (newGame:)
                           key:@"n"]];
  [game addItem:[self menuItem:@"New Game — Play Black"
                        action:@selector (newGameBlack:)
                           key:@"b"]];
  [game addItem:[self menuItem:@"Save Game…"
                        action:@selector (saveGame:)
                           key:@"s"]];
  [game addItem:[self menuItem:@"Undo Move"
                        action:@selector (undo:)
                           key:@"z"]];
  [game addItem:[NSMenuItem separatorItem]];
  _computerMenu = [[self menuItem:@"Play Computer"
                           action:@selector (toggleComputer:)
                              key:@"k"] retain];
  [_computerMenu setState:GC_ON_STATE];
  [game addItem:_computerMenu];
  _selfPlayMenu = [[self menuItem:@"Computer vs Computer"
                           action:@selector (toggleSelfPlay:)
                              key:@"d"] retain];
  [_selfPlayMenu setState:GC_OFF_STATE];
  [game addItem:_selfPlayMenu];
  [gameRoot setSubmenu:game];
  NSMenuItem *viewRoot = [[NSMenuItem alloc] initWithTitle:@"View"
                                                    action:NULL
                                             keyEquivalent:@""];
  [bar addItem:viewRoot];
  NSMenu *view = [[NSMenu alloc] initWithTitle:@"View"];
  [view addItem:[self menuItem:@"Flip Board"
                        action:@selector (flip:)
                           key:@"f"]];
  [viewRoot setSubmenu:view];
  [NSApp setMainMenu:bar];
  [bar release];
}
- (void)applicationDidFinishLaunching:(NSNotification *)n
{
  (void)n;
  _game = [ChessGame new];
  [self buildMenu];
  NSString *appIconPath = [[NSBundle mainBundle] pathForResource:@"app-icon"
                                                          ofType:@"png"];
  NSImage *appIcon =
      [[[NSImage alloc] initWithContentsOfFile:appIconPath] autorelease];
  if (appIcon)
    [NSApp setApplicationIconImage:appIcon];
  _window =
      [[NSWindow alloc] initWithContentRect:NSMakeRect (120, 100, 850, 650)
                                  styleMask:GC_WINDOW_STYLE
                                    backing:NSBackingStoreBuffered
                                      defer:NO];
  [_window setTitle:@"Grandmaster Chess"];
  [_window setMinSize:NSMakeSize (700, 540)];
  NSView *c = [_window contentView];
  _board =
      [[ChessBoardView alloc] initWithFrame:NSMakeRect (20, 55, 590, 575)];
  [_board setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
  [_board setGame:_game];
  [_board setDelegate:self];
  [c addSubview:_board];
  _status = [[NSTextField alloc] initWithFrame:NSMakeRect (20, 18, 590, 28)];
  [_status setEditable:NO];
  [_status setBezeled:NO];
  [_status setDrawsBackground:NO];
  [_status setFont:[NSFont boldSystemFontOfSize:16]];
  [_status setAutoresizingMask:NSViewWidthSizable | NSViewMaxYMargin];
  [c addSubview:_status];
  CGFloat x = 630;
  NSArray *buttons =
      [NSArray arrayWithObjects:[self button:@"New: Play White"
                                      action:@selector (newGame:)
                                       frame:NSMakeRect (x, 590, 190, 32)],
                                [self button:@"New: Play Black"
                                      action:@selector (newGameBlack:)
                                       frame:NSMakeRect (x, 550, 190, 32)],
                                [self button:@"Save Game…"
                                      action:@selector (saveGame:)
                                       frame:NSMakeRect (x, 510, 190, 32)],
                                [self button:@"Undo"
                                      action:@selector (undo:)
                                       frame:NSMakeRect (x, 470, 190, 32)],
                                [self button:@"Flip Board"
                                      action:@selector (flip:)
                                       frame:NSMakeRect (x, 430, 190, 32)],
                                nil];
  NSEnumerator *be = [buttons objectEnumerator];
  NSButton *b;
  while ((b = [be nextObject]))
    {
      [b setAutoresizingMask:NSViewMinXMargin | NSViewMinYMargin];
      [c addSubview:b];
    }
  _computer = [[self button:@"Play Computer: On"
                     action:@selector (toggleComputer:)
                      frame:NSMakeRect (x, 390, 190, 32)] retain];
  [_computer setState:GC_ON_STATE];
  [_computer setAutoresizingMask:NSViewMinXMargin | NSViewMinYMargin];
  [c addSubview:_computer];
  _selfPlayButton = [[self button:@"Computer vs Computer: Off"
                           action:@selector (toggleSelfPlay:)
                            frame:NSMakeRect (x, 350, 190, 32)] retain];
  [_selfPlayButton setState:GC_OFF_STATE];
  [_selfPlayButton setAutoresizingMask:NSViewMinXMargin | NSViewMinYMargin];
  [c addSubview:_selfPlayButton];
  NSScrollView *scroll = [[[NSScrollView alloc]
      initWithFrame:NSMakeRect (x, 55, 190, 275)] autorelease];
  [scroll setHasVerticalScroller:YES];
  [scroll setAutoresizingMask:NSViewMinXMargin | NSViewHeightSizable];
  _history = [[NSTextView alloc] initWithFrame:[scroll bounds]];
  [_history setEditable:NO];
  [_history setFont:[NSFont userFixedPitchFontOfSize:13]];
  [scroll setDocumentView:_history];
  [c addSubview:scroll];
  [self refresh];
  [_window center];
  [_window makeKeyAndOrderFront:nil];
  [NSApp activateIgnoringOtherApps:YES];
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
  (void)sender;
  return YES;
}
- (void)refresh
{
  [_status
      setStringValue:_thinking ? @"Computer is thinking…" : [_game status]];
  NSMutableString *s = [NSMutableString string];
  NSArray *h = [_game history];
  for (NSUInteger i = 0; i < [h count]; i += 2)
    {
      [s appendFormat:@"%2lu.  %@", (unsigned long)i / 2 + 1,
                      [h objectAtIndex:i]];
      if (i + 1 < [h count])
        [s appendFormat:@"   %@", [h objectAtIndex:i + 1]];
      [s appendString:@"\n"];
    }
  [_history setString:s];
  [_board setNeedsDisplay:YES];
}
- (void)boardView:(ChessBoardView *)v requestedMove:(GCMove)m
{
  (void)v;
  if (_thinking || [_selfPlayButton state] == GC_ON_STATE
      || ([_computer state] == GC_ON_STATE
          && [_game blackToMove] != _playerBlack))
    return;
  if ([_game makeMove:m])
    {
      [self refresh];
      [self maybeComputer];
    }
}
- (void)maybeComputer
{
  BOOL selfPlay = [_selfPlayButton state] == GC_ON_STATE;
  if ((!selfPlay
       && ([_computer state] != GC_ON_STATE
           || [_game blackToMove] == _playerBlack))
      || [_game gameOver] || _thinking)
    return;
  _thinking = YES;
  _varyComputerMove = selfPlay;
  [self refresh];
  ChessGame *snapshot = [_game copy];
  [NSThread detachNewThreadSelector:@selector (searchThread:)
                           toTarget:self
                         withObject:snapshot];
  [snapshot release];
}
- (void)searchThread:(ChessGame *)snapshot
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  GCMove m = _varyComputerMove
                 ? [snapshot variedOpeningMoveAtDepth:3]
                 : [snapshot bestMoveAtDepth:3];
  [self performSelectorOnMainThread:@selector (finishComputer:)
                         withObject:GCMoveValue (m)
                      waitUntilDone:NO];
  [pool drain];
}
- (void)finishComputer:(NSValue *)value
{
  GCMove m = GCMoveFromValue (value);
  _thinking = NO;
  if (m.from >= 0)
    [_game makeMove:m];
  [self refresh];
  if ([_selfPlayButton state] == GC_ON_STATE && ![_game gameOver])
    [self performSelector:@selector (continueSelfPlay:)
               withObject:nil
               afterDelay:0.8];
  else
    [self maybeComputer];
}
- (void)continueSelfPlay:(id)sender
{
  (void)sender;
  [self maybeComputer];
}
- (void)newGame:(id)sender
{
  (void)sender;
  if (_thinking)
    return;
  _playerBlack = NO;
  [_game reset];
  [_board setFlippedBoard:NO];
  [_board clearSelection];
  [self refresh];
  [self maybeComputer];
}
- (void)newGameBlack:(id)sender
{
  (void)sender;
  if (_thinking)
    return;
  _playerBlack = YES;
  [_game reset];
  [_board setFlippedBoard:YES];
  [_board clearSelection];
  [self refresh];
  [self maybeComputer];
}
- (void)saveGame:(id)sender
{
  (void)sender;
  NSSavePanel *panel = [NSSavePanel savePanel];
  [panel setTitle:@"Save Chess Game"];
#if defined(GNUSTEP)
  [panel setRequiredFileType:@"pgn"];
  if ([panel runModal] == NSOKButton)
    {
      NSError *error = nil;
      BOOL saved = [[_game PGNString] writeToFile:[panel filename]
                                       atomically:YES
                                         encoding:NSUTF8StringEncoding
                                            error:&error];
      if (!saved)
        [NSApp presentError:error];
    }
#else
  [panel
      setAllowedContentTypes:
          [NSArray arrayWithObject:[UTType typeWithFilenameExtension:@"pgn"]]];
  if ([panel runModal] == NSModalResponseOK)
    {
      NSError *error = nil;
      BOOL saved = [[_game PGNString] writeToURL:[panel URL]
                                      atomically:YES
                                        encoding:NSUTF8StringEncoding
                                           error:&error];
      if (!saved)
        [NSApp presentError:error];
    }
#endif
}
- (void)undo:(id)sender
{
  (void)sender;
  if (_thinking)
    return;
  [_game undo];
  if ([_computer state] == GC_ON_STATE
      && [_game blackToMove] != _playerBlack)
    [_game undo];
  [_board clearSelection];
  [self refresh];
}
- (void)flip:(id)sender
{
  (void)sender;
  [_board setFlippedBoard:![_board flippedBoard]];
}
- (void)toggleComputer:(id)sender
{
  (void)sender;
  [_computer
      setState:[_computer state] == GC_ON_STATE ? GC_OFF_STATE : GC_ON_STATE];
  [_computerMenu setState:[_computer state]];
  [_computer setTitle:[_computer state] == GC_ON_STATE
                          ? @"Play Computer: On"
                          : @"Play Computer: Off"];
  [self maybeComputer];
}
- (void)toggleSelfPlay:(id)sender
{
  NSInteger state;
  (void)sender;
  [NSObject cancelPreviousPerformRequestsWithTarget:self
                                           selector:@selector (continueSelfPlay:)
                                             object:nil];
  state = [_selfPlayButton state] == GC_ON_STATE ? GC_OFF_STATE : GC_ON_STATE;
  [_selfPlayButton setState:state];
  [_selfPlayMenu setState:state];
  [_selfPlayButton setTitle:state == GC_ON_STATE
                                ? @"Computer vs Computer: On"
                                : @"Computer vs Computer: Off"];
  [self maybeComputer];
}
- (void)showInfo:(id)sender
{
  (void)sender;
  if (!_infoPanel)
    {
      NSView *content;
      NSImageView *imageView;
      NSTextField *title;
      NSTextField *details;
      NSString *iconPath;
      NSImage *icon;

      _infoPanel =
          [[NSPanel alloc] initWithContentRect:NSMakeRect (0, 0, 480, 270)
                                     styleMask:GC_PANEL_STYLE
                                       backing:NSBackingStoreBuffered
                                         defer:NO];
      [_infoPanel setTitle:@"About Grandmaster Chess"];
      [_infoPanel setReleasedWhenClosed:NO];
      content = [_infoPanel contentView];

      iconPath = [[NSBundle mainBundle] pathForResource:@"app-icon"
                                                 ofType:@"png"];
      icon = [[[NSImage alloc] initWithContentsOfFile:iconPath] autorelease];
      imageView = [[[NSImageView alloc]
          initWithFrame:NSMakeRect (28, 70, 160, 160)] autorelease];
      [imageView setImage:icon ? icon : [NSApp applicationIconImage]];
      [imageView setImageScaling:NSImageScaleProportionallyUpOrDown];
      [content addSubview:imageView];

      title = [[[NSTextField alloc]
          initWithFrame:NSMakeRect (210, 185, 240, 42)] autorelease];
      [title setStringValue:@"Grandmaster Chess"];
      [title setFont:[NSFont boldSystemFontOfSize:24]];
      [title setEditable:NO];
      [title setBezeled:NO];
      [title setDrawsBackground:NO];
      [content addSubview:title];

      details = [[[NSTextField alloc]
          initWithFrame:NSMakeRect (210, 66, 240, 118)] autorelease];
      [details setStringValue:
                   @"Version 1.0\n\nNative chess for GNUstep and macOS.\n"
                   @"Complete legal-move engine with documented negamax "
                   @"alpha-beta computer play.\n\nOriginal artwork generated "
                   @"with OpenAI ImageGen."];
      [details setFont:[NSFont systemFontOfSize:13]];
      [details setEditable:NO];
      [details setSelectable:YES];
      [details setBezeled:NO];
      [details setDrawsBackground:NO];
      [content addSubview:details];
      [_infoPanel center];
    }
  [_infoPanel makeKeyAndOrderFront:nil];
}
- (void)terminate:(id)sender
{
  [NSApp terminate:sender];
}
- (void)dealloc
{
  [_window release];
  [_board release];
  [_game release];
  [_status release];
  [_history release];
  [_computer release];
  [_computerMenu release];
  [_selfPlayButton release];
  [_selfPlayMenu release];
  [_infoPanel release];
  [super dealloc];
}
@end
