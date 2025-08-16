#!/bin/bash

# Setup Validation Script for Retail Store Microservices CI/CD
# This script validates that all required components are properly configured

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
CHECKS_PASSED=0
CHECKS_FAILED=0
WARNINGS=0

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
    ((CHECKS_PASSED++))
}

print_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
    ((WARNINGS++))
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
    ((CHECKS_FAILED++))
}

print_header() {
    echo ""
    echo "=================================="
    echo "$1"
    echo "=================================="
}

# Check if we're in the right directory
check_project_structure() {
    print_header "Checking Project Structure"
    
    if [ ! -d "src" ]; then
        print_error "src directory not found. Are you in the project root?"
        return 1
    fi
    print_success "Project root directory confirmed"
    
    # Check for microservices
    services=("ui" "catalog" "cart" "checkout" "orders")
    for service in "${services[@]}"; do
        if [ -d "src/$service" ]; then
            print_success "Service directory found: src/$service"
        else
            print_error "Service directory missing: src/$service"
        fi
    done
    
    # Check for Dockerfiles
    for service in "${services[@]}"; do
        if [ -f "src/$service/Dockerfile" ]; then
            print_success "Dockerfile found: src/$service/Dockerfile"
        else
            print_error "Dockerfile missing: src/$service/Dockerfile"
        fi
    done
}

# Check GitHub Actions workflows
check_github_workflows() {
    print_header "Checking GitHub Actions Workflows"
    
    if [ ! -d ".github/workflows" ]; then
        print_error ".github/workflows directory not found"
        return 1
    fi
    print_success ".github/workflows directory exists"
    
    # Check for workflow files
    workflows=("ci-cd-microservices.yml" "security-scan.yml")
    for workflow in "${workflows[@]}"; do
        if [ -f ".github/workflows/$workflow" ]; then
            print_success "Workflow file found: $workflow"
        else
            print_error "Workflow file missing: $workflow"
        fi
    done
    
    # Check for helper scripts
    if [ -f ".github/workflows/local-build.sh" ]; then
        print_success "Local build script found"
        if [ -x ".github/workflows/local-build.sh" ]; then
            print_success "Local build script is executable"
        else
            print_warning "Local build script is not executable (run: chmod +x .github/workflows/local-build.sh)"
        fi
    else
        print_error "Local build script missing"
    fi
    
    # Check Dependabot configuration
    if [ -f ".github/dependabot.yml" ]; then
        print_success "Dependabot configuration found"
    else
        print_warning "Dependabot configuration missing (automated dependency updates disabled)"
    fi
}

