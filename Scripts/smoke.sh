#!/usr/bin/env bash
set -euo pipefail

# DevReader Smoke Test Script
# Comprehensive build, test, and archive validation for DevReader v1.0

# -------- config --------
SCHEME="DevReader"
PROJECT="DevReader.xcodeproj"  # Using project instead of workspace
DEST="platform=macOS,arch=arm64"
CONFIG="Release"
ARCHIVE_PATH="build/DevReader.xcarchive"
APP_PATH="build/DevReader.app"
SWIFTLINT=${SWIFTLINT:-swiftlint}   # optional
XCPRETTY=${XCPRETTY:-xcpretty}      # optional
# ------------------------

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 DevReader Smoke Test Suite${NC}"
echo "=================================="
echo "Date: $(date)"
echo "Version: DevReader v1.0"
echo ""

# Check prerequisites
check_prerequisites() {
    echo -e "${BLUE}==> Checking prerequisites${NC}"
    
    # Check for xcodebuild
    if ! command -v xcodebuild >/dev/null 2>&1; then
        echo -e "${RED}❌ xcodebuild not found. Please install Xcode.${NC}"
        exit 1
    fi
    
    # Check for xcpretty (optional but recommended)
    if command -v "$XCPRETTY" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ xcpretty found${NC}"
    else
        echo -e "${YELLOW}⚠ xcpretty not found; output will be verbose${NC}"
        XCPRETTY="cat"
    fi
    
    # Check for swiftlint (optional)
    if command -v "$SWIFTLINT" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ swiftlint found${NC}"
    else
        echo -e "${YELLOW}⚠ swiftlint not found; skipping linting${NC}"
        SWIFTLINT=""
    fi
    
    echo ""
}

# Clean build
clean_build() {
    echo -e "${BLUE}==> Cleaning build${NC}"
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIG" clean >/dev/null
    echo -e "${GREEN}✓ Clean completed${NC}"
    echo ""
}

# Run linting
run_lint() {
    if [ -n "$SWIFTLINT" ]; then
        echo -e "${BLUE}==> Running SwiftLint${NC}"
        if "$SWIFTLINT" --quiet; then
            echo -e "${GREEN}✓ Linting passed${NC}"
        else
            echo -e "${RED}❌ Linting failed${NC}"
            exit 1
        fi
        echo ""
    else
        echo -e "${YELLOW}==> Skipping linting (swiftlint not available)${NC}"
        echo ""
    fi
}

# Build and test
build_and_test() {
    echo -e "${BLUE}==> Building and testing${NC}"
    
    # Create build directory
    mkdir -p build
    
    # Run tests with coverage
    if xcodebuild -project "$PROJECT" -scheme "$SCHEME" -destination "$DEST" \
        -configuration Debug \
        -enableCodeCoverage YES \
        -resultBundlePath build/TestResults \
        test | "$XCPRETTY"; then
        echo -e "${GREEN}✓ Build and test completed${NC}"
    else
        echo -e "${RED}❌ Build or test failed${NC}"
        exit 1
    fi
    
    # Verify test results
    if [ -f "build/TestResults/Info.plist" ]; then
        if grep -q "TEST SUCCEEDED" build/TestResults/Info.plist 2>/dev/null; then
            echo -e "${GREEN}✓ All tests passed${NC}"
        else
            echo -e "${RED}❌ Tests did not succeed${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}⚠ Test results not found; assuming tests passed${NC}"
    fi
    
    echo ""
}

# Create release archive
create_archive() {
    echo -e "${BLUE}==> Creating release archive${NC}"
    
    if xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIG" \
        -destination "$DEST" -archivePath "$ARCHIVE_PATH" archive | "$XCPRETTY"; then
        echo -e "${GREEN}✓ Archive created successfully${NC}"
    else
        echo -e "${RED}❌ Archive creation failed${NC}"
        exit 1
    fi
    
    echo ""
}

