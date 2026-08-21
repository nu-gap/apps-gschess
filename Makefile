.PHONY: mac gnustep test clean

APP=GrandmasterChess
SOURCES=main.m AppDelegate.m ChessGame.m ChessBoardView.m CapturedPiecesView.m

mac:
	mkdir -p build/$(APP).app/Contents/MacOS build/$(APP).app/Contents/Resources
	clang -fmodules -framework Cocoa -O2 -Wall -Wextra $(SOURCES) -o build/$(APP).app/Contents/MacOS/$(APP)
	cp Resources/pieces.png Resources/app-icon.png Resources/app-icon.icns build/$(APP).app/Contents/Resources/
	cp Resources/Info.plist build/$(APP).app/Contents/Info.plist

gnustep:
	$(MAKE) -f Makefile.gnustep MAKEFILE_NAME=Makefile.gnustep

test:
	mkdir -p build
	clang -fmodules -framework Foundation -O2 ChessGame.m Tests/EngineTests.m -I. -o build/EngineTests
	./build/EngineTests

clean:
	rm -rf build $(APP).app obj
