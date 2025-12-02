#!/bin/bash
# Pull latest, build and run Hive Terminal
set -e
cd "$(dirname "$0")"
git pull && flutter pub get && flutter run -d macos
