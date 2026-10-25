#!/usr/bin/env bash
# Build do site no Vercel (chamado pelo vercel.json): a homepage (site/) fica na
# raiz e o app Flutter em /app/. O Vercel não traz o Flutter: baixa a versão
# fixada abaixo e compila com as variáveis do projeto
# (Vercel > Settings > Environment Variables). SENTRY_DSN é opcional.
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
flutter build web --release --base-href /app/ \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"   --dart-define=SENTRY_DSN="${SENTRY_DSN:-}"   --dart-define=SENTRY_ENVIRONMENT="${VERCEL_ENV:-production}"

# Monta a saída publicada: homepage na raiz, app em /app/.
cd ..
rm -rf dist
mkdir -p dist
cp -R site/. dist/
node scripts/site-seo.mjs dist/index.html
cp -R freelanceflow/build/web dist/app
# Quem tinha o app aberto na raiz recebe o service worker de limpeza do Flutter,
# que se desregistra e recarrega a página (agora a homepage).
cp freelanceflow/build/web/flutter_service_worker.js dist/
