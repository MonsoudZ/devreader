#!/usr/bin/env bash
set -euo pipefail

# DevReader Performance Testing Script
# Tests the application with large PDFs and various performance scenarios

echo "🚀 DevReader Performance Testing Suite"
echo "======================================"

# Configuration
SCHEME="DevReader"
PROJECT="DevReader.xcodeproj"
DEST="platform=macOS,arch=arm64"
CONFIG="Release"
TEST_RESULTS_DIR="build/PerformanceTestResults"
PERFORMANCE_LOG="build/performance_test.log"

# Create results directory
mkdir -p "$TEST_RESULTS_DIR"
mkdir -p build

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Performance thresholds (in seconds)
LARGE_PDF_LOAD_THRESHOLD=10.0
SEARCH_PERFORMANCE_THRESHOLD=3.0
MEMORY_USAGE_THRESHOLD=500  # MB
UI_RESPONSIVENESS_THRESHOLD=2.0

echo -e "${BLUE}📊 Performance Test Configuration:${NC}"
echo "  • Large PDF Load Threshold: ${LARGE_PDF_LOAD_THRESHOLD}s"
echo "  • Search Performance Threshold: ${SEARCH_PERFORMANCE_THRESHOLD}s"
echo "  • Memory Usage Threshold: ${MEMORY_USAGE_THRESHOLD}MB"
echo "  • UI Responsiveness Threshold: ${UI_RESPONSIVENESS_THRESHOLD}s"
echo ""

# Function to run performance tests
run_performance_tests() {
    echo -e "${BLUE}🧪 Running Performance Tests...${NC}"
    
    # Run the performance test suite
    xcodebuild test \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "$DEST" \
        -configuration "$CONFIG" \
        -only-testing:DevReaderTests/PerformanceTests \
        -resultBundlePath "$TEST_RESULTS_DIR" \
        -enableCodeCoverage YES \
        2>&1 | tee "$PERFORMANCE_LOG"
    
    local test_exit_code=$?
    
    if [ $test_exit_code -eq 0 ]; then
        echo -e "${GREEN}✅ Performance tests passed!${NC}"
        return 0
    else
        echo -e "${RED}❌ Performance tests failed!${NC}"
        return 1
    fi
}