# Validate workflow syntax
validate_workflow_syntax() {
    print_header "Validating Workflow Syntax"
    
    # Check if yq is available for YAML validation
    if command -v yq >/dev/null 2>&1; then
        for workflow in .github/workflows/*.yml; do
            if [ -f "$workflow" ]; then
                if yq eval '.' "$workflow" >/dev/null 2>&1; then
                    print_success "Valid YAML syntax: $(basename "$workflow")"
                else
                    print_error "Invalid YAML syntax: $(basename "$workflow")"
                fi
            fi
        done
    else
        print_warning "yq not installed, skipping YAML syntax validation"
        print_warning "Install yq with: brew install yq (macOS) or apt-get install yq (Ubuntu)"
    fi
}

# Check Docker setup
check_docker_setup() {
    print_header "Checking Docker Setup"
    
    if command -v docker >/dev/null 2>&1; then
        print_success "Docker CLI installed"
        
        if docker info >/dev/null 2>&1; then
            print_success "Docker daemon is running"
        else
            print_warning "Docker daemon is not running (required for local builds)"
        fi
    else
        print_warning "Docker not installed (required for local builds)"
    fi
    
    # Check for .dockerignore files
    services=("ui" "catalog" "cart" "checkout" "orders")
    for service in "${services[@]}"; do
        if [ -f "src/$service/.dockerignore" ]; then
            print_success ".dockerignore found: src/$service/.dockerignore"
        else
            print_warning ".dockerignore missing: src/$service/.dockerignore (may increase build context size)"
        fi
    done
}

# Check AWS CLI setup
check_aws_setup() {
    print_header "Checking AWS Setup"
    
    if command -v aws >/dev/null 2>&1; then
        print_success "AWS CLI installed"
        
        if aws sts get-caller-identity >/dev/null 2>&1; then
            print_success "AWS credentials configured"
            
            # Get AWS account ID
            AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
            if [ -n "$AWS_ACCOUNT_ID" ]; then
                print_success "AWS Account ID: $AWS_ACCOUNT_ID"
            fi
        else
            print_warning "AWS credentials not configured (required for ECR operations)"
            print_warning "Run: aws configure"
        fi
    else
        print_warning "AWS CLI not installed (required for ECR operations)"
    fi
}

# Check service-specific dependencies
check_service_dependencies() {
    print_header "Checking Service Dependencies"
    
    # Java services
    java_services=("ui" "cart" "orders")
    for service in "${java_services[@]}"; do
        if [ -f "src/$service/pom.xml" ]; then
            print_success "Maven configuration found: src/$service/pom.xml"
        else
            print_error "Maven configuration missing: src/$service/pom.xml"
        fi
        
        if [ -f "src/$service/mvnw" ]; then
            print_success "Maven wrapper found: src/$service/mvnw"
        else
            print_error "Maven wrapper missing: src/$service/mvnw"
        fi
    done
    
    # Go service
    if [ -f "src/catalog/go.mod" ]; then
        print_success "Go module configuration found: src/catalog/go.mod"
    else
        print_error "Go module configuration missing: src/catalog/go.mod"
    fi
    
    # Node.js service
    if [ -f "src/checkout/package.json" ]; then
        print_success "Node.js configuration found: src/checkout/package.json"
    else
        print_error "Node.js configuration missing: src/checkout/package.json"
    fi
    
    if [ -f "src/checkout/yarn.lock" ]; then
        print_success "Yarn lock file found: src/checkout/yarn.lock"
    else
        print_warning "Yarn lock file missing: src/checkout/yarn.lock (may cause dependency issues)"
    fi
}

# Check for security and compliance files
check_security_files() {
    print_header "Checking Security and Compliance"
    
    if [ -f "SECURITY.md" ]; then
        print_success "Security policy found: SECURITY.md"
    else
        print_warning "Security policy missing: SECURITY.md (recommended for open source projects)"
    fi
    
    if [ -f "LICENSE" ]; then
        print_success "License file found: LICENSE"
    else
        print_warning "License file missing: LICENSE"
    fi
    
    # Check for .gitignore
    if [ -f ".gitignore" ]; then
        print_success ".gitignore file found"
    else
        print_warning ".gitignore file missing"
    fi
}

# Test local build script
test_local_build() {
    print_header "Testing Local Build Script"
    
    if [ -f ".github/workflows/local-build.sh" ] && [ -x ".github/workflows/local-build.sh" ]; then
        # Test help command
        if ./.github/workflows/local-build.sh --help >/dev/null 2>&1; then
            print_success "Local build script help command works"
        else
            print_error "Local build script help command failed"
        fi
    else
        print_error "Local build script not found or not executable"
    fi
}

# Generate recommendations
generate_recommendations() {
    print_header "Recommendations"
    
    echo "Based on the validation results, here are some recommendations:"
    echo ""
    
    if [ $CHECKS_FAILED -gt 0 ]; then
        echo "🔴 Critical Issues Found:"
        echo "   - Fix all failed checks before proceeding"
        echo "   - Ensure all required files are present"
        echo "   - Verify project structure matches expected layout"
        echo ""
    fi
    
    if [ $WARNINGS -gt 0 ]; then
        echo "🟡 Warnings to Address:"
        echo "   - Install missing optional tools (Docker, AWS CLI, yq)"
        echo "   - Add missing .dockerignore files to optimize builds"
        echo "   - Consider adding security policy and license files"
        echo "   - Configure AWS credentials for local testing"
        echo ""
    fi
    
    echo "✅ Next Steps:"
    echo "   1. Fix any critical issues identified above"
    echo "   2. Set up GitHub repository secrets (AWS credentials)"
    echo "   3. Test the pipeline with a small change"
    echo "   4. Monitor the first few builds for any issues"
    echo "   5. Set up team notifications and reviewers"
    echo ""
    
    echo "📚 Documentation:"
    echo "   - Read DEVOPS_SETUP.md for detailed setup instructions"
    echo "   - Check .github/workflows/README.md for workflow details"
    echo "   - Review security-scan.yml for security requirements"
}

# Main execution
main() {
    echo "🔍 Retail Store Microservices CI/CD Validation"
    echo "=============================================="
    echo ""
    
    check_project_structure
    check_github_workflows
    validate_workflow_syntax
    check_docker_setup
    check_aws_setup
    check_service_dependencies
    check_security_files
    test_local_build
    
    print_header "Validation Summary"
    echo "Checks Passed: $CHECKS_PASSED"
    echo "Checks Failed: $CHECKS_FAILED"
    echo "Warnings: $WARNINGS"
    echo ""
    
    if [ $CHECKS_FAILED -eq 0 ]; then
        print_success "All critical checks passed! ✨"
        echo ""
        generate_recommendations
        exit 0
    else
        print_error "Some critical checks failed. Please fix the issues above."
        echo ""
        generate_recommendations
        exit 1
    fi
}

# Run the validation
main "$@"
