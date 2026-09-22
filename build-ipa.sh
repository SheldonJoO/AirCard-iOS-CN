#!/bin/bash
set -euo pipefail

CONFIG="${1:-Release}"

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

echo "==> 正在构建 AirCard-iOS（$CONFIG）..."
rm -rf build/DerivedData build/Payload build/*.app build/*.ipa
mkdir -p build

xcodebuild -project AirCard-iOS.xcodeproj \
    -scheme AirCard-iOS \
    -configuration "$CONFIG" \
    -derivedDataPath build/DerivedData \
    -destination 'generic/platform=iOS' \
    clean build \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGN_ENTITLEMENTS="" CODE_SIGNING_ALLOWED="NO"

APP_PATH="$(find build/DerivedData/Build/Products -name "AirCard-iOS.app" -type d | head -n 1)"
if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "错误：在 DerivedData 中找不到 AirCard-iOS.app"
    exit 1
fi

echo "==> 正在打包 IPA..."
cp -R "$APP_PATH" build/AirCard-iOS.app

# 清理已有的签名
rm -rf build/AirCard-iOS.app/_CodeSignature
rm -rf build/AirCard-iOS.app/embedded.mobileprovision

mkdir -p build/Payload
cp -R build/AirCard-iOS.app build/Payload/AirCard-iOS.app

cd build
zip -qr "AirCard-iOS.ipa" Payload
rm -rf Payload AirCard-iOS.app

echo "==> 完成！IPA 已生成：$ROOT/build/AirCard-iOS.ipa"
ls -lh "$ROOT/build/AirCard-iOS.ipa"
