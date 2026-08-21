#import "ChessGame.h"
#include <limits.h>

static int
fileOf (int s)
{
  return s & 7;
}
static int
rankOf (int s)
{
  return s >> 3;
}
static BOOL
inside (int f, int r)
{
  return f >= 0 && f < 8 && r >= 0 && r < 8;
}
static BOOL
isBlack (uint8_t p)
{
  return (p & GCBlack) != 0;
}
static int
kind (uint8_t p)
{
  return p & 7;
}
static uint8_t
piece (int k, BOOL black)
{
  return (uint8_t)(k | (black ? GCBlack : 0));
}
static NSInteger
compareMoves (id left, id right, void *context)
{
  GCMove a, b;
  (void)context;
  a = GCMoveFromValue (left);
  b = GCMoveFromValue (right);
  if (a.flags < b.flags)
    return NSOrderedDescending;
  if (a.flags > b.flags)
    return NSOrderedAscending;
  return NSOrderedSame;
}

@implementation ChessGame

- (id)init
{
  if ((self = [super init]))
    {
      _undo = [[NSMutableArray alloc] init];
      _mutableHistory = [[NSMutableArray alloc] init];
      _positionKeys = [[NSMutableArray alloc] init];
      [self reset];
    }
  return self;
}
- (void)dealloc
{
  [_undo release];
  [_mutableHistory release];
  [_positionKeys release];
  [super dealloc];
}
- (id)copyWithZone:(NSZone *)zone
{
  ChessGame *g = [[[self class] allocWithZone:zone] init];
  g->_p = _p;
  g->_resigned = _resigned;
  g->_resignedBlack = _resignedBlack;
  [g->_undo release];
  [g->_mutableHistory release];
  [g->_positionKeys release];
  g->_undo = [_undo mutableCopy];
  g->_mutableHistory = [_mutableHistory mutableCopy];
  g->_positionKeys = [_positionKeys mutableCopy];
  return g;
}
- (BOOL)blackToMove
{
  return _p.black;
}
- (NSArray *)history
{
  return [[_mutableHistory copy] autorelease];
}
- (uint8_t)pieceAt:(NSInteger)s
{
  return s >= 0 && s < 64 ? _p.board[s] : 0;
}

- (void)reset
{
  memset (&_p, 0, sizeof (_p));
  _p.ep = -1;
  _p.rights = 15;
  _p.black = NO;
  _resigned = NO;
  _resignedBlack = NO;
  int back[8] = { GCRook, GCKnight, GCBishop, GCQueen,
                  GCKing, GCBishop, GCKnight, GCRook };
  for (int f = 0; f < 8; f++)
    {
      _p.board[f] = piece (back[f], NO);
      _p.board[8 + f] = GCPawn;
      _p.board[48 + f] = piece (GCPawn, YES);
      _p.board[56 + f] = piece (back[f], YES);
    }
  [_undo removeAllObjects];
  [_mutableHistory removeAllObjects];
  [_positionKeys removeAllObjects];
  [_positionKeys addObject:[self positionKeyForPosition:&_p]];
}

/* Attack detection is separate from move generation: pawn attacks differ from
   pawn moves, and kings must not recursively ask whether their moves are
   legal. */
