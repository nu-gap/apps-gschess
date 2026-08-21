#import "AppDelegate.h"
#import <AppKit/AppKit.h>
int
main (int argc, const char *argv[])
{
  NSAutoreleasePool *pool;
  NSApplication *app;
  AppDelegate *delegate;

  (void)argc;
  (void)argv;
  pool = [[NSAutoreleasePool alloc] init];
  app = [NSApplication sharedApplication];
  delegate = [[AppDelegate alloc] init];
  [app setDelegate:delegate];
  [app run];
  [delegate release];
  [pool drain];
  return 0;
}
