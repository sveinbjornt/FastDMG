rm -r fastdmg.iconset &> /dev/null
mkdir fastdmg.iconset
sips -z 16 16   fastdmg.png --out fastdmg.iconset/icon_16x16.png
sips -z 32 32   fastdmg.png --out fastdmg.iconset/icon_16x16@2x.png
sips -z 32 32   fastdmg.png --out fastdmg.iconset/icon_32x32.png
sips -z 64 64   fastdmg.png --out fastdmg.iconset/icon_32x32@2x.png
sips -z 128 128 fastdmg.png --out fastdmg.iconset/icon_128x128.png
sips -z 256 256 fastdmg.png --out fastdmg.iconset/icon_128x128@2x.png
sips -z 256 256 fastdmg.png --out fastdmg.iconset/icon_256x256.png
sips -z 512 512 fastdmg.png --out fastdmg.iconset/icon_256x256@2x.png
sips -z 512 512 fastdmg.png --out fastdmg.iconset/icon_512x512.png
cp fastdmg.png fastdmg.iconset/icon_512x512@2x.png
# Run through ImageOptim...
# iconutil -c icns fastdmg.iconset
# ./createicns fastdmg.iconset