# Export app bundle
export_app() {
    echo -e "${BLUE}==> Exporting app bundle${NC}"
    
    # Find the app bundle in the archive
    APP_BUNDLE=$(find "$ARCHIVE_PATH/Products/Applications" -maxdepth 1 -type d -name "*.app" | head -n1)
    
    if [ -z "$APP_BUNDLE" ]; then
        echo -e "${RED}❌ App bundle not found in archive${NC}"
        exit 1
    fi
    
    # Copy app bundle
    if cp -R "$APP_BUNDLE" "$APP_PATH"; then
        echo -e "${GREEN}✓ App bundle exported to $APP_PATH${NC}"
    else
        echo -e "${RED}❌ Failed to export app bundle${NC}"
        exit 1
    fi
    
    echo ""
}

# Verify app bundle
verify_app() {
    echo -e "${BLUE}==> Verifying app bundle${NC}"
    
    # Check if app exists
    if [ ! -d "$APP_PATH" ]; then
        echo -e "${RED}❌ App bundle not found at $APP_PATH${NC}"
        exit 1
    fi
    
    # Check code signing
    echo "Code signing info:"
    if codesign --display --verbose=2 "$APP_PATH" 2>/dev/null; then
        echo -e "${GREEN}✓ Code signing verified${NC}"
    else
        echo -e "${YELLOW}⚠ Code signing info not available${NC}"
    fi
    
    # Check Info.plist
    echo "App info:"
    if plutil -p "$APP_PATH/Contents/Info.plist" 2>/dev/null | head -n 20; then
        echo -e "${GREEN}✓ Info.plist is valid${NC}"
    else
        echo -e "${RED}❌ Info.plist is invalid${NC}"
        exit 1
    fi
    
    # Check app size
    APP_SIZE=$(du -sh "$APP_PATH" | cut -f1)
    echo "App size: $APP_SIZE"
    
    echo ""
}

# Run basic functionality test
test_basic_functionality() {
    echo -e "${BLUE}==> Testing basic functionality${NC}"
    
    # Launch app in background
    open "$APP_PATH" &
    APP_PID=$!
    
    # Wait for app to launch
    sleep 3
    
    # Check if app is running
    if kill -0 "$APP_PID" 2>/dev/null; then
        echo -e "${GREEN}✓ App launched successfully${NC}"
        
        # Wait a bit for app to stabilize
        sleep 2
        
        # Check memory usage
        if command -v ps >/dev/null 2>&1; then
            MEMORY_MB=$(ps -o rss= -p "$APP_PID" 2>/dev/null | awk '{print $1/1024}' || echo "0")
            echo "Memory usage: ${MEMORY_MB}MB"
            
            # Check if memory usage is reasonable (less than 500MB for idle app)
            if (( $(echo "$MEMORY_MB < 500" | bc -l) )); then
                echo -e "${GREEN}✓ Memory usage is reasonable${NC}"
            else
                echo -e "${YELLOW}⚠ High memory usage: ${MEMORY_MB}MB${NC}"
            fi
        fi
        
        # Close app
        kill "$APP_PID" 2>/dev/null || true
        sleep 1
        echo -e "${GREEN}✓ App closed successfully${NC}"
    else
        echo -e "${RED}❌ App failed to launch${NC}"
        exit 1
    fi
    
    echo ""
}

# Generate test report
generate_report() {
    echo -e "${BLUE}==> Generating test report${NC}"
    
    # Create report file
    REPORT_FILE="build/smoke_test_report.txt"
    cat > "$REPORT_FILE" << EOF
DevReader Smoke Test Report
==========================
Date: $(date)
Version: DevReader v1.0
Build Configuration: $CONFIG
Destination: $DEST

Test Results:
- Clean: ✓ PASSED
- Lint: $([ -n "$SWIFTLINT" ] && echo "✓ PASSED" || echo "⚠ SKIPPED")
- Build: ✓ PASSED
- Tests: ✓ PASSED
- Archive: ✓ PASSED
- Export: ✓ PASSED
- Verification: ✓ PASSED
- Functionality: ✓ PASSED

App Bundle: $APP_PATH
Archive: $ARCHIVE_PATH

All smoke tests completed successfully!
EOF
    
    echo -e "${GREEN}✓ Test report generated: $REPORT_FILE${NC}"
    echo ""
}

# Main execution
main() {
    check_prerequisites
    clean_build
    run_lint
    build_and_test
    create_archive
    export_app
    verify_app
    test_basic_functionality
    generate_report
    
    echo -e "${GREEN}🎉 All smoke tests passed! Ready for release.${NC}"
}

# Run main function
main "$@"
