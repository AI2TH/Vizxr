#!/bin/bash
set -e
flutter create --no-pub --project-name vizxr --org com.ai2th --platforms android /tmp/workspace
cd /tmp/workspace
cp -r /app/lib/. lib/
cp /app/pubspec.yaml pubspec.yaml
cp /app/android/app/src/main/AndroidManifest.xml android/app/src/main/AndroidManifest.xml
[ -d /app/assets ] && cp -r /app/assets/. assets/ || true
printf 'flutter.sdk=/opt/flutter\nsdk.dir=/opt/android-sdk\n' > android/local.properties
flutter pub get
flutter build apk --release
mkdir -p /app/build
cp build/app/outputs/flutter-apk/app-release.apk /app/build/vizxr-release.apk
