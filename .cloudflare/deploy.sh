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

# ── Warn if URL uses .com instead of .co ──
if echo "$SUPABASE_URL" | grep -q "\.supabase\.com"; then
  echo "[DEPLOY] WARNING: SUPABASE_URL uses .supabase.com instead of .supabase.co"
  echo "[DEPLOY] Please update to: $(echo $SUPABASE_URL | sed 's/\.supabase\.com/\.supabase\.co/')"
  echo "[DEPLOY] Proceeding anyway..."
fi

# ── Check Flutter availability ──
FLUTTER_CMD="flutter"
echo "[DEPLOY] Flutter version: $($FLUTTER_CMD --version | head -1)"

# ── Get dependencies (uses cache if available) ──
echo "[DEPLOY] Getting dependencies..."
$FLUTTER_CMD pub get

# ── Production build ──
echo "[DEPLOY] Building Flutter web..."
$FLUTTER_CMD build web --release \
  --base-href / \
  --no-pub \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" 2>&1

echo "[DEPLOY] Build complete!"
echo "[DEPLOY] Output: $(du -sh build/web | cut -f1)"

