#import "CapturedPiecesView.h"
#import "ChessGame.h"

#if defined(GNUSTEP)
#define GC_SOURCE_OVER NSCompositeSourceOver
#else
#define GC_SOURCE_OVER NSCompositingOperationSourceOver
#endif

@implementation CapturedPiecesView
- (id)initWithFrame:(NSRect)frame
{
  if ((self = [super initWithFrame:frame]))
    {
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
- (void)dealloc
{
  [_pieces release];
  [super dealloc];
}
- (void)setGame:(ChessGame *)game
{
  _game = game;
  [self setNeedsDisplay:YES];
}
- (void)drawPiece:(int)kind black:(BOOL)black inRect:(NSRect)destination
{
  int index = (black ? 6 : 0) + kind - 1;
  int map[12] = { 5, 4, 3, 2, 1, 0, 11, 10, 9, 8, 7, 6 };
  index = map[index];
  int column = index % 4, row = index / 4;
  NSSize imageSize = [_pieces size];
  CGFloat rowTop[3] = { 0.0, 462.0, 880.0 };
  CGFloat rowHeight[3] = { 462.0, 418.0, 374.0 };
  CGFloat scaleY = imageSize.height / 1254.0;
  CGFloat sourceHeight = rowHeight[row] * scaleY;
  CGFloat sourceY
      = imageSize.height - (rowTop[row] + rowHeight[row]) * scaleY;
  NSRect source = NSMakeRect (column * imageSize.width / 4, sourceY,
                              imageSize.width / 4, sourceHeight);
  destination.origin.y -= 2;
  [_pieces drawInRect:destination
             fromRect:source
            operation:GC_SOURCE_OVER
             fraction:1
       respectFlipped:YES
                hints:nil];
}
- (CGFloat)drawCapturedColor:(BOOL)black
                           at:(CGFloat)x
                       counts:(int *)current
{
  int kinds[5] = { GCQueen, GCRook, GCBishop, GCKnight, GCPawn };
  int initial[7] = { 0, 8, 2, 2, 2, 1, 1 };
  NSDictionary *countAttributes = [NSDictionary
      dictionaryWithObjectsAndKeys:[NSFont boldSystemFontOfSize:10],
                                   NSFontAttributeName, [NSColor whiteColor],
                                   NSForegroundColorAttributeName, nil];
  BOOL drewPiece = NO;
  for (int i = 0; i < 5; i++)
    {
      int kind = kinds[i], count = initial[kind] - current[kind];
      if (count <= 0)
        continue;
      [self drawPiece:kind
                black:black
               inRect:NSMakeRect (x, 10, 27, 27)];
      if (count > 1)
        [[NSString stringWithFormat:@"%d", count]
            drawAtPoint:NSMakePoint (x + 20, 4)
         withAttributes:countAttributes];
      x += 29;
      drewPiece = YES;
    }
  if (!drewPiece)
    {
      NSDictionary *attributes = [NSDictionary
          dictionaryWithObjectsAndKeys:[NSFont systemFontOfSize:15],
                                       NSFontAttributeName,
                                       [NSColor lightGrayColor],
                                       NSForegroundColorAttributeName, nil];
      [@"—" drawAtPoint:NSMakePoint (x + 4, 14) withAttributes:attributes];
      x += 24;
    }
  return x;
}
- (void)drawRect:(NSRect)dirty
{
  (void)dirty;
  [[NSColor colorWithCalibratedRed:.13 green:.15 blue:.18 alpha:1] setFill];
  NSRectFill ([self bounds]);
  if (!_game || !_pieces)
    return;

  int white[7] = { 0 }, black[7] = { 0 };
  for (int square = 0; square < 64; square++)
    {
      uint8_t piece = [_game pieceAt:square];
      if (piece)
        ((piece & GCBlack) ? black : white)[piece & 7]++;
    }
  int initial[7] = { 0, 8, 2, 2, 2, 1, 1 };
  int value[7] = { 0, 1, 3, 3, 5, 9, 0 };
  int score = 0;
  for (int kind = GCPawn; kind <= GCQueen; kind++)
    score += ((initial[kind] - black[kind])
              - (initial[kind] - white[kind]))
             * value[kind];

  NSDictionary *labelAttributes = [NSDictionary
      dictionaryWithObjectsAndKeys:[NSFont boldSystemFontOfSize:12],
                                   NSFontAttributeName, [NSColor whiteColor],
                                   NSForegroundColorAttributeName, nil];
  [@"White took" drawAtPoint:NSMakePoint (10, 17)
               withAttributes:labelAttributes];
  [self drawCapturedColor:YES at:73 counts:black];
  CGFloat secondX = 225;
  [@"Black took" drawAtPoint:NSMakePoint (secondX, 17)
               withAttributes:labelAttributes];
  [self drawCapturedColor:NO at:secondX + 70 counts:white];

  NSString *scoreText;
  if (score > 0)
    scoreText = [NSString stringWithFormat:@"Score: White +%d", score];
  else if (score < 0)
    scoreText = [NSString stringWithFormat:@"Score: Black +%d", -score];
  else
    scoreText = @"Score: Even";
  NSSize scoreSize = [scoreText sizeWithAttributes:labelAttributes];
  [scoreText drawAtPoint:NSMakePoint (NSWidth ([self bounds]) - scoreSize.width
                                          - 10,
                                      17)
          withAttributes:labelAttributes];
}
@end
