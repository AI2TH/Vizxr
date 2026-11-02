#!/bin/bash
set -e
export MSYS_NO_PATHCONV=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && (pwd -W 2>/dev/null || pwd))"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && (pwd -W 2>/dev/null || pwd))"
BUILD_TYPE="${1:-release}"
OUTPUT_DIR="${PROJECT_ROOT}/build"
IMAGE_NAME="${IMAGE_NAME:-localhost/linxr-builder:latest}"

if [ -n "${USERPROFILE}" ] && [ -d "${USERPROFILE}/.gradle" ]; then
    GRADLE_DIR="${USERPROFILE}/.gradle"
elif [ -d "${HOME}/.gradle" ]; then
    GRADLE_DIR="${HOME}/.gradle"
else
    mkdir -p "${HOME}/.gradle"
    GRADLE_DIR="${HOME}/.gradle"
fi
GRADLE_DIR="${GRADLE_DIR//\\//}"

if command -v podman &>/dev/null; then
    CONTAINER_CMD="podman"
elif command -v docker &>/dev/null; then
    CONTAINER_CMD="docker"
else
    echo "ERROR: Neither podman nor docker found in PATH."
    exit 1
fi

mkdir -p "${OUTPUT_DIR}"

echo "=== Building Vizxr APK (${BUILD_TYPE}) inside ${CONTAINER_CMD} ==="
echo "Project : ${PROJECT_ROOT}"
echo "Image   : ${IMAGE_NAME}"
echo "Output  : ${OUTPUT_DIR}/vizxr-${BUILD_TYPE}.apk"

"${CONTAINER_CMD}" run --rm \
    --platform linux/amd64 \
    -v "${PROJECT_ROOT}:/src:ro" \
    -v "${OUTPUT_DIR}:/out" \
    -v "${GRADLE_DIR}:/root/.gradle" \
    "${IMAGE_NAME}" \
    bash -c '
set -e
git config --global --add safe.directory /opt/flutter 2>/dev/null || true

echo "--- Step 1: Scaffold fresh workspace ---"
flutter create --no-pub --project-name vizxr --org com.ai2th --platforms android /tmp/workspace
cd /tmp/workspace

echo "--- Step 2: Apply Vizxr sources ---"
cp -r /src/lib/. lib/
cp /src/pubspec.yaml pubspec.yaml
cp /src/android/app/src/main/AndroidManifest.xml android/app/src/main/AndroidManifest.xml
[ -d /src/assets ] && cp -r /src/assets/. assets/ || true

echo "--- Step 2b: Fix Gradle wrapper to 8.11.1 ---"
sed -i "s|distributionUrl=.*|distributionUrl=https\://services.gradle.org/distributions/gradle-8.11.1-bin.zip|" \
    android/gradle/wrapper/gradle-wrapper.properties

printf "flutter.sdk=/opt/flutter\nsdk.dir=/opt/android-sdk\n" > android/local.properties

echo "--- Step 3: flutter pub get ---"
flutter pub get

echo "--- Step 4: flutter build apk ---"
export GRADLE_OPTS="-Dorg.gradle.daemon=false -Xmx3g -Dorg.gradle.internal.http.connectionTimeout=60000 -Dorg.gradle.internal.http.socketTimeout=60000"
flutter build apk --'"${BUILD_TYPE}"' --no-tree-shake-icons

echo "--- Step 5: Copy APK to output ---"
cp build/app/outputs/flutter-apk/app-'"${BUILD_TYPE}"'.apk /out/vizxr-'"${BUILD_TYPE}"'.apk
echo "APK size: $(du -sh /out/vizxr-'"${BUILD_TYPE}"'.apk | cut -f1)"
'

echo "✅ Vizxr APK build complete: ${OUTPUT_DIR}/vizxr-${BUILD_TYPE}.apk"
