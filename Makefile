# Makefile for FastDMG

release: clean build size

build_unsigned:
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

build:
	mkdir -p products
	xattr -w com.apple.xcode.CreatedByBuildSystem true products
	xcodebuild  -parallelizeTargets \
	            -project "FastDMG.xcodeproj" \
	            -target "FastDMG" \
	            -configuration "Release" \
	            CONFIGURATION_BUILD_DIR="products" \
	            clean build

size:
	@echo "App size:"
	@du -hs products/FastDMG.app
	@echo "Binary size:"
	@du -hs products/FastDMG.app/Contents/MacOS/*

clean:
	xattr -w com.apple.xcode.CreatedByBuildSystem true products
	xcodebuild -project "FastDMG.xcodeproj" clean
	rm -rf products/* 2> /dev/null
