#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Generate the Android host with the pinned Flutter version used in CI.
flutter create --platforms=android --org vn.bannie --project-name nhac_viec --empty .
python3 scripts/configure_android.py
mkdir -p assets/fonts
if [[ ! -s assets/fonts/BeVietnamPro-Regular.ttf ]]; then
  curl --fail --location --retry 3 'https://raw.githubusercontent.com/google/fonts/main/ofl/bevietnampro/BeVietnamPro-Regular.ttf' -o assets/fonts/BeVietnamPro-Regular.ttf
  curl --fail --location --retry 3 'https://raw.githubusercontent.com/google/fonts/main/ofl/bevietnampro/BeVietnamPro-SemiBold.ttf' -o assets/fonts/BeVietnamPro-SemiBold.ttf
  curl --fail --location --retry 3 'https://raw.githubusercontent.com/google/fonts/main/ofl/bevietnampro/OFL.txt' -o assets/fonts/OFL.txt
fi
python3 - <<'PY'
from pathlib import Path
p=Path('pubspec.yaml')
s=p.read_text()
if 'fonts:' not in s:
    p.write_text(s+'''  fonts:
    - family: BeVietnamPro
      fonts:
        - asset: assets/fonts/BeVietnamPro-Regular.ttf
        - asset: assets/fonts/BeVietnamPro-SemiBold.ttf
          weight: 600
''')
PY
flutter pub get