- (BOOL)square:(int)s attackedByBlack:(BOOL)black position:(GCPosition *)p
{
  int f = fileOf (s), r = rankOf (s), pawnRank = r + (black ? 1 : -1);
  for (int df = -1; df <= 1; df += 2)
    if (inside (f + df, pawnRank)
        && p->board[pawnRank * 8 + f + df] == piece (GCPawn, black))
      return YES;
  int nf[8] = { 1, 2, 2, 1, -1, -2, -2, -1 },
      nr[8] = { 2, 1, -1, -2, -2, -1, 1, 2 };
  for (int i = 0; i < 8; i++)
    if (inside (f + nf[i], r + nr[i])
        && p->board[(r + nr[i]) * 8 + f + nf[i]] == piece (GCKnight, black))
      return YES;
  int dirs[8][2] = { { 1, 0 }, { -1, 0 }, { 0, 1 },  { 0, -1 },
                     { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } };
  for (int d = 0; d < 8; d++)
    {
      int x = f + dirs[d][0], y = r + dirs[d][1];
      while (inside (x, y))
        {
          uint8_t q = p->board[y * 8 + x];
          if (q)
            {
              if (isBlack (q) == black
                  && (kind (q) == GCQueen
                      || kind (q) == (d < 4 ? GCRook : GCBishop)))
                return YES;
              break;
            }
          x += dirs[d][0];
          y += dirs[d][1];
        }
    }
  for (int x = f - 1; x <= f + 1; x++)
    for (int y = r - 1; y <= r + 1; y++)
      if (inside (x, y) && (x != f || y != r)
          && p->board[y * 8 + x] == piece (GCKing, black))
        return YES;
  return NO;
}

- (BOOL)inCheck:(BOOL)black position:(GCPosition *)p
{
  for (int s = 0; s < 64; s++)
    if (p->board[s] == piece (GCKing, black))
      return [self square:s attackedByBlack:!black position:p];
  return YES;
}

static void
add (NSMutableArray *a, int from, int to, int promo, int flags)
{
  GCMove m = { (int8_t)from, (int8_t)to, (int8_t)promo, (uint8_t)flags };
  [a addObject:GCMoveValue (m)];
}

/* Produces geometric candidates. King-safety validation happens afterwards. */
- (NSArray *)pseudoMoves:(GCPosition *)p
{
  NSMutableArray *a = [NSMutableArray array];
  BOOL side = p->black;
  for (int s = 0; s < 64; s++)
    {
      uint8_t pc = p->board[s];
      if (!pc || isBlack (pc) != side)
        continue;
      int f = fileOf (s), r = rankOf (s), k = kind (pc);
      if (k == GCPawn)
        {
          int dr = side ? -1 : 1, nr = r + dr;
          if (inside (f, nr) && !p->board[nr * 8 + f])
            {
              int flags = (nr == 0 || nr == 7) ? GCPromotion : 0;
              add (a, s, nr * 8 + f, flags ? GCQueen : 0, flags);
              int start = side ? 6 : 1, nr2 = r + 2 * dr;
              if (r == start && !p->board[nr2 * 8 + f])
                add (a, s, nr2 * 8 + f, 0, 0);
            }
          for (int df = -1; df <= 1; df += 2)
            {
              int x = f + df;
              if (!inside (x, nr))
                continue;
              int to = nr * 8 + x;
              uint8_t q = p->board[to];
              if ((q && isBlack (q) != side) || to == p->ep)
                {
                  int fl = GCCapture | (to == p->ep ? GCEnPassant : 0)
                           | ((nr == 0 || nr == 7) ? GCPromotion : 0);
                  add (a, s, to, (fl & GCPromotion) ? GCQueen : 0, fl);
                }
            }
        }
      else if (k == GCKnight)
        {
          int dx[8] = { 1, 2, 2, 1, -1, -2, -2, -1 },
              dy[8] = { 2, 1, -1, -2, -2, -1, 1, 2 };
          for (int i = 0; i < 8; i++)
            {
              int x = f + dx[i], y = r + dy[i];
              if (inside (x, y)
                  && (!p->board[y * 8 + x]
                      || isBlack (p->board[y * 8 + x]) != side))
                add (a, s, y * 8 + x, 0, p->board[y * 8 + x] ? GCCapture : 0);
            }
        }
      else if (k == GCKing)
        {
          for (int x = f - 1; x <= f + 1; x++)
            for (int y = r - 1; y <= r + 1; y++)
              if (inside (x, y) && (x != f || y != r)
                  && (!p->board[y * 8 + x]
                      || isBlack (p->board[y * 8 + x]) != side))
                add (a, s, y * 8 + x, 0, p->board[y * 8 + x] ? GCCapture : 0);
          int base = side ? 56 : 0, shift = side ? 2 : 0;
          if (s == base + 4 && ![self inCheck:side position:p])
            {
              if ((p->rights & (1 << shift)) && !p->board[base + 5]
                  && !p->board[base + 6]
                  && ![self square:base + 5 attackedByBlack:!side position:p]
                  && ![self square:base + 6 attackedByBlack:!side position:p])
                add (a, s, base + 6, 0, GCCastle);
              if ((p->rights & (2 << shift)) && !p->board[base + 1]
                  && !p->board[base + 2] && !p->board[base + 3]
                  && ![self square:base + 3 attackedByBlack:!side position:p]
                  && ![self square:base + 2 attackedByBlack:!side position:p])
                add (a, s, base + 2, 0, GCCastle);
            }
        }
      else
        {
          int dirs[8][2] = { { 1, 0 }, { -1, 0 }, { 0, 1 },  { 0, -1 },
                             { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } };
          int lo = k == GCBishop ? 4 : 0, hi = k == GCRook ? 4 : 8;
          for (int d = lo; d < hi; d++)
            {
              int x = f + dirs[d][0], y = r + dirs[d][1];
              while (inside (x, y))
                {
                  uint8_t q = p->board[y * 8 + x];
                  if (!q)
                    add (a, s, y * 8 + x, 0, 0);
                  else
                    {
                      if (isBlack (q) != side)
                        add (a, s, y * 8 + x, 0, GCCapture);
                      break;
                    }
                  x += dirs[d][0];
                  y += dirs[d][1];
                }
            }
        }
    }
  return a;
}