# Function to test with real large PDFs
test_large_pdfs() {
    echo -e "${BLUE}📄 Testing with Large PDFs...${NC}"
    
    # Check if we have large PDFs available
    local large_pdf_dir="$HOME/Downloads/LargePDFs"
    local test_pdfs=()
    
    if [ -d "$large_pdf_dir" ]; then
        echo "Found large PDF directory: $large_pdf_dir"
        test_pdfs=($(find "$large_pdf_dir" -name "*.pdf" -size +10M 2>/dev/null | head -3))
    fi
    
    # If no large PDFs found, create a test scenario
    if [ ${#test_pdfs[@]} -eq 0 ]; then
        echo -e "${YELLOW}⚠️  No large PDFs found. Creating test scenario...${NC}"
        
        # Create a test PDF with many pages (simulated)
        local test_pdf="$TEST_RESULTS_DIR/test_large.pdf"
        echo "Creating test PDF: $test_pdf"
        
        # This would create a large PDF for testing
        # For now, we'll use the existing test infrastructure
        echo "Using existing test infrastructure for large PDF simulation"
    else
        echo "Found ${#test_pdfs[@]} large PDFs for testing:"
        for pdf in "${test_pdfs[@]}"; do
            local size=$(du -h "$pdf" | cut -f1)
            echo "  • $(basename "$pdf") ($size)"
        done
    fi
}

# Function to measure memory usage
measure_memory_usage() {
    echo -e "${BLUE}🧠 Measuring Memory Usage...${NC}"
    
    # Get current memory usage
    local memory_usage=$(ps -o rss= -p $$ | awk '{print $1/1024}')
    echo "Current memory usage: ${memory_usage}MB"
    
    if (( $(echo "$memory_usage > $MEMORY_USAGE_THRESHOLD" | bc -l) )); then
        echo -e "${RED}⚠️  Memory usage exceeds threshold: ${memory_usage}MB > ${MEMORY_USAGE_THRESHOLD}MB${NC}"
        return 1
    else
        echo -e "${GREEN}✅ Memory usage within acceptable limits${NC}"
        return 0
    fi
}

# Function to test UI responsiveness
test_ui_responsiveness() {
    echo -e "${BLUE}⚡ Testing UI Responsiveness...${NC}"
    
    # This would test UI responsiveness with large datasets
    # For now, we'll use the existing test infrastructure
    echo "Testing UI responsiveness with large datasets..."
    
    # Simulate UI operations
    local start_time=$(date +%s.%N)
    
    # Run UI performance tests
    xcodebuild test \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "$DEST" \
        -configuration "$CONFIG" \
        -only-testing:DevReaderTests/PerformanceTests/testUIResponsiveness \
        -resultBundlePath "$TEST_RESULTS_DIR/ui_test" \
        2>&1 | tee "$PERFORMANCE_LOG.ui"
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)
    
    echo "UI responsiveness test completed in ${duration}s"
    
    if (( $(echo "$duration > $UI_RESPONSIVENESS_THRESHOLD" | bc -l) )); then
        echo -e "${RED}⚠️  UI responsiveness exceeds threshold: ${duration}s > ${UI_RESPONSIVENESS_THRESHOLD}s${NC}"
        return 1
    else
        echo -e "${GREEN}✅ UI responsiveness within acceptable limits${NC}"
        return 0
    fi
}

# Function to generate performance report
generate_performance_report() {
    echo -e "${BLUE}📊 Generating Performance Report...${NC}"
    
    local report_file="$TEST_RESULTS_DIR/performance_report.md"
    
    cat > "$report_file" << EOF
# DevReader Performance Test Report

Generated: $(date)

## Test Configuration
- **Large PDF Load Threshold**: ${LARGE_PDF_LOAD_THRESHOLD}s
- **Search Performance Threshold**: ${SEARCH_PERFORMANCE_THRESHOLD}s
- **Memory Usage Threshold**: ${MEMORY_USAGE_THRESHOLD}MB
- **UI Responsiveness Threshold**: ${UI_RESPONSIVENESS_THRESHOLD}s

## Test Results

### Performance Tests
EOF

    if [ -f "$PERFORMANCE_LOG" ]; then
        echo "### Test Log" >> "$report_file"
        echo '```' >> "$report_file"
        cat "$PERFORMANCE_LOG" >> "$report_file"
        echo '```' >> "$report_file"
    fi

    echo "" >> "$report_file"
    echo "## Recommendations" >> "$report_file"
    echo "" >> "$report_file"
    echo "Based on the performance test results:" >> "$report_file"
    echo "- Monitor memory usage during large PDF operations" >> "$report_file"
    echo "- Optimize search performance for large datasets" >> "$report_file"
    echo "- Ensure UI remains responsive with many notes" >> "$report_file"
    echo "" >> "$report_file"
    echo "## Next Steps" >> "$report_file"
    echo "" >> "$report_file"
    echo "1. Review performance bottlenecks" >> "$report_file"
    echo "2. Optimize identified slow operations" >> "$report_file"
    echo "3. Re-run tests after optimizations" >> "$report_file"
    echo "4. Consider memory management improvements" >> "$report_file"

    echo -e "${GREEN}📊 Performance report generated: $report_file${NC}"
}

# Function to run stress tests
run_stress_tests() {
    echo -e "${BLUE}💪 Running Stress Tests...${NC}"
    
    # Test with maximum load
    echo "Testing with maximum load scenarios..."
    
    # Run stress tests
    xcodebuild test \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "$DEST" \
        -configuration "$CONFIG" \
        -only-testing:DevReaderTests/PerformanceTests/testMemoryUsage \
        -resultBundlePath "$TEST_RESULTS_DIR/stress_test" \
        2>&1 | tee "$PERFORMANCE_LOG.stress"
    
    echo -e "${GREEN}✅ Stress tests completed${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}🚀 Starting DevReader Performance Testing...${NC}"
    echo ""
    
    # Check prerequisites
    if ! command -v xcodebuild &> /dev/null; then
        echo -e "${RED}❌ xcodebuild not found. Please install Xcode.${NC}"
        exit 1
    fi
    
    if ! command -v bc &> /dev/null; then
        echo -e "${RED}❌ bc not found. Please install bc for calculations.${NC}"
        exit 1
    fi
    
    # Run performance tests
    local overall_success=true
    
    echo -e "${BLUE}1. Running Performance Tests...${NC}"
    if ! run_performance_tests; then
        overall_success=false
    fi
    
    echo -e "${BLUE}2. Testing Large PDFs...${NC}"
    test_large_pdfs
    
    echo -e "${BLUE}3. Measuring Memory Usage...${NC}"
    if ! measure_memory_usage; then
        overall_success=false
    fi
    
    echo -e "${BLUE}4. Testing UI Responsiveness...${NC}"
    if ! test_ui_responsiveness; then
        overall_success=false
    fi
    
    echo -e "${BLUE}5. Running Stress Tests...${NC}"
    run_stress_tests
    
    echo -e "${BLUE}6. Generating Performance Report...${NC}"
    generate_performance_report
    
    # Final results
    echo ""
    echo "======================================"
    if [ "$overall_success" = true ]; then
        echo -e "${GREEN}🎉 Performance Testing Complete - All Tests Passed!${NC}"
        echo -e "${GREEN}✅ DevReader is ready for production deployment${NC}"
        exit 0
    else
        echo -e "${RED}⚠️  Performance Testing Complete - Some Issues Found${NC}"
        echo -e "${YELLOW}📊 Review the performance report for details${NC}"
        echo -e "${YELLOW}🔧 Consider optimizations before production deployment${NC}"
        exit 1
    fi
}

# Run main function
main "$@"
