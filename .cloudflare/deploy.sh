#!/bin/bash
# ============================================================
# FAMHUB Cloudflare Pages Deployment Script
# Single source of truth for production builds
# ============================================================
set -euo pipefail

echo "[DEPLOY] FAMHUB Production Build - $(date -u +'%Y-%m-%dT%H:%M:%SZ')"

# ── Validate required environment variables ──
if [ -z "${SUPABASE_URL:-}" ] || [ -z "${SUPABASE_ANON_KEY:-}" ]; then
  echo "[DEPLOY] ERROR: SUPABASE_URL and SUPABASE_ANON_KEY must be set"
  exit 1
fi

# ── Check Flutter availability ──
FLUTTER_CMD="flutter"
echo "[DEPLOY] Flutter version: $($FLUTTER_CMD --version | head -1)"

# ── Get dependencies (uses cache if available) ──
echo "[DEPLOY] Getting dependencies..."
$FLUTTER_CMD pub get

# ── Production build with WASM ──
echo "[DEPLOY] Building Flutter web (WASM)..."
$FLUTTER_CMD build web --release --wasm \
  --base-href / \
  --source-maps=false \
  --no-pub \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" 2>&1

echo "[DEPLOY] Build complete!"
echo "[DEPLOY] Output: $(du -sh build/web | cut -f1)"