- (void)apply:(GCMove)m to:(GCPosition *)p
{
  uint8_t pc = p->board[m.from], captured = p->board[m.to];
  BOOL side = isBlack (pc);
  p->ep = -1;
  p->board[m.to] = pc;
  p->board[m.from] = 0;
  if (m.flags & GCEnPassant)
    p->board[m.to + (side ? 8 : -8)] = 0;
  if (m.flags & GCCastle)
    {
      int rookFrom = m.to > m.from ? m.from + 3 : m.from - 4,
          rookTo = m.to > m.from ? m.from + 1 : m.from - 1;
      p->board[rookTo] = p->board[rookFrom];
      p->board[rookFrom] = 0;
    }
  if (m.flags & GCPromotion)
    p->board[m.to] = piece (m.promotion ? m.promotion : GCQueen, side);
  if (kind (pc) == GCPawn && abs (m.to - m.from) == 16)
    p->ep = (int8_t)((m.to + m.from) / 2);
  if (kind (pc) == GCKing)
    p->rights &= side ? 3 : 12;
  if (m.from == 0 || m.to == 0)
    p->rights &= ~2;
  if (m.from == 7 || m.to == 7)
    p->rights &= ~1;
  if (m.from == 56 || m.to == 56)
    p->rights &= ~8;
  if (m.from == 63 || m.to == 63)
    p->rights &= ~4;
  (void)captured;
  p->black = !p->black;
}

