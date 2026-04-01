#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
IMAGE_NAME="vizxr-builder"
BUILD_TYPE="${1:-debug}"
OUTPUT_DIR="${PROJECT_ROOT}/build"

mkdir -p "${OUTPUT_DIR}"

if ! docker image inspect "${IMAGE_NAME}" &>/dev/null; then
    echo "=== Building Docker build environment ==="
    docker build -t "${IMAGE_NAME}" -f "${PROJECT_ROOT}/docker/Dockerfile.build" "${PROJECT_ROOT}"
fi

echo "=== Building Vizxr APK (${BUILD_TYPE}) inside Docker ==="

docker run --rm \
    -v "${PROJECT_ROOT}:/src:ro" \
    -v "${OUTPUT_DIR}:/out" \
    "${IMAGE_NAME}" \
    bash -c "
set -e
flutter create --no-pub --project-name vizxr --org com.ai2th --platforms android /tmp/workspace
cd /tmp/workspace
cp -r /src/lib/. lib/
cp /src/pubspec.yaml pubspec.yaml
cp /src/android/app/src/main/AndroidManifest.xml android/app/src/main/AndroidManifest.xml
# Add assets if present
[ -d /src/assets ] && cp -r /src/assets/. assets/ || true

printf 'flutter.sdk=/opt/flutter\nsdk.dir=/opt/android-sdk\n' > android/local.properties
flutter pub get
flutter build apk --${BUILD_TYPE}
cp build/app/outputs/flutter-apk/app-${BUILD_TYPE}.apk /out/vizxr-${BUILD_TYPE}.apk
"

echo "✅ Build complete: ${OUTPUT_DIR}/vizxr-${BUILD_TYPE}.apk"

if [ -n "$DOCKER_USERNAME" ] && [ -n "$DOCKER_PASSWORD" ]; then
    echo "=== Pushing Artifact to Registry ==="
    echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin
    
    # Wrap APK in a minimal image for storage in registry
    cat <<EOF > "${OUTPUT_DIR}/Dockerfile.artifact"
FROM scratch
COPY vizxr-${BUILD_TYPE}.apk /vizxr-${BUILD_TYPE}.apk
EOF
    
    IMAGE_TAG="${DOCKER_USERNAME}/vizxr:${BUILD_TYPE}"
    docker build -t "\$IMAGE_TAG" -f "${OUTPUT_DIR}/Dockerfile.artifact" "${OUTPUT_DIR}"
    docker push "\$IMAGE_TAG"
    echo "✅ Artifact pushed: \$IMAGE_TAG"
fi
