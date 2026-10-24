#!/usr/bin/env bash
# Build do app web no Vercel (chamado pelo vercel.json). O Vercel não traz o
# Flutter: baixa a versão fixada abaixo e compila com as variáveis do projeto
# (Vercel > Settings > Environment Variables).
set -euo pipefail

FLUTTER_VERSION="3.47.7"

: "${SUPABASE_URL:?Defina SUPABASE_URL nas variáveis de ambiente do projeto no Vercel}"
: "${SUPABASE_ANON_KEY:?Defina SUPABASE_ANON_KEY nas variáveis de ambiente do projeto no Vercel}"

if [ ! -x .flutter/bin/flutter ]; then
  git clone --quiet --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git .flutter
fi
export PATH="$PWD/.flutter/bin:$PATH"
flutter config --no-analytics > /dev/null

cd freelanceflow
flutter pub get
flutter build web --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
