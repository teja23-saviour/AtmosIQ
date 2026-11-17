#!/usr/bin/env bash
set -euo pipefail
FLUTTER_HOME="${HOME}/.cache/flutter-sdk"
if [ ! -d "${FLUTTER_HOME}/.git" ]; then
  mkdir -p "$(dirname "${FLUTTER_HOME}")"
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "${FLUTTER_HOME}"
fi
export PATH="${FLUTTER_HOME}/bin:${PATH}"
flutter --version
flutter config --enable-web
flutter pub get
flutter build web --release
