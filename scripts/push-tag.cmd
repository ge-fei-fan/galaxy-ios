@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo.
echo ===== 当前本地 Tags =====
set "HAS_TAG=0"
for /f "delims=" %%i in ('git tag') do (
  echo %%i
  set "HAS_TAG=1"
)
if "!HAS_TAG!"=="0" (
  echo (暂无本地 Tag)
)
echo ========================
echo.

set /p TAG=请输入要推送的 Tag（例如 v1.0.0）：
if "%TAG%"=="" (
  echo Tag 不能为空。
  exit /b 1
)

git rev-parse "%TAG%" >nul 2>&1
if !errorlevel!==0 (
  echo Tag "%TAG%" 已存在，将直接推送远端。
) else (
  echo 创建 Tag "%TAG%"...
  git tag "%TAG%"
  if !errorlevel! neq 0 (
    echo 创建 Tag 失败。
    exit /b 1
  )
)

echo 推送 Tag 到远端...
git push origin "%TAG%"
if !errorlevel! neq 0 (
  echo 推送失败，请检查网络或权限。
  echo.
  pause
  exit /b 1
)

echo.
echo ===== 推送结果1 =====
git ls-remote --tags origin "%TAG%"
echo ==================
echo.
echo 完成！Tag "%TAG%" 已推送。
echo 按任意键退出...
pause >nul
endlocal