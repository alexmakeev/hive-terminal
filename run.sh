#!/bin/bash
# Pull latest, build and run Hive Terminal with auto-update on Shift+R
set -e
cd "$(dirname "$0")"

# Initial pull
git pull
flutter pub get

# Create a named pipe for communication
PIPE=$(mktemp -u)
mkfifo "$PIPE"

# Cleanup on exit
cleanup() {
    rm -f "$PIPE"
    kill $FLUTTER_PID 2>/dev/null || true
}
trap cleanup EXIT

# Start flutter with stdin from pipe
flutter run -d macos < "$PIPE" &
FLUTTER_PID=$!

# Keep pipe open and handle input
exec 3>"$PIPE"

echo ""
echo "=== HIVE TERMINAL ==="
echo "  r = hot reload"
echo "  R = git pull + hot reload"
echo "  q = quit"
echo "====================="
echo ""

# Read user input and handle R specially
while IFS= read -r -n1 char; do
    if [[ "$char" == "R" ]]; then
        echo ""
        echo "[run.sh] Pulling latest changes..."
        git pull
        echo "[run.sh] Triggering hot reload..."
        echo "r" >&3
    else
        echo -n "$char" >&3
    fi
done
