#!/bin/zsh
# 콜록 iOS 아카이브 → TestFlight 업로드.
# App Store Connect API 키(팀 키, 관리자)로 배포 인증서·프로파일을 클라우드에서 자동 생성한다.
#
# 프로젝트에는 개발용 수동 프로파일(fastlane match)이 고정돼 있어, 아카이브 때만 자동 서명으로 덮어쓴다.
#
# 필요 환경변수 (키 파일은 저장소 밖에 둘 것 — git·메신저에 올리지 말 것):
#   ASC_KEY_PATH   AuthKey_<KeyID>.p8 경로
#   ASC_KEY_ID     Key ID (10자리)
#   ASC_ISSUER_ID  Issuer ID (팀 키는 필수, 개인 키는 생략)
# 선택:
#   BUILD_NUMBER   지정하면 CURRENT_PROJECT_VERSION 을 이 값으로 아카이브 (지난 업로드보다 커야 함)
#   REVENUECAT_API_KEY  RevenueCat 공개 SDK 키(appl_…). 비우면 결제 화면이 「결제를 준비하고 있어요」만 보인다
set -euo pipefail
cd "${0:A:h}/.."

: "${ASC_KEY_PATH:?ASC_KEY_PATH 를 설정하세요}"
: "${ASC_KEY_ID:?ASC_KEY_ID 를 설정하세요}"
[[ -f "$ASC_KEY_PATH" ]] || { echo "키 파일이 없어요: $ASC_KEY_PATH" >&2; exit 1; }

OUT="build/testflight"
ARCHIVE="$OUT/collog-ios.xcarchive"
rm -rf "$OUT"; mkdir -p "$OUT"

AUTH=(-allowProvisioningUpdates
      -authenticationKeyPath "$ASC_KEY_PATH"
      -authenticationKeyID "$ASC_KEY_ID")
[[ -n "${ASC_ISSUER_ID:-}" ]] && AUTH+=(-authenticationKeyIssuerID "$ASC_ISSUER_ID")

EXTRA=()
[[ -n "${BUILD_NUMBER:-}" ]] && EXTRA+=(CURRENT_PROJECT_VERSION="$BUILD_NUMBER")
[[ -n "${REVENUECAT_API_KEY:-}" ]] && EXTRA+=(REVENUECAT_API_KEY="$REVENUECAT_API_KEY")
[[ -z "${REVENUECAT_API_KEY:-}" ]] && echo "경고: REVENUECAT_API_KEY 가 비어 있어요. 이 빌드의 결제 화면은 「결제를 준비하고 있어요」만 보여요." >&2
[[ -n "${REVENUECAT_API_KEY:-}" && "$REVENUECAT_API_KEY" != appl_* ]] && echo "경고: REVENUECAT_API_KEY 가 appl_ 로 시작하지 않아 앱이 키 없음으로 봐요." >&2

xcodebuild archive \
  -project collog-ios.xcodeproj -scheme collog-ios -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" \
  CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM=3X4434LYHD \
  CODE_SIGN_IDENTITY="Apple Development" PROVISIONING_PROFILE_SPECIFIER="" \
  "${AUTH[@]}" "${EXTRA[@]}"

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" -exportPath "$OUT/export" \
  -exportOptionsPlist scripts/ExportOptions.plist \
  "${AUTH[@]}"

echo "업로드 완료. App Store Connect → TestFlight 에서 처리 상태를 확인하세요."
