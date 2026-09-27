#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
flutter_version="3.41.2"
flutter_bin="$(command -v flutter || true)"

if [[ -z "$flutter_bin" ]]; then
  sdk_dir="$repo_root/.vercel-flutter"
  if [[ ! -x "$sdk_dir/bin/flutter" ]]; then
    git clone --depth 1 --branch "$flutter_version" https://github.com/flutter/flutter.git "$sdk_dir"
  fi
  flutter_bin="$sdk_dir/bin/flutter"
fi

defines=()
if [[ -n "${SUPABASE_URL:-}" || -n "${SUPABASE_ANON_KEY:-}" ]]; then
  if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_ANON_KEY:-}" ]]; then
    echo "Both SUPABASE_URL and SUPABASE_ANON_KEY are required when configuring the web backend." >&2
    exit 1
  fi
  defines+=("--dart-define=SUPABASE_URL=$SUPABASE_URL")
  defines+=("--dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY")
fi

cd "$repo_root/project"
build_id="$(git rev-parse HEAD)-$(date -u +%Y%m%d%H%M%S)"
"$flutter_bin" pub get
"$flutter_bin" build web --release --no-tree-shake-icons "--dart-define=HADAYAH_BUILD_ID=$build_id" "${defines[@]}"
node tool/stamp_offline_build.mjs build/web "$build_id"
test -s build/web/index.html
