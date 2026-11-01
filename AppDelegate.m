#import "AppDelegate.h"
#import "CapturedPiecesView.h"
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

static void
appendUInt16 (NSMutableData *data, uint16_t value)
{
  uint8_t bytes[2] = { value & 255, (value >> 8) & 255 };
  [data appendBytes:bytes length:2];
}
static void
appendUInt32 (NSMutableData *data, uint32_t value)
{
  uint8_t bytes[4] = { value & 255, (value >> 8) & 255, (value >> 16) & 255,
                       (value >> 24) & 255 };
  [data appendBytes:bytes length:4];
}
static NSSound *
moveSound (NSUInteger frequency, NSTimeInterval duration)
{
  const NSUInteger sampleRate = 22050;
  NSUInteger sampleCount = (NSUInteger)(sampleRate * duration);
  uint32_t dataSize = (uint32_t)(sampleCount * 2);
  NSMutableData *wave = [NSMutableData dataWithCapacity:44 + dataSize];
  [wave appendBytes:"RIFF" length:4];
  appendUInt32 (wave, 36 + dataSize);
  [wave appendBytes:"WAVEfmt " length:8];
  appendUInt32 (wave, 16);
  appendUInt16 (wave, 1);
  appendUInt16 (wave, 1);
  appendUInt32 (wave, (uint32_t)sampleRate);
  appendUInt32 (wave, (uint32_t)(sampleRate * 2));
  appendUInt16 (wave, 2);
  appendUInt16 (wave, 16);
  [wave appendBytes:"data" length:4];
  appendUInt32 (wave, dataSize);
  NSUInteger period = MAX ((NSUInteger)2, sampleRate / frequency);
  for (NSUInteger i = 0; i < sampleCount; i++)
    {
      NSInteger position = (NSInteger)(i % period);
      NSInteger half = (NSInteger)period / 2;
      NSInteger triangle
          = position < half ? position : (NSInteger)period - position;
      NSInteger centered = triangle * 2 - half;
      NSInteger envelope = (NSInteger)(sampleCount - i);
      int16_t sample = (int16_t)(centered * 24000 / MAX ((NSInteger)1, half)
                                 * envelope / (NSInteger)sampleCount);
      appendUInt16 (wave, (uint16_t)sample);
    }
  return [[[NSSound alloc] initWithData:wave] autorelease];
}
static NSString *
moveSquareName (int square)
{
  return [NSString
      stringWithFormat:@"%c%d", 'a' + (square & 7), (square >> 3) + 1];
}
static NSString *
moveDescription (ChessGame *game, GCMove move)
{
  uint8_t piece = [game pieceAt:move.from];
  NSArray *names =
      [NSArray arrayWithObjects:@"", @"Pawn", @"Knight", @"Bishop", @"Rook",
                                @"Queen", @"King", nil];
  if (move.flags & GCCastle)
    return move.to > move.from ? @"Castle king side" : @"Castle queen side";
  return [NSString
      stringWithFormat:@"%@ from %@ to %@%@", [names objectAtIndex:piece & 7],
                       moveSquareName (move.from), moveSquareName (move.to),
                       (move.flags & GCCapture) ? @", capturing" : @""];
}

