#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ASSETS="$PROJECT_DIR/assets"
TMP_DIR=$(mktemp -d)

mkdir -p "$ASSETS"

echo "=== NyanBar Screenshot & GIF Capture ==="
echo ""
echo "이 스크립트는 macOS 화면 녹화 기능을 사용합니다."
echo "화면 녹화 권한이 필요합니다:"
echo "  시스템 설정 > 개인정보 보호 > 화면 녹화 > 터미널 앱 허용"
echo ""

# ---- 1. Menu bar screenshot ----
echo "[1/3] 메뉴바 스크린샷"
echo "  NyanBar 아이콘이 보이는 메뉴바 영역을 드래그로 선택해주세요."
echo "  (Crosshair가 나타나면 메뉴바 영역을 드래그)"
echo ""
read -p "  준비되면 ENTER..." -r
screencapture -i -x "$ASSETS/menubar-preview.png"
if [ -f "$ASSETS/menubar-preview.png" ]; then
    echo "  -> menubar-preview.png ($(du -h "$ASSETS/menubar-preview.png" | cut -f1))"
else
    echo "  -> 스킵됨"
fi

# ---- 2. Dashboard screenshot ----
echo ""
echo "[2/3] 대시보드 스크린샷"
echo "  1. NyanBar 아이콘을 클릭해서 팝오버를 열어주세요"
echo "  2. 팝오버가 열린 상태에서 ENTER를 눌러주세요"
echo ""
read -p "  준비되면 ENTER..." -r
screencapture -i -x "$ASSETS/dashboard-preview.png"
if [ -f "$ASSETS/dashboard-preview.png" ]; then
    echo "  -> dashboard-preview.png ($(du -h "$ASSETS/dashboard-preview.png" | cut -f1))"
else
    echo "  -> 스킵됨"
fi

# ---- 3. Menu bar animation GIF ----
echo ""
echo "[3/3] 메뉴바 애니메이션 GIF (5초 녹화)"
echo "  macOS 화면 녹화를 사용합니다."
echo ""
echo "  방법:"
echo "    1. Cmd+Shift+5 로 화면 녹화 시작"
echo "    2. 메뉴바 영역만 선택해서 녹화"
echo "    3. 5초 후 녹화 중지"
echo "    4. 녹화된 파일을 assets/ 폴더에 menubar-recording.mov로 저장"
echo ""
echo "  또는 mov 파일이 이미 있다면 경로를 입력해주세요."
echo "  (스킵하려면 그냥 ENTER)"
echo ""
read -p "  .mov 파일 경로 (또는 ENTER로 스킵): " MOV_PATH

if [ -n "$MOV_PATH" ] && [ -f "$MOV_PATH" ]; then
    echo "  Converting to GIF..."
    ffmpeg -y -i "$MOV_PATH" \
        -vf "fps=15,scale=600:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse=dither=bayer" \
        -loop 0 \
        "$ASSETS/menubar-animation.gif" 2>/dev/null
    echo "  -> menubar-animation.gif ($(du -h "$ASSETS/menubar-animation.gif" | cut -f1))"
else
    echo "  -> 스킵됨"
    echo ""
    echo "  나중에 변환하려면:"
    echo "  ffmpeg -i recording.mov -vf \"fps=15,scale=600:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse\" -loop 0 assets/menubar-animation.gif"
fi

# Cleanup
rm -rf "$TMP_DIR"

echo ""
echo "=== 완료! ==="
echo ""
ls -lh "$ASSETS" 2>/dev/null
echo ""
echo "다음 단계: git add assets/ && git commit -m 'docs: add screenshots'"
