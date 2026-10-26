SWIFT_FLAGS = -O -framework Foundation -framework CoreBluetooth -framework CoreGraphics -framework CoreImage -framework AppKit

.PHONY: all build clean install

all: build

build:
	swiftc $(SWIFT_FLAGS) catprinter.swift -o catprinter

clean:
	rm -f catprinter preview*.png *.log

install: build
	install -d /usr/local/bin
	install -m 755 catprinter /usr/local/bin/catprinter