@implementation AppDelegate
- (NSButton *)button:(NSString *)title action:(SEL)action frame:(NSRect)frame
{
  NSButton *b = [[[NSButton alloc] initWithFrame:frame] autorelease];
  [b setTitle:title];
  [b setTarget:self];
  [b setAction:action];
  [b setBezelStyle:GC_BUTTON_STYLE];
  [b setFont:[NSFont systemFontOfSize:22]];
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
#if !defined(GNUSTEP)
  [app addItem:[NSMenuItem separatorItem]];
  [app addItem:[self menuItem:@"Quit Grandmaster Chess"
                       action:@selector (terminate:)
                          key:@"q"]];
#endif
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
  [game addItem:[self menuItem:@"Suggest Move"
                        action:@selector (suggestMove:)
                           key:@"h"]];
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
  [game addItem:[NSMenuItem separatorItem]];
  _soundEffectsMenu = [[self menuItem:@"Sound Effects"
                               action:@selector (toggleSoundEffects:)
                                  key:@""] retain];
  [_soundEffectsMenu setState:_soundEffects ? GC_ON_STATE : GC_OFF_STATE];
  [game addItem:_soundEffectsMenu];
  _speechMenu = [[self menuItem:@"Announce Moves"
                         action:@selector (toggleSpeech:)
                            key:@""] retain];
  [_speechMenu setState:_speechEnabled ? GC_ON_STATE : GC_OFF_STATE];
  [game addItem:_speechMenu];
  _teachingThreatsMenu = [[self menuItem:@"Teaching: Show Move Threats"
                                  action:@selector (toggleTeachingThreats:)
                                     key:@""] retain];
  [_teachingThreatsMenu setState:_teachingThreatsEnabled ? GC_ON_STATE
                                                        : GC_OFF_STATE];
  [game addItem:_teachingThreatsMenu];
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
#if defined(GNUSTEP)
  [bar addItem:[NSMenuItem separatorItem]];
  [bar addItem:[self menuItem:@"Quit Grandmaster Chess"
                       action:@selector (terminate:)
                          key:@"q"]];
#endif
  [NSApp setMainMenu:bar];
  [bar release];
}
- (void)applicationDidFinishLaunching:(NSNotification *)n
{
  (void)n;
  _game = [ChessGame new];
  id soundPreference = [[NSUserDefaults standardUserDefaults]
      objectForKey:@"GCSoundEffectsEnabled"];
  _soundEffects = soundPreference ? [soundPreference boolValue] : YES;
  id speechPreference =
      [[NSUserDefaults standardUserDefaults] objectForKey:@"GCSpeechEnabled"];
  _speechEnabled = speechPreference ? [speechPreference boolValue] : NO;
  id teachingPreference = [[NSUserDefaults standardUserDefaults]
      objectForKey:@"GCTeachingThreatsEnabled"];
  _teachingThreatsEnabled =
      teachingPreference ? [teachingPreference boolValue] : NO;
  _whiteMoveSound = [moveSound (920, 0.07) retain];
  _blackMoveSound = [moveSound (360, 0.14) retain];
  [self buildMenu];
  NSString *appIconPath = [[NSBundle mainBundle] pathForResource:@"app-icon"
                                                          ofType:@"png"];
  NSImage *appIcon =
      [[[NSImage alloc] initWithContentsOfFile:appIconPath] autorelease];
  if (appIcon)
    [NSApp setApplicationIconImage:appIcon];
  _window =
      [[NSWindow alloc] initWithContentRect:NSMakeRect (80, 50, 1700, 1300)
                                  styleMask:GC_WINDOW_STYLE
                                    backing:NSBackingStoreBuffered
                                      defer:NO];
  [_window setTitle:@"Grandmaster Chess"];
  [_window setMinSize:NSMakeSize (1400, 1080)];
  NSView *c = [_window contentView];
  _board =
      [[ChessBoardView alloc] initWithFrame:NSMakeRect (40, 224, 1180, 1036)];
  [_board setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
  [_board setGame:_game];
  [_board setDelegate:self];
  [_board setTeachingThreatsEnabled:_teachingThreatsEnabled];
  [c addSubview:_board];
  [_window setAcceptsMouseMovedEvents:YES];
  _captured = [[CapturedPiecesView alloc]
      initWithFrame:NSMakeRect (40, 110, 1180, 96)];
  [_captured setAutoresizingMask:NSViewWidthSizable | NSViewMaxYMargin];
  [_captured setGame:_game];
  [c addSubview:_captured];
  _status = [[NSTextField alloc] initWithFrame:NSMakeRect (40, 36, 1180, 56)];
  [_status setEditable:NO];
  [_status setBezeled:NO];
  [_status setDrawsBackground:NO];
  [_status setFont:[NSFont boldSystemFontOfSize:32]];
  [_status setAutoresizingMask:NSViewWidthSizable | NSViewMaxYMargin];
  [c addSubview:_status];
  CGFloat x = 1260;
  NSArray *buttons =
      [NSArray arrayWithObjects:[self button:@"New: Play White"
                                      action:@selector (newGame:)
                                       frame:NSMakeRect (x, 1180, 380, 64)],
                                [self button:@"New: Play Black"
                                      action:@selector (newGameBlack:)
                                       frame:NSMakeRect (x, 1100, 380, 64)],
                                [self button:@"Save Game…"
                                      action:@selector (saveGame:)
                                       frame:NSMakeRect (x, 1020, 380, 64)],
                                [self button:@"Undo"
                                      action:@selector (undo:)
                                       frame:NSMakeRect (x, 940, 380, 64)],
                                [self button:@"Flip Board"
                                      action:@selector (flip:)
                                       frame:NSMakeRect (x, 860, 380, 64)],
                                [self button:@"Resign"
                                      action:@selector (resign:)
                                       frame:NSMakeRect (x, 780, 380, 64)],
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
                      frame:NSMakeRect (x, 700, 380, 64)] retain];
  [_computer setState:GC_ON_STATE];
  [_computer setAutoresizingMask:NSViewMinXMargin | NSViewMinYMargin];
  [c addSubview:_computer];
  _selfPlayButton = [[self button:@"Computer vs Computer: Off"
                           action:@selector (toggleSelfPlay:)
                            frame:NSMakeRect (x, 620, 380, 64)] retain];
  [_selfPlayButton setState:GC_OFF_STATE];
  [_selfPlayButton setAutoresizingMask:NSViewMinXMargin | NSViewMinYMargin];
  [c addSubview:_selfPlayButton];
  NSButton *suggestButton = [self button:@"Suggest Move"
                                  action:@selector (suggestMove:)
                                   frame:NSMakeRect (x, 540, 380, 64)];
  [suggestButton setAutoresizingMask:NSViewMinXMargin | NSViewMinYMargin];
  [c addSubview:suggestButton];
  _speechButton = [[self button:@"Announce Moves: Off"
                         action:@selector (toggleSpeech:)
                          frame:NSMakeRect (x, 460, 380, 64)] retain];
  [_speechButton setState:_speechEnabled ? GC_ON_STATE : GC_OFF_STATE];
  [_speechButton setTitle:_speechEnabled ? @"Announce Moves: On"
                                         : @"Announce Moves: Off"];
  [_speechButton setAutoresizingMask:NSViewMinXMargin | NSViewMinYMargin];
  [c addSubview:_speechButton];
  NSScrollView *scroll = [[[NSScrollView alloc]
      initWithFrame:NSMakeRect (x, 80, 380, 340)] autorelease];
  [scroll setHasVerticalScroller:YES];
  [scroll setAutoresizingMask:NSViewMinXMargin | NSViewHeightSizable];
  _history = [[NSTextView alloc] initWithFrame:[scroll bounds]];
  [_history setEditable:NO];
  [_history setFont:[NSFont userFixedPitchFontOfSize:26]];
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
  [_status setStringValue:_thinking && ![_game gameOver]
                              ? @"Computer is thinking…"
                              : [_game status]];
  NSMutableString *s = [NSMutableString string];
  NSArray *h = [_game history];
  NSRange opponentRange = NSMakeRange (NSNotFound, 0);
  BOOL selfPlay = [_selfPlayButton state] == GC_ON_STATE;
  for (NSUInteger i = 0; i < [h count]; i += 2)
    {
      [s appendFormat:@"%2lu.  ", (unsigned long)i / 2 + 1];
      NSRange whiteRange
          = NSMakeRange ([s length], [[h objectAtIndex:i] length]);
      [s appendString:[h objectAtIndex:i]];
      if (selfPlay || _playerBlack)
        opponentRange = whiteRange;
      if (i + 1 < [h count])
        {
          [s appendString:@"   "];
          NSRange blackRange
              = NSMakeRange ([s length], [[h objectAtIndex:i + 1] length]);
          [s appendString:[h objectAtIndex:i + 1]];
          if (selfPlay || !_playerBlack)
            opponentRange = blackRange;
        }
      [s appendString:@"\n"];
    }
  [_history setString:s];
  if (opponentRange.location != NSNotFound)
    {
      [_history setSelectedRange:opponentRange];
      [_history scrollRangeToVisible:opponentRange];
    }
  else
    [_history setSelectedRange:NSMakeRange (0, 0)];
  [_board setNeedsDisplay:YES];
  [_captured setNeedsDisplay:YES];
}
- (void)boardView:(ChessBoardView *)v requestedMove:(GCMove)m
{
  (void)v;
  if (_thinking || _observingComputerMove || _waitingForComputer ||
      [_selfPlayButton state] == GC_ON_STATE
      || ([_computer state] == GC_ON_STATE &&
          [_game blackToMove] != _playerBlack))
    return;
  BOOL movedBlack = [_game blackToMove];
  NSString *spokenMove = moveDescription (_game, m);
  if ([_game makeMove:m])
    {
      [self playMoveSoundForBlack:movedBlack];
      [self announceMove:spokenMove];
      [self refresh];
      if ([_computer state] == GC_ON_STATE && ![_game gameOver] &&
          [_game blackToMove] != _playerBlack)
        {
          _waitingForComputer = YES;
          [self performSelector:@selector (beginComputerResponse:)
                     withObject:nil
                     afterDelay:0.8];
        }
      else
        [self maybeComputer];
    }
}
- (void)beginComputerResponse:(id)sender
{
  (void)sender;
  _waitingForComputer = NO;
  [self maybeComputer];
}
- (void)maybeComputer
{
  BOOL selfPlay = [_selfPlayButton state] == GC_ON_STATE;
  if ((!selfPlay
       && ([_computer state] != GC_ON_STATE ||
           [_game blackToMove] == _playerBlack))
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
  GCMove m = _varyComputerMove ? [snapshot variedOpeningMoveAtDepth:3]
                               : [snapshot bestMoveAtDepth:3];
  [self performSelectorOnMainThread:@selector (finishComputer:)
                         withObject:GCMoveValue (m)
                      waitUntilDone:NO];
  [pool drain];
}
- (void)finishComputer:(NSValue *)value
{
  GCMove m = GCMoveFromValue (value);
  NSString *spokenMove = m.from >= 0 ? moveDescription (_game, m) : nil;
  BOOL movedBlack = [_game blackToMove];
  BOOL moved = NO;
  _thinking = NO;
  if (m.from >= 0 && [_game makeMove:m])
    {
      moved = YES;
      [self playMoveSoundForBlack:movedBlack];
      [self announceMove:spokenMove];
      [_board clearSelection];
    }
  BOOL selfPlay = [_selfPlayButton state] == GC_ON_STATE;
  if (moved && !selfPlay && ![_game gameOver])
    _observingComputerMove = YES;
  [self refresh];
  if (selfPlay && ![_game gameOver])
    [self performSelector:@selector (continueSelfPlay:)
               withObject:nil
               afterDelay:0.8];
  else if (_observingComputerMove)
    [self performSelector:@selector (endComputerMovePause:)
               withObject:nil
               afterDelay:0.8];
  else
    [self maybeComputer];
}
- (void)endComputerMovePause:(id)sender
{
  (void)sender;
  _observingComputerMove = NO;
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
  [NSObject
      cancelPreviousPerformRequestsWithTarget:self
                                     selector:@selector (endComputerMovePause:)
                                       object:nil];
  [NSObject cancelPreviousPerformRequestsWithTarget:self
                                           selector:@selector
                                           (beginComputerResponse:)
                                             object:nil];
  _observingComputerMove = NO;
  _waitingForComputer = NO;
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
  [NSObject
      cancelPreviousPerformRequestsWithTarget:self
                                     selector:@selector (endComputerMovePause:)
                                       object:nil];
  [NSObject cancelPreviousPerformRequestsWithTarget:self
                                           selector:@selector
                                           (beginComputerResponse:)
                                             object:nil];
  _observingComputerMove = NO;
  _waitingForComputer = NO;
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
  [NSObject cancelPreviousPerformRequestsWithTarget:self
                                           selector:@selector
                                           (beginComputerResponse:)
                                             object:nil];
  _waitingForComputer = NO;
  [_game undo];
  if ([_computer state] == GC_ON_STATE && [_game blackToMove] != _playerBlack)
    [_game undo];
  [_board clearSelection];
  [self refresh];
}
- (void)resign:(id)sender
{
  (void)sender;
  if ([_game gameOver])
    return;
  [NSObject
      cancelPreviousPerformRequestsWithTarget:self
                                     selector:@selector (continueSelfPlay:)
                                       object:nil];
  [NSObject cancelPreviousPerformRequestsWithTarget:self
                                           selector:@selector
                                           (beginComputerResponse:)
                                             object:nil];
  _waitingForComputer = NO;
  BOOL selfPlay = [_selfPlayButton state] == GC_ON_STATE;
  [_game resignBlack:selfPlay ? [_game blackToMove] : _playerBlack];
  if (selfPlay)
    {
      [_selfPlayButton setState:GC_OFF_STATE];
      [_selfPlayMenu setState:GC_OFF_STATE];
      [_selfPlayButton setTitle:@"Computer vs Computer: Off"];
    }
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
  if ([_computer state] != GC_ON_STATE)
    {
      [NSObject cancelPreviousPerformRequestsWithTarget:self
                                               selector:@selector
                                               (beginComputerResponse:)
                                                 object:nil];
      _waitingForComputer = NO;
    }
  [self maybeComputer];
}
- (void)toggleSelfPlay:(id)sender
{
  NSInteger state;
  (void)sender;
  [NSObject
      cancelPreviousPerformRequestsWithTarget:self
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
- (void)playMoveSoundForBlack:(BOOL)black
{
  if (!_soundEffects)
    return;
  NSSound *sound = black ? _blackMoveSound : _whiteMoveSound;
  if (sound)
    {
      [sound stop];
      [sound play];
    }
  else
    NSBeep ();
}
- (void)toggleSoundEffects:(id)sender
{
  (void)sender;
  _soundEffects = !_soundEffects;
  [_soundEffectsMenu setState:_soundEffects ? GC_ON_STATE : GC_OFF_STATE];
  [[NSUserDefaults standardUserDefaults] setBool:_soundEffects
                                          forKey:@"GCSoundEffectsEnabled"];
}
- (void)announceMove:(NSString *)move
{
  if (!_speechEnabled || !move)
    return;
  if (!_speechQueue)
    _speechQueue = [[NSMutableArray alloc] init];
  [_speechQueue addObject:move];
  [self speakNextAnnouncement];
}
- (void)speakNextAnnouncement
{
  if (_speechActive || !_speechEnabled || ![_speechQueue count])
    return;
  if (!_speechSynthesizer)
    {
      Class speechClass = NSClassFromString (@"NSSpeechSynthesizer");
      if (speechClass)
        {
          NS_DURING
            {
              _speechSynthesizer = [[speechClass alloc] init];
              if ([_speechSynthesizer
                      respondsToSelector:@selector (setDelegate:)])
                [_speechSynthesizer setDelegate:self];
            }
          NS_HANDLER
            {
              NSLog (@"Unable to initialize speech synthesizer: %@",
                     localException);
              [_speechSynthesizer release];
              _speechSynthesizer = nil;
            }
          NS_ENDHANDLER
        }
    }
  NSString *announcement = [[_speechQueue objectAtIndex:0] retain];
  [_speechQueue removeObjectAtIndex:0];
  if (_speechSynthesizer &&
      [_speechSynthesizer respondsToSelector:@selector (startSpeakingString:)])
    {
      BOOL started = NO;
      NS_DURING
        {
          _speechActive = YES;
          started = [_speechSynthesizer startSpeakingString:announcement];
        }
      NS_HANDLER
        {
          NSLog (@"Unable to speak move announcement: %@", localException);
          started = NO;
        }
      NS_ENDHANDLER
      if (!started)
        {
          _speechActive = NO;
          [self performSelector:@selector (speakNextAnnouncement)
                     withObject:nil
                     afterDelay:0];
        }
    }
#if defined(GNUSTEP)
  else if ([[NSFileManager defaultManager]
               isExecutableFileAtPath:@"/usr/bin/espeak"])
    {
      _speechActive = YES;
      _speechTask = [[NSTask launchedTaskWithLaunchPath:@"/usr/bin/espeak"
                              arguments:[NSArray arrayWithObject:announcement]]
                       retain];
      [[NSNotificationCenter defaultCenter]
          addObserver:self
             selector:@selector (speechTaskDidTerminate:)
                 name:NSTaskDidTerminateNotification
               object:_speechTask];
    }
#endif
  [announcement release];
}
- (void)speechSynthesizer:(id)sender didFinishSpeaking:(BOOL)finished
{
  (void)sender;
  (void)finished;
  _speechActive = NO;
  [self speakNextAnnouncement];
}
- (void)speechTaskDidTerminate:(NSNotification *)notification
{
  [[NSNotificationCenter defaultCenter] removeObserver:self
                                                  name:NSTaskDidTerminateNotification
                                                object:[notification object]];
  [_speechTask release];
  _speechTask = nil;
  _speechActive = NO;
  [self speakNextAnnouncement];
}
- (void)toggleSpeech:(id)sender
{
  (void)sender;
  _speechEnabled = !_speechEnabled;
  [_speechMenu setState:_speechEnabled ? GC_ON_STATE : GC_OFF_STATE];
  [_speechButton setState:_speechEnabled ? GC_ON_STATE : GC_OFF_STATE];
  [_speechButton setTitle:_speechEnabled ? @"Announce Moves: On"
                                         : @"Announce Moves: Off"];
  [[NSUserDefaults standardUserDefaults] setBool:_speechEnabled
                                          forKey:@"GCSpeechEnabled"];
  if (_speechEnabled)
    [self announceMove:@"Move announcements enabled"];
  else
    {
      [_speechQueue removeAllObjects];
      if ([_speechSynthesizer respondsToSelector:@selector (stopSpeaking)])
        {
          NS_DURING
            {
              [_speechSynthesizer stopSpeaking];
            }
          NS_HANDLER
            {
              NSLog (@"Unable to stop speech synthesizer: %@",
                     localException);
            }
          NS_ENDHANDLER
        }
#if defined(GNUSTEP)
      if ([_speechTask isRunning])
        [_speechTask terminate];
#endif
      _speechActive = NO;
    }
}
- (void)toggleTeachingThreats:(id)sender
{
  (void)sender;
  _teachingThreatsEnabled = !_teachingThreatsEnabled;
  [_teachingThreatsMenu setState:_teachingThreatsEnabled ? GC_ON_STATE
                                                       : GC_OFF_STATE];
  [_board setTeachingThreatsEnabled:_teachingThreatsEnabled];
  [[NSUserDefaults standardUserDefaults]
      setBool:_teachingThreatsEnabled
       forKey:@"GCTeachingThreatsEnabled"];
}
- (void)suggestMove:(id)sender
{
  ChessGame *snapshot;
  (void)sender;
  if (_thinking || [_game gameOver])
    return;
  _thinking = YES;
  [_board clearSelection];
  [self refresh];
  snapshot = [_game copy];
  [NSThread detachNewThreadSelector:@selector (suggestionThread:)
                           toTarget:self
                         withObject:snapshot];
  [snapshot release];
}
- (void)suggestionThread:(ChessGame *)snapshot
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  GCMove move = [snapshot bestMoveAtDepth:3];
  [self performSelectorOnMainThread:@selector (finishSuggestion:)
                         withObject:GCMoveValue (move)
                      waitUntilDone:NO];
  [pool drain];
}
- (void)finishSuggestion:(NSValue *)value
{
  GCMove move = GCMoveFromValue (value);
  NSString *description = move.from >= 0 ? moveDescription (_game, move) : nil;
  _thinking = NO;
  [self refresh];
  if (description)
    {
      [_board showRecommendedMove:move];
      [_status setStringValue:[NSString stringWithFormat:@"Recommended: %@",
                                                         description]];
    }
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
  [_captured release];
  [_game release];
  [_status release];
  [_history release];
  [_computer release];
  [_computerMenu release];
  [_selfPlayButton release];
  [_selfPlayMenu release];
  [_soundEffectsMenu release];
  [_speechButton release];
  [_speechMenu release];
  [_teachingThreatsMenu release];
  [_speechSynthesizer release];
  [_speechQueue release];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  if ([_speechTask isRunning])
    [_speechTask terminate];
  [_speechTask release];
  [_whiteMoveSound release];
  [_blackMoveSound release];
  [_infoPanel release];
  [super dealloc];
}
@end
