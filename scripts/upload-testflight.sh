#!/bin/bash
#
# 아카이브 → TestFlight 업로드. **Xcode 를 열지 않고 CLI 만으로** 한다.
#
# 쓰기 전에 한 번만 준비해야 하는 것 (둘 다 이 스크립트가 대신할 수 없다):
#
#  1) App ID `com.waasegye.moduwa` 의 권한 두 개
#     developer.apple.com → Identifiers → 이 App ID →
#       · Push Notifications  체크
#       · Sign in with Apple  체크  → Save
#     ⚠️ 안 켜면 **아카이브 서명이 실패한다** — 엔타이틀먼트에 있는 권한이 프로파일에 없으면
#        배포 프로파일을 만들 수 없다("doesn't support the ... capability").
#
#  2) App Store Connect API 키 (업로드 인증)
#     App Store Connect → 사용자 및 액세스 → 통합 → App Store Connect API → 키 생성
#       · 역할은 **App Manager** 이상
#       · 내려받은 `AuthKey_XXXXXXXXXX.p8` 을 `~/.private_keys/` 에 둔다(한 번만 내려받을 수 있다)
#     그리고 아래 세 값을 환경변수로 준다:
#       export ASC_KEY_ID=XXXXXXXXXX
#       export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
#       export ASC_KEY_PATH=~/.private_keys/AuthKey_XXXXXXXXXX.p8   # 생략하면 위 규칙으로 찾는다
#
# 실행:
#   scripts/upload-testflight.sh
#
# 업로드가 끝나도 **테스트 노트는 따로 넣어야 한다** — "테스트할 내용" 은 ipa 에 들어가지 않는다.
#  `TestFlight/WhatToTest.ko.txt` 를 App Store Connect → TestFlight → 해당 빌드에 붙여넣는다.
#  (Xcode Cloud 로 올릴 때만 그 파일이 자동으로 읽힌다.)
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT=$(pwd)
BUILD_DIR="$ROOT/build/testflight"
ARCHIVE="$BUILD_DIR/moduwa.xcarchive"

KEY_ID=${ASC_KEY_ID:-}
ISSUER_ID=${ASC_ISSUER_ID:-}
KEY_PATH=${ASC_KEY_PATH:-"$HOME/.private_keys/AuthKey_${KEY_ID}.p8"}

if [[ -z "$KEY_ID" || -z "$ISSUER_ID" ]]; then
  echo "✗ ASC_KEY_ID / ASC_ISSUER_ID 가 없다. 이 파일 위쪽 주석의 2) 를 먼저 하세요." >&2
  exit 1
fi
if [[ ! -f "$KEY_PATH" ]]; then
  echo "✗ API 키 파일이 없다: $KEY_PATH" >&2
  exit 1
fi

VERSION=$(grep -m1 "MARKETING_VERSION" moduwa.xcodeproj/project.pbxproj | sed 's/.*= *//; s/;//')
BUILD=$(grep -m1 "CURRENT_PROJECT_VERSION" moduwa.xcodeproj/project.pbxproj | sed 's/.*= *//; s/;//')
echo "▶ 올릴 버전: $VERSION ($BUILD)"

# 시크릿이 번들에 들어가는 앱이다 — 없으면 라이브 API 가 죽은 채로 올라간다.
if [[ ! -f moduwa/Resources/Secrets.plist ]]; then
  echo "✗ moduwa/Resources/Secrets.plist 가 없다. 이대로 올리면 서버 연동이 죽는다." >&2
  exit 1
fi

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "▶ 아카이브"
# `-allowProvisioningUpdates`: 배포 인증서·프로파일이 없으면 Xcode 가 만들어 받아 온다.
#  이 머신에는 개발용 인증서만 있어서 이 옵션이 없으면 실패한다.
xcodebuild archive \
  -project moduwa.xcodeproj \
  -scheme moduwa \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$KEY_PATH" \
  -authenticationKeyID "$KEY_ID" \
  -authenticationKeyIssuerID "$ISSUER_ID" \
  | tail -5

echo "▶ 내보내기 + 업로드 (ExportOptions 의 destination=upload)"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist scripts/ExportOptions.plist \
  -exportPath "$BUILD_DIR/export" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$KEY_PATH" \
  -authenticationKeyID "$KEY_ID" \
  -authenticationKeyIssuerID "$ISSUER_ID" \
  | tail -10

cat <<EOF

✅ 업로드 요청 완료 — $VERSION ($BUILD)

남은 일 (App Store Connect 에서):
  1. 처리(Processing)가 끝날 때까지 기다린다 — 보통 5~15분. 끝나면 메일이 온다.
  2. TestFlight → 해당 빌드 → **"테스트할 내용"** 에 아래 파일 내용을 붙여넣는다:
       TestFlight/WhatToTest.ko.txt
  3. 내부 테스터 그룹에 빌드를 넣는다(이미 넣어 뒀으면 자동으로 배포된다).
EOF
