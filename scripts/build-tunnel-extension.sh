#!/bin/bash
# ============================================================================
# build-tunnel-extension.sh
# 使用 swiftc 独立编译 PacketTunnelExtension 并 embed 到 Runner.app
# 用于 CI 免签构建 + TrollStore 安装
# ============================================================================

set -euo pipefail

# --- 参数 ---
APP_PATH="${1:-build/ios/iphoneos/Runner.app}"
EXTENSION_NAME="PacketTunnelExtension"
EXTENSION_SRC="ios/PacketTunnelExtension/PacketTunnelProvider.swift"
EXTENSION_INFO_PLIST="ios/PacketTunnelExtension/Info.plist"
EXTENSION_ENTITLEMENTS="ios/PacketTunnelExtension/PacketTunnelExtension.entitlements"
RUNNER_ENTITLEMENTS="ios/Runner/Runner.entitlements"

# --- 编译目录 ---
BUILD_DIR="build/tunnel_extension"
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

echo "=========================================="
echo "📦 Building PacketTunnelExtension"
echo "=========================================="

# --- 检测 SDK ---
SDK_PATH=$(xcrun --sdk iphoneos --show-sdk-path)
SWIFT_TARGET="arm64-apple-ios14.0"

echo "📦 SDK: ${SDK_PATH}"
echo "🎯 Target: ${SWIFT_TARGET}"

# --- 1. 编译 Swift 源码为 App Extension 可执行文件 ---
echo ""
echo "🔨 Step 1: Compiling PacketTunnelProvider.swift ..."

# 关键点：
# - `-e _NSExtensionMain` 指定 Extension 入口点（不是普通的 main）
# - `-rpath` 设置运行时库搜索路径
xcrun swiftc \
  -target "${SWIFT_TARGET}" \
  -sdk "${SDK_PATH}" \
  -parse-as-library \
  -module-name "${EXTENSION_NAME}" \
  -Xlinker -e -Xlinker _NSExtensionMain \
  -Xlinker -rpath -Xlinker @executable_path/Frameworks \
  -Xlinker -rpath -Xlinker @executable_path/../../Frameworks \
  -framework NetworkExtension \
  -framework Foundation \
  -o "${BUILD_DIR}/${EXTENSION_NAME}" \
  "${EXTENSION_SRC}"

echo "✅ Compilation successful"

# --- 2. 构建 .appex 包 ---
echo ""
echo "📁 Step 2: Creating .appex bundle ..."

APPEX_DIR="${BUILD_DIR}/${EXTENSION_NAME}.appex"
mkdir -p "${APPEX_DIR}"

cp "${BUILD_DIR}/${EXTENSION_NAME}" "${APPEX_DIR}/${EXTENSION_NAME}"
cp "${EXTENSION_INFO_PLIST}" "${APPEX_DIR}/Info.plist"

echo "✅ .appex bundle created: ${APPEX_DIR}"

# --- 3. Embed 到 Runner.app/PlugIns ---
echo ""
echo "📲 Step 3: Embedding into Runner.app ..."

PLUGINS_DIR="${APP_PATH}/PlugIns"
mkdir -p "${PLUGINS_DIR}"
rm -rf "${PLUGINS_DIR}/${EXTENSION_NAME}.appex"
cp -R "${APPEX_DIR}" "${PLUGINS_DIR}/"

echo "✅ Extension embedded: ${PLUGINS_DIR}/${EXTENSION_NAME}.appex"

# --- 4. 注入 entitlements（TrollStore 必需） ---
echo ""
echo "🔐 Step 4: Injecting entitlements with ldid ..."

if command -v ldid &> /dev/null; then
  echo "   Injecting entitlements for Extension..."
  ldid -S"${EXTENSION_ENTITLEMENTS}" "${PLUGINS_DIR}/${EXTENSION_NAME}.appex/${EXTENSION_NAME}"
  echo "   Injecting entitlements for Runner..."
  ldid -S"${RUNNER_ENTITLEMENTS}" "${APP_PATH}/Runner"
  echo "✅ Entitlements injected successfully (TrollStore compatible)"
else
  echo "❌ ERROR: ldid not found! TrollStore requires entitlements to be embedded."
  echo "   Install with: brew install ldid"
  exit 1
fi

# --- 5. 验证结构 ---
echo ""
echo "=========================================="
echo "🎉 Build completed successfully!"
echo "=========================================="
echo ""
echo "📂 App structure:"
echo "   ${APP_PATH}/"
echo "   ├── Runner"
echo "   ├── Info.plist"
echo "   ├── PlugIns/"
echo "   │   └── ${EXTENSION_NAME}.appex/"
echo "   │       ├── ${EXTENSION_NAME}"
echo "   │       └── Info.plist"
echo "   └── ..."
echo ""

# 验证文件存在
if [ -f "${PLUGINS_DIR}/${EXTENSION_NAME}.appex/${EXTENSION_NAME}" ]; then
  echo "✅ Extension binary exists"
  file "${PLUGINS_DIR}/${EXTENSION_NAME}.appex/${EXTENSION_NAME}"
else
  echo "❌ ERROR: Extension binary not found!"
  exit 1
fi

# 验证 entitlements
echo ""
echo "🔍 Verifying entitlements..."
echo "--- Runner entitlements ---"
ldid -e "${APP_PATH}/Runner" 2>/dev/null || echo "(could not read)"
echo ""
echo "--- Extension entitlements ---"
ldid -e "${PLUGINS_DIR}/${EXTENSION_NAME}.appex/${EXTENSION_NAME}" 2>/dev/null || echo "(could not read)"
