#!/bin/sh

# Xcode Cloud 전용 — 저장소를 클론한 직후에 실행된다(Apple 정해진 이름·위치).
#
# `moduwa/Resources/Secrets.plist` 는 .gitignore 대상이라 저장소에 없다. 로컬 빌드에는
# 파일이 있지만 클라우드 클론에는 없어서, 여기서 **워크플로 환경변수(Secret)로** 만들어 준다.
# 값 자체는 이 스크립트에 없다 — 저장소에 비밀이 남지 않게 런타임 env 로만 받는다.
#
# App Store Connect → Xcode Cloud → 이 워크플로 → Environment 에 아래 3개를 Secret 으로 등록:
#   MODUWA_API_KEY / KAKAO_NATIVE_APP_KEY / GOOGLE_IOS_CLIENT_ID
# (값은 로컬 moduwa/Resources/Secrets.plist 에 들어 있는 그대로.)

set -e

# 하나라도 비면 껍데기 앱이 나가므로, 조용히 넘어가지 않고 빌드를 여기서 세운다.
: "${MODUWA_API_KEY:?Xcode Cloud 환경변수 MODUWA_API_KEY 가 없습니다}"
: "${KAKAO_NATIVE_APP_KEY:?Xcode Cloud 환경변수 KAKAO_NATIVE_APP_KEY 가 없습니다}"
: "${GOOGLE_IOS_CLIENT_ID:?Xcode Cloud 환경변수 GOOGLE_IOS_CLIENT_ID 가 없습니다}"

PLIST="$CI_PRIMARY_REPOSITORY_PATH/moduwa/Resources/Secrets.plist"

# PlistBuddy 로 만든다 — 값에 특수문자가 있어도 XML 이스케이프를 알아서 처리한다.
rm -f "$PLIST"
/usr/libexec/PlistBuddy \
  -c "Add :MODUWA_API_KEY string $MODUWA_API_KEY" \
  -c "Add :KAKAO_NATIVE_APP_KEY string $KAKAO_NATIVE_APP_KEY" \
  -c "Add :GOOGLE_IOS_CLIENT_ID string $GOOGLE_IOS_CLIENT_ID" \
  "$PLIST"

echo "✅ Secrets.plist 생성됨: $PLIST"
