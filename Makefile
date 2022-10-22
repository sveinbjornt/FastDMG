# Makefile for FastDMG

all: build

build:
	mkdir -p products
	xattr -w com.apple.xcode.CreatedByBuildSystem true products
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
	xattr -w com.apple.xcode.CreatedByBuildSystem true products
	xcodebuild -project "FastDMG.xcodeproj" clean
	rm -rf products/* 2> /dev/null