- (NSArray *)legalMovesFor:(GCPosition *)p
{
  NSMutableArray *legal = [NSMutableArray array];
  BOOL side = p->black;
  NSEnumerator *enumerator;
  NSValue *v;
  enumerator = [[self pseudoMoves:p] objectEnumerator];
  while ((v = [enumerator nextObject]))
    {
      GCMove m = GCMoveFromValue (v);
      GCPosition q = *p;
      [self apply:m to:&q];
      if (![self inCheck:side position:&q])
        [legal addObject:v];
    }
  return legal;
}
- (NSData *)positionKeyForPosition:(GCPosition *)p
{
  NSMutableData *key;
  int8_t effectiveEnPassant = -1;
  NSEnumerator *enumerator;
  NSValue *value;

  /* FIDE 9.2 compares possible moves as well as piece placement.  An
     en-passant square therefore matters only when a legal en-passant capture
     actually exists.  Castling rights always remain part of the key. */
  if (p->ep >= 0)
    {
      enumerator = [[self legalMovesFor:p] objectEnumerator];
      while ((value = [enumerator nextObject]))
        if (GCMoveFromValue (value).flags & GCEnPassant)
          {
            effectiveEnPassant = p->ep;
            break;
          }
    }
  key = [NSMutableData dataWithCapacity:67];
  [key appendBytes:p->board length:64];
  [key appendBytes:&p->rights length:1];
  [key appendBytes:&effectiveEnPassant length:1];
  [key appendBytes:&p->black length:1];
  return key;
}
- (NSUInteger)currentPositionRepetitionCount
{
  NSData *current = [self positionKeyForPosition:&_p];
  NSEnumerator *enumerator = [_positionKeys objectEnumerator];
  NSData *key;
  NSUInteger count = 0;
  while ((key = [enumerator nextObject]))
    if ([key isEqual:current])
      count++;
  return count;
}
- (NSArray *)legalMoves
{
  GCPosition p = _p;
  return [self legalMovesFor:&p];
}
- (NSArray *)legalMovesFrom:(NSInteger)s
{
  NSMutableArray *a = [NSMutableArray array];
  NSEnumerator *e = [[self legalMoves] objectEnumerator];
  NSValue *v;
  while ((v = [e nextObject]))
    if (GCMoveFromValue (v).from == s)
      [a addObject:v];
  return a;
}

static NSString *
squareName (int s)
{
  return [NSString stringWithFormat:@"%c%d", 'a' + fileOf (s), rankOf (s) + 1];
}
- (NSString *)notation:(GCMove)m moving:(uint8_t)pc
{
  if (m.flags & GCCastle)
    return m.to > m.from ? @"O-O" : @"O-O-O";
  NSString *names = @" PNBRQK";
  NSString *lead = kind (pc) == GCPawn
                       ? @""
                       : [names substringWithRange:NSMakeRange (kind (pc), 1)];
  NSString *cap = (m.flags & GCCapture) ? @"x" : @"";
  if (kind (pc) == GCPawn && (m.flags & GCCapture))
    lead = [NSString stringWithFormat:@"%c", 'a' + fileOf (m.from)];
  return [NSString stringWithFormat:@"%@%@%@%@", lead, cap, squareName (m.to),
                                    (m.flags & GCPromotion) ? @"=Q" : @""];
}
- (BOOL)makeMove:(GCMove)m
{
  if ([self gameOver])
    return NO;
  BOOL found = NO;
  NSEnumerator *e = [[self legalMoves] objectEnumerator];
  NSValue *v;
  while ((v = [e nextObject]))
    {
      GCMove x = GCMoveFromValue (v);
      if (x.from == m.from && x.to == m.to)
        {
          m = x;
          found = YES;
          break;
        }
    }
  if (!found)
    return NO;
  [_undo addObject:[NSData dataWithBytes:&_p length:sizeof (_p)]];
  NSString *n = [self notation:m moving:_p.board[m.from]];
  [self apply:m to:&_p];
  NSArray *next = [self legalMoves];
  if (![next count])
    n = [n stringByAppendingString:[self inCheck:_p.black position:&_p] ? @"#"
                                                                        : @""];
  else if ([self inCheck:_p.black position:&_p])
    n = [n stringByAppendingString:@"+"];
  [_mutableHistory addObject:n];
  [_positionKeys addObject:[self positionKeyForPosition:&_p]];
  return YES;
}
- (void)undo
{
  if (_resigned)
    {
      _resigned = NO;
      return;
    }
  if (![_undo count])
    return;
  [[_undo lastObject] getBytes:&_p length:sizeof (_p)];
  [_undo removeLastObject];
  if ([_mutableHistory count])
    [_mutableHistory removeLastObject];
  if ([_positionKeys count] > 1)
    [_positionKeys removeLastObject];
}
- (void)resignBlack:(BOOL)black
{
  if (![self gameOver])
    {
      _resigned = YES;
      _resignedBlack = black;
    }
}
- (BOOL)gameOver
{
  return _resigned || [[self legalMoves] count] == 0 ||
         [self currentPositionRepetitionCount] >= 5;
}
- (NSString *)status
{
  if (_resigned)
    return [NSString stringWithFormat:@"%@ resigned — %@ wins",
                                      _resignedBlack ? @"Black" : @"White",
                                      _resignedBlack ? @"White" : @"Black"];
  if ([self currentPositionRepetitionCount] >= 5)
    return @"Draw — fivefold repetition";
  if (![self gameOver])
    return [NSString
        stringWithFormat:@"%@ to move%@", _p.black ? @"Black" : @"White",
                         [self inCheck:_p.black position:&_p] ? @" — check"
                                                              : @""];
  return [self inCheck:_p.black position:&_p]
             ? [NSString stringWithFormat:@"Checkmate — %@ wins",
                                          _p.black ? @"White" : @"Black"]
             : @"Draw — stalemate";
}

