#import "ChessBoardView.h"

#if defined(GNUSTEP)
#define GC_SOURCE_OVER NSCompositeSourceOver
#else
#define GC_SOURCE_OVER NSCompositingOperationSourceOver
#endif

@implementation ChessBoardView
- (void)drawCoordinate:(NSString *)text atPoint:(NSPoint)point
{
  CGFloat squareSize = [self boardRect].size.width / 8;
  NSFont *font = [NSFont boldSystemFontOfSize:MAX (12.0, squareSize * .12)];
  NSDictionary *outline = [NSDictionary
      dictionaryWithObjectsAndKeys:font, NSFontAttributeName,
                                   [NSColor colorWithWhite:0 alpha:.95],
                                   NSForegroundColorAttributeName, nil];
  NSDictionary *face = [NSDictionary
      dictionaryWithObjectsAndKeys:font, NSFontAttributeName,
                                   [NSColor whiteColor],
                                   NSForegroundColorAttributeName, nil];
  /* Four one-pixel shadows form a crisp outline on both board colors. */
  [text drawAtPoint:NSMakePoint (point.x - 1, point.y) withAttributes:outline];
  [text drawAtPoint:NSMakePoint (point.x + 1, point.y) withAttributes:outline];
  [text drawAtPoint:NSMakePoint (point.x, point.y - 1) withAttributes:outline];
  [text drawAtPoint:NSMakePoint (point.x, point.y + 1) withAttributes:outline];
  [text drawAtPoint:point withAttributes:face];
}
- (id)initWithFrame:(NSRect)frame
{
  if ((self = [super initWithFrame:frame]))
    {
      _selected = -1;
      _hoveredTarget = -1;
      _targets = [[NSArray alloc] init];
      _threatenedTargets = [[NSSet alloc] init];
      _hoverAttackers = [[NSArray alloc] init];
      NSString *path = [[NSBundle mainBundle] pathForResource:@"pieces"
                                                       ofType:@"png"];
      if (!path)
        path = @"Resources/pieces.png";
      _pieces = [[NSImage alloc] initWithContentsOfFile:path];
    }
  return self;
}
- (BOOL)isFlipped
{
  return YES;
}
- (void)updateTrackingAreas
{
  [super updateTrackingAreas];
  if (_trackingArea)
    {
      [self removeTrackingArea:_trackingArea];
      [_trackingArea release];
    }
  _trackingArea = [[NSTrackingArea alloc]
      initWithRect:[self bounds]
           options:NSTrackingMouseMoved | NSTrackingActiveInKeyWindow |
                   NSTrackingInVisibleRect
             owner:self
          userInfo:nil];
  [self addTrackingArea:_trackingArea];
}
- (void)dealloc
{
  if (_trackingArea)
    [self removeTrackingArea:_trackingArea];
  [_trackingArea release];
  [_targets release];
  [_threatenedTargets release];
  [_hoverAttackers release];
  [_pieces release];
  [super dealloc];
}
- (void)setGame:(ChessGame *)game
{
  _game = game;
  [self clearSelection];
}
- (ChessGame *)game
{
  return _game;
}
- (void)setDelegate:(id)delegate
{
  _delegate = delegate;
}
- (id)delegate
{
  return _delegate;
}
- (void)setFlippedBoard:(BOOL)v
{
  _flippedBoard = v;
  [self setNeedsDisplay:YES];
}
- (BOOL)flippedBoard
{
  return _flippedBoard;
}
- (void)clearSelection
{
  _selected = -1;
  _hoveredTarget = -1;
  _hasRecommendedMove = NO;
  [_targets release];
  _targets = [[NSArray alloc] init];
  [_threatenedTargets release];
  _threatenedTargets = [[NSSet alloc] init];
  [_hoverAttackers release];
  _hoverAttackers = [[NSArray alloc] init];
  [self setNeedsDisplay:YES];
}
- (NSArray *)attackersAfterMove:(GCMove)move
{
  ChessGame *position = [_game copy];
  NSMutableArray *attackers = [NSMutableArray array];
  if ([position makeMove:move])
    {
      NSEnumerator *enumerator = [[position legalMoves] objectEnumerator];
      NSValue *value;
      while ((value = [enumerator nextObject]))
        {
          GCMove reply = GCMoveFromValue (value);
          if (reply.to == move.to && (reply.flags & GCCapture))
            [attackers addObject:[NSNumber numberWithInt:reply.from]];
        }
    }
  [position release];
  return attackers;
}
- (void)updateTeachingMarkers
{
  NSMutableSet *threatened = [NSMutableSet set];
  if (_teachingThreats)
    {
      NSEnumerator *enumerator = [_targets objectEnumerator];
      NSValue *value;
      while ((value = [enumerator nextObject]))
        {
          GCMove move = GCMoveFromValue (value);
          if ([[self attackersAfterMove:move] count])
            [threatened addObject:[NSNumber numberWithInt:move.to]];
        }
    }
  [_threatenedTargets release];
  _threatenedTargets = [threatened copy];
}
- (void)setTeachingThreatsEnabled:(BOOL)enabled
{
  _teachingThreats = enabled;
  _hoveredTarget = -1;
  [_hoverAttackers release];
  _hoverAttackers = [[NSArray alloc] init];
  [self updateTeachingMarkers];
  [self setNeedsDisplay:YES];
}
- (void)showRecommendedMove:(GCMove)move
{
  _recommendedMove = move;
  _hasRecommendedMove = move.from >= 0 && move.to >= 0;
  _selected = -1;
  [_targets release];
  _targets = [[NSArray alloc] init];
  [self setNeedsDisplay:YES];
}
- (NSRect)boardRect
{
  NSRect bounds = [self bounds];
  CGFloat n = MIN (bounds.size.width, bounds.size.height),
          x = (bounds.size.width - n) / 2, y = (bounds.size.height - n) / 2;
  return NSMakeRect (x, y, n, n);
}
- (NSInteger)squareAtPoint:(NSPoint)p
{
  NSRect b = [self boardRect];
  if (!NSPointInRect (p, b))
    return -1;
  CGFloat z = b.size.width / 8;
  int vf = (p.x - b.origin.x) / z, vr = (p.y - b.origin.y) / z;
  int f = _flippedBoard ? 7 - vf : vf, r = _flippedBoard ? vr : 7 - vr;
  return r * 8 + f;
}
- (NSRect)rectForSquare:(NSInteger)s
{
  NSRect b = [self boardRect];
  CGFloat z = b.size.width / 8;
  int f = (int)s & 7, r = (int)s >> 3;
  int vf = _flippedBoard ? 7 - f : f, vr = _flippedBoard ? r : 7 - r;
  return NSMakeRect (b.origin.x + vf * z, b.origin.y + vr * z, z, z);
}
- (void)drawRect:(NSRect)dirty
{
  (void)dirty;
  [[NSColor colorWithCalibratedRed:.08 green:.10 blue:.13 alpha:1] setFill];
  NSRectFill ([self bounds]);
  NSColor *light
      = [NSColor colorWithCalibratedRed:.83 green:.72 blue:.56 alpha:1],
      *dark = [NSColor colorWithCalibratedRed:.35 green:.22 blue:.15 alpha:1];
  /* a1 is dark, therefore h1 (the lower-right square from White's side) is
   * light. */
  for (int s = 0; s < 64; s++)
    {
      NSRect q = [self rectForSquare:s];
      [(((s & 7) + (s >> 3)) & 1) ? light : dark setFill];
      NSRectFill (q);
      if (_hasRecommendedMove
          && (s == _recommendedMove.from || s == _recommendedMove.to))
        {
          NSBezierPath *recommendation =
              [NSBezierPath bezierPathWithRect:NSInsetRect (q, 4, 4)];
          [[NSColor colorWithCalibratedRed:.10 green:.55 blue:1.0
                                     alpha:.95] setStroke];
          [recommendation setLineWidth:MAX (3.0, q.size.width * .045)];
          [recommendation stroke];
        }
      if (s == _selected)
        {
          [[NSColor colorWithCalibratedRed:.95 green:.75 blue:.15
                                     alpha:.65] setFill];
          NSRectFillUsingOperation (q, GC_SOURCE_OVER);
        }
      if ([_hoverAttackers containsObject:[NSNumber numberWithInt:s]])
        {
          NSBezierPath *attacker =
              [NSBezierPath bezierPathWithRect:NSInsetRect (q, 5, 5)];
          [[NSColor colorWithCalibratedRed:1 green:.12 blue:.12 alpha:.95]
              setStroke];
          [attacker setLineWidth:MAX (4.0, q.size.width * .055)];
          [attacker stroke];
        }
      NSEnumerator *targetEnumerator = [_targets objectEnumerator];
      NSValue *v;
      while ((v = [targetEnumerator nextObject]))
        if (GCMoveFromValue (v).to == s)
          {
            CGFloat d = q.size.width * .22;
            NSColor *marker = [_threatenedTargets
                containsObject:[NSNumber numberWithInt:s]]
                                  ? [NSColor colorWithCalibratedRed:.9
                                                             green:.12
                                                              blue:.12
                                                             alpha:.85]
                                  : [NSColor colorWithCalibratedRed:.15
                                                             green:.65
                                                              blue:.35
                                                             alpha:.8];
            [marker setFill];
            [[NSBezierPath bezierPathWithOvalInRect:NSInsetRect (q, d, d)]
                fill];
          }
      uint8_t pc = [_game pieceAt:s];
      if (pc && _pieces)
        {
          int k = (pc & 7), idx;
          if (!(pc & GCBlack))
            idx = k - 1;
          else
            idx = 6 + k - 1; /* sheet order: WK WQ WR WB / WN WP BK BQ / BR BB
                                BN BP */
          int map[12] = { 5, 4, 3, 2, 1, 0, 11, 10, 9, 8, 7, 6 };
          idx = map[idx];
          int col = idx % 4, row = idx / 4;
          NSSize im = [_pieces size];
          /* ImageGen's visual rows are not exact thirds: the first row extends
             below 1/3 and the last is shorter.  Use the real transparent-row
             boundaries so a preceding piece's base never bleeds into the next
             sprite.  NSImage source coordinates start at the image bottom. */
          CGFloat rowTop[3] = { 0.0, 462.0, 880.0 };
          CGFloat rowHeight[3] = { 462.0, 418.0, 374.0 };
          CGFloat scaleY = im.height / 1254.0;
          CGFloat sourceHeight = rowHeight[row] * scaleY;
          CGFloat sourceY
              = im.height - (rowTop[row] + rowHeight[row]) * scaleY;
          NSRect src = NSMakeRect (col * im.width / 4, sourceY, im.width / 4,
                                   sourceHeight);
          NSRect destination
              = NSInsetRect (q, q.size.width * .08, q.size.height * .08);
          destination.origin.y -= q.size.height * .055;
          [_pieces drawInRect:destination
                     fromRect:src
                    operation:GC_SOURCE_OVER
                     fraction:1
               respectFlipped:YES
                        hints:nil];
        }
    }
  for (int i = 0; i < 8; i++)
    {
      CGFloat squareSize = [self boardRect].size.width / 8;
      CGFloat labelInset = MAX (13.0, squareSize * .14);
      int f = _flippedBoard ? 7 - i : i, r = _flippedBoard ? i : 7 - i;
      NSRect fq = [self rectForSquare:f];
      [self drawCoordinate:[NSString stringWithFormat:@"%c", 'a' + f]
                   atPoint:NSMakePoint (NSMaxX (fq) - labelInset,
                                        NSMaxY (fq) - labelInset - 3)];
      NSRect rq = [self rectForSquare:r * 8];
      [self drawCoordinate:[NSString stringWithFormat:@"%d", r + 1]
                   atPoint:NSMakePoint (NSMinX (rq) + 3, NSMinY (rq) + 2)];
    }
}
- (void)mouseMoved:(NSEvent *)event
{
  NSInteger square = [self squareAtPoint:[self convertPoint:[event locationInWindow]
                                                    fromView:nil]];
  NSInteger hovered = -1;
  GCMove hoveredMove = { -1, -1, 0, 0 };
  NSEnumerator *enumerator = [_targets objectEnumerator];
  NSValue *value;
  while ((value = [enumerator nextObject]))
    {
      GCMove move = GCMoveFromValue (value);
      if (move.to == square)
        {
          hovered = square;
          hoveredMove = move;
          break;
        }
    }
  if (hovered == _hoveredTarget)
    return;
  _hoveredTarget = hovered;
  [_hoverAttackers release];
  _hoverAttackers = (_teachingThreats && hovered >= 0)
                        ? [[self attackersAfterMove:hoveredMove] retain]
                        : [[NSArray alloc] init];
  [self setNeedsDisplay:YES];
}
- (void)mouseDown:(NSEvent *)event
{
  NSInteger s = [self squareAtPoint:[self convertPoint:[event locationInWindow]
                                              fromView:nil]];
  NSEnumerator *e;
  NSValue *v;
  if (s < 0)
    return;
  e = [_targets objectEnumerator];
  while ((v = [e nextObject]))
    {
      GCMove m = GCMoveFromValue (v);
      if (m.to == s)
        {
          [_delegate boardView:self requestedMove:m];
          [self clearSelection];
          return;
        }
    }
  uint8_t pc = [_game pieceAt:s];
  if (pc && ((pc & GCBlack) != 0) == [_game blackToMove])
    {
      _selected = s;
      [_targets release];
      _targets = [[_game legalMovesFrom:s] retain];
      [self updateTeachingMarkers];
    }
  else
    {
      _selected = -1;
      [_targets release];
      _targets = [[NSArray alloc] init];
      [self updateTeachingMarkers];
    }
  [self setNeedsDisplay:YES];
}
@end
