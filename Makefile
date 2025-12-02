# Hive Terminal - Local Build Commands

.PHONY: help build run clean test analyze

help:
	@echo "Hive Terminal Build Commands:"
	@echo "  make build    - Build macOS release app"
	@echo "  make run      - Run in debug mode"
	@echo "  make install  - Build and open app location"
	@echo "  make test     - Run all tests"
	@echo "  make analyze  - Run static analysis"
	@echo "  make clean    - Clean build artifacts"
	@echo "  make e2e      - Run E2E tests (requires Hive server)"

# Build release
build:
	flutter build macos --release

# Run in debug mode (no Gatekeeper issues)
run:
	flutter run -d macos

# Build and show where the app is
install: build
	@echo ""
	@echo "App built at:"
	@echo "  build/macos/Build/Products/Release/hive_terminal.app"
	@echo ""
	@echo "To run without Gatekeeper warning, use:"
	@echo "  open build/macos/Build/Products/Release/hive_terminal.app"
	@open build/macos/Build/Products/Release/

# Run tests
test:
	flutter test

# Run E2E tests (requires running Hive server)
e2e:
	flutter test test/integration/e2e_test.dart --tags=e2e --run-skipped

# Static analysis
analyze:
	flutter analyze --fatal-infos

# Clean
clean:
	flutter clean
	rm -rf build/

# Get dependencies
deps:
	flutter pub get
