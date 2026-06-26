#!/bin/bash
# Vercel build script for FamHub Flutter web app
set -e

# Clone Flutter SDK if not already present
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi

# Add Flutter to PATH
export PATH="$PATH:$(pwd)/flutter/bin"

# Get dependencies
flutter pub get

# Build with Supabase env vars
flutter build web --release --base-href / \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