- (NSString *)FENString
{
  NSMutableString *fen = [NSMutableString string];
  NSString *symbols = @" pnbrqk";
  for (int r = 7; r >= 0; r--)
    {
      int empty = 0;
      for (int f = 0; f < 8; f++)
        {
          uint8_t pc = _p.board[r * 8 + f];
          if (!pc)
            {
              empty++;
              continue;
            }
          if (empty)
            {
              [fen appendFormat:@"%d", empty];
              empty = 0;
            }
          unichar c = [symbols characterAtIndex:kind (pc)];
          if (!isBlack (pc))
            c = (unichar)toupper (c);
          [fen appendFormat:@"%C", c];
        }
      if (empty)
        [fen appendFormat:@"%d", empty];
      if (r)
        [fen appendString:@"/"];
    }
  NSMutableString *rights = [NSMutableString string];
  if (_p.rights & 1)
    [rights appendString:@"K"];
  if (_p.rights & 2)
    [rights appendString:@"Q"];
  if (_p.rights & 4)
    [rights appendString:@"k"];
  if (_p.rights & 8)
    [rights appendString:@"q"];
  [fen appendFormat:@" %@ %@ %@ 0 %lu", _p.black ? @"b" : @"w",
                    [rights length] ? rights : @"-",
                    _p.ep >= 0 ? squareName (_p.ep) : @"-",
                    (unsigned long)([_mutableHistory count] / 2 + 1)];
  return fen;
}
- (NSString *)PGNString
{
  NSString *result = @"*";
  if (_resigned)
    result = _resignedBlack ? @"1-0" : @"0-1";
  else if ([self gameOver])
    result = [self inCheck:_p.black position:&_p]
                 ? (_p.black ? @"1-0" : @"0-1")
                 : @"1/2-1/2";
  NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
  [formatter setDateFormat:@"yyyy.MM.dd"];
  NSMutableString *pgn = [NSMutableString
      stringWithFormat:
          @"[Event \"Grandmaster Chess Game\"]\n[Site "
          @"\"GNUstep/macOS\"]\n[Date \"%@\"]\n[Round \"-\"]\n[White "
          @"\"Human\"]\n[Black \"Computer\"]\n[Result \"%@\"]\n[CurrentFEN "
          @"\"%@\"]\n\n",
          [formatter stringFromDate:[NSDate date]], result, [self FENString]];
  for (NSUInteger i = 0; i < [_mutableHistory count]; i += 2)
    {
      [pgn appendFormat:@"%lu. %@", (unsigned long)i / 2 + 1,
                        [_mutableHistory objectAtIndex:i]];
      if (i + 1 < [_mutableHistory count])
        [pgn appendFormat:@" %@", [_mutableHistory objectAtIndex:i + 1]];
      [pgn appendString:@" "];
    }
  [pgn appendFormat:@"%@\n", result];
  [formatter release];
  return pgn;
}

