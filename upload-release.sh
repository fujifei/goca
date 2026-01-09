#!/bin/bash

# 上传构建产物到 GitHub Release
# 用法: ./upload-release.sh <tag> [dist_dir]
# 例如: ./upload-release.sh v1.0.0 dist

set -e

if [ $# -lt 1 ]; then
  echo "用法: $0 <tag> [dist_dir]"
  echo "例如: $0 v1.0.0 dist"
  exit 1
fi

TAG=$1
DIST_DIR=${2:-"dist"}

# 检查目录是否存在
if [ ! -d "$DIST_DIR" ]; then
  echo "错误: 目录 $DIST_DIR 不存在"
  echo "请先运行 ./build-release.sh $TAG 构建产物"
  exit 1
fi

# 获取仓库信息
if [ -z "$GITHUB_REPOSITORY" ]; then
  # 尝试从 git remote 获取
  REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
  if [ -n "$REMOTE_URL" ]; then
    # 解析仓库名，支持多种格式
    if [[ "$REMOTE_URL" =~ github\.com[:/]([^/]+)/([^/]+) ]]; then
      REPO="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
      REPO=${REPO%.git}  # 移除 .git 后缀
    else
      echo "错误: 无法从 git remote 解析仓库信息"
      exit 1
    fi
  else
    echo "错误: 请设置 GITHUB_REPOSITORY 环境变量，格式: owner/repo"
    exit 1
  fi
else
  REPO=$GITHUB_REPOSITORY
fi

echo "仓库: $REPO"
echo "标签: $TAG"
echo "目录: $DIST_DIR"
echo ""

# 检查 GitHub CLI 是否可用
if command -v gh > /dev/null 2>&1; then
  echo "使用 GitHub CLI (gh) 上传..."
  echo ""
  
  # 检查是否已登录
  if ! gh auth status > /dev/null 2>&1; then
    echo "请先登录 GitHub CLI:"
    echo "  gh auth login"
    exit 1
  fi
  
  # 上传所有文件
  for file in "$DIST_DIR"/*.tar.gz "$DIST_DIR"/*.zip "$DIST_DIR"/*.md5; do
    if [ -f "$file" ]; then
      filename=$(basename "$file")
      echo "上传: $filename"
      gh release upload "$TAG" "$file" --repo "$REPO" 2>/dev/null || {
        echo "警告: 上传 $filename 失败，可能文件已存在"
      }
    fi
  done
  
  echo ""
  echo "✓ 上传完成！"
  echo "查看 Release: https://github.com/$REPO/releases/tag/$TAG"
  
elif [ -n "$GITHUB_TOKEN" ]; then
  echo "使用 GitHub API 上传..."
  echo ""
  
  # 获取 release ID
  RELEASE_RESPONSE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$REPO/releases/tags/$TAG")
  
  RELEASE_ID=$(echo "$RELEASE_RESPONSE" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
  
  if [ -z "$RELEASE_ID" ]; then
    echo "错误: 找不到标签 $TAG 对应的 Release"
    echo "请先在 GitHub 上创建 Release: https://github.com/$REPO/releases/new"
    exit 1
  fi
  
  UPLOAD_URL=$(echo "$RELEASE_RESPONSE" | grep -o '"upload_url":"[^"]*' | cut -d'"' -f4)
  UPLOAD_URL=${UPLOAD_URL/\{?name,label\}/}
  
  # 上传所有文件
  for file in "$DIST_DIR"/*.tar.gz "$DIST_DIR"/*.zip "$DIST_DIR"/*.md5; do
    if [ -f "$file" ]; then
      filename=$(basename "$file")
      echo "上传: $filename"
      
      # 确定 Content-Type
      if [[ "$filename" == *.md5 ]]; then
        CONTENT_TYPE="text/plain"
      elif [[ "$filename" == *.zip ]]; then
        CONTENT_TYPE="application/zip"
      else
        CONTENT_TYPE="application/gzip"
      fi
      
      curl -X POST \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Content-Type: $CONTENT_TYPE" \
        --data-binary @"$file" \
        "$UPLOAD_URL?name=$filename" > /dev/null 2>&1 || {
        echo "警告: 上传 $filename 失败，可能文件已存在"
      }
    fi
  done
  
  echo ""
  echo "✓ 上传完成！"
  echo "查看 Release: https://github.com/$REPO/releases/tag/$TAG"
  
else
  echo "错误: 需要以下任一方式："
  echo "  1. 安装 GitHub CLI (gh) 并登录: brew install gh && gh auth login"
  echo "  2. 设置 GITHUB_TOKEN 环境变量"
  echo ""
  echo "获取 GitHub Token:"
  echo "  https://github.com/settings/tokens"
  exit 1
fi

