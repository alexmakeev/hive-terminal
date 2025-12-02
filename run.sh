#!/bin/bash
# Pull latest and run Hive Terminal
# Usage: ./run.sh (pulls + runs)
#        q then ./run.sh again to get latest changes
set -e
cd "$(dirname "$0")"

echo "=== Pulling latest changes ==="
git pull
flutter pub get

echo ""
echo "=== Starting Hive Terminal ==="
echo "  r = hot reload"
echo "  R = hot restart"
echo "  q = quit, then ./run.sh to pull new changes"
echo ""

flutter run -d macos
