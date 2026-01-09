#!/bin/bash

# 构建脚本：支持多平台构建 goc
# 用法: ./build-release.sh [version]
# 例如: ./build-release.sh v1.0.0

set -e

VERSION=${1:-"dev"}
PROJECT_NAME="goc"
BUILD_DIR="dist"

# 支持的平台列表
PLATFORMS=(
  "linux/amd64"
  "darwin/amd64"
  "darwin/arm64"
  "windows/amd64"
)

# 清理并创建构建目录
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "Building $PROJECT_NAME version: $VERSION"
echo "=========================================="

# 遍历所有平台进行构建
for PLATFORM in "${PLATFORMS[@]}"; do
  GOOS=${PLATFORM%%/*}
  GOARCH=${PLATFORM##*/}
  
  OUTPUT_NAME="$PROJECT_NAME"
  ARCHIVE_NAME="$PROJECT_NAME-$VERSION-$GOOS-$GOARCH"
  
  # Windows 平台需要 .exe 后缀
  if [ "$GOOS" = "windows" ]; then
    OUTPUT_NAME="${OUTPUT_NAME}.exe"
    ARCHIVE_NAME="${ARCHIVE_NAME}.zip"
  else
    ARCHIVE_NAME="${ARCHIVE_NAME}.tar.gz"
  fi
  
  echo ""
  echo "Building for $GOOS/$GOARCH..."
  echo "  Output: $OUTPUT_NAME"
  echo "  Archive: $ARCHIVE_NAME"
  
  # 构建
  CGO_ENABLED=0 GOOS=$GOOS GOARCH=$GOARCH go build \
    -ldflags "-X 'github.com/qiniu/goc/cmd.version=${VERSION}'" \
    -o "$BUILD_DIR/$OUTPUT_NAME" .
  
  # 创建压缩包
  cd "$BUILD_DIR"
  if [ "$GOOS" = "windows" ]; then
    zip "$ARCHIVE_NAME" "$OUTPUT_NAME" > /dev/null
  else
    tar czf "$ARCHIVE_NAME" "$OUTPUT_NAME"
  fi
  
  # 计算校验和
  if command -v md5sum > /dev/null; then
    md5sum "$ARCHIVE_NAME" > "${ARCHIVE_NAME}.md5"
  elif command -v md5 > /dev/null; then
    md5 -q "$ARCHIVE_NAME" | awk '{print $1 "  " "'"$ARCHIVE_NAME"'"}' > "${ARCHIVE_NAME}.md5"
  fi
  
  # 清理临时文件
  rm "$OUTPUT_NAME"
  cd ..
  
  echo "  ✓ Built successfully"
done

echo ""
echo "=========================================="
echo "Build completed! All artifacts are in: $BUILD_DIR/"
echo ""
echo "Generated files:"
ls -lh "$BUILD_DIR" | grep -E "\.(tar\.gz|zip|md5)$" || true

