# Makefile for FastDMG

all: build

build:
	mkdir -p products
	xcodebuild  -parallelizeTargets \
	            -project "FastDMG.xcodeproj" \
	            -target "FastDMG" \
	            -configuration "Release" \
	            CONFIGURATION_BUILD_DIR="products" \
	            CODE_SIGN_IDENTITY="" \
	            CODE_SIGNING_REQUIRED=NO \
	            clean build
	@echo "Binary size:"
	@stat -f %z products/FastDMG.app/Contents/MacOS/*

clean:
	xcodebuild -project "FastDMG.xcodeproj" clean
	rm -rf products/* 2> /dev/null