/* Negamax: each recursive score is from the player-to-move's perspective.
   Negating the child's score converts it back to the current perspective. */
- (int)evaluate:(GCPosition *)p
{
  int val[7] = { 0, 100, 320, 330, 500, 900, 0 }, score = 0;
  for (int s = 0; s < 64; s++)
    {
      uint8_t pc = p->board[s];
      if (!pc)
        continue;
      int center
          = 6 - (abs (fileOf (s) * 2 - 7) + abs (rankOf (s) * 2 - 7)) / 2;
      int v = val[kind (pc)] + center;
      (isBlack (pc) == p->black) ? (score += v) : (score -= v);
    }
  return score;
}
- (int)search:(GCPosition *)p
        depth:(int)d
        alpha:(int)alpha
         beta:(int)beta
          ply:(int)ply
{
  NSArray *moves = [self legalMovesFor:p];
  if (![moves count])
    return [self inCheck:p->black position:p] ? -100000 + ply : 0;
  if (d <= 0)
    return [self evaluate:p] + (int)[moves count] * 2;
  NSArray *ordered = [moves sortedArrayUsingFunction:compareMoves
                                             context:NULL];
  NSEnumerator *e = [ordered objectEnumerator];
  NSValue *v;
  while ((v = [e nextObject]))
    {
      GCPosition q = *p;
      [self apply:GCMoveFromValue (v) to:&q];
      int score = -[self search:&q
                          depth:d - 1
                          alpha:-beta
                           beta:-alpha
                            ply:ply + 1];
      if (score > alpha)
        alpha = score;
      if (alpha >= beta)
        break;
    }
  return alpha;
}
- (GCMove)bestMoveAtDepth:(NSInteger)depth
{
  GCMove best = { -1, -1, 0, 0 };
  int bestScore = INT_MIN + 1;
  NSArray *moves = [self legalMoves];
  NSEnumerator *e = [moves objectEnumerator];
  NSValue *v;
  while ((v = [e nextObject]))
    {
      GCMove m = GCMoveFromValue (v);
      GCPosition q = _p;
      [self apply:m to:&q];
      int s = -[self search:&q
                      depth:(int)MAX (0, depth - 1)
                      alpha:-1000000
                       beta:1000000
                        ply:1];
      if (s > bestScore)
        {
          bestScore = s;
          best = m;
        }
    }
  return best;
}
- (GCMove)variedOpeningMoveAtDepth:(NSInteger)depth
{
  if ([_mutableHistory count] >= 12)
    return [self bestMoveAtDepth:depth];

  int bestScore = INT_MIN + 1;
  NSMutableArray *moves = [NSMutableArray array];
  NSMutableArray *scores = [NSMutableArray array];
  NSEnumerator *enumerator = [[self legalMoves] objectEnumerator];
  NSValue *value;
  while ((value = [enumerator nextObject]))
    {
      GCMove move = GCMoveFromValue (value);
      GCPosition position = _p;
      [self apply:move to:&position];
      int score = -[self search:&position
                          depth:(int)MAX (0, depth - 1)
                          alpha:-1000000
                           beta:1000000
                            ply:1];
      [moves addObject:value];
      [scores addObject:[NSNumber numberWithInt:score]];
      if (score > bestScore)
        bestScore = score;
    }

  /* Vary among a few credible moves rather than sacrificing playing strength. */
  NSMutableArray *candidates = [NSMutableArray arrayWithCapacity:4];
  for (NSUInteger i = 0; i < [moves count] && [candidates count] < 4; i++)
    if ([[scores objectAtIndex:i] intValue] >= bestScore - 50)
      [candidates addObject:[moves objectAtIndex:i]];
  if (![candidates count])
    return [self bestMoveAtDepth:depth];

  NSTimeInterval now = [[NSDate date] timeIntervalSinceReferenceDate];
  NSUInteger choice = (NSUInteger)(now * 1000000.0) % [candidates count];
  return GCMoveFromValue ([candidates objectAtIndex:choice]);
}
@end
