#!/bin/bash

# Local Build Script for Retail Store Microservices
# This script helps developers test builds locally before pushing to GitHub

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SERVICES=("ui" "catalog" "cart" "checkout" "orders")
BUILD_ALL=false
PUSH_TO_ECR=false
AWS_REGION="us-east-1"
ECR_REGISTRY=""

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS] [SERVICES...]"
    echo ""
    echo "Options:"
    echo "  -a, --all           Build all services"
    echo "  -p, --push          Push images to ECR (requires AWS credentials)"
    echo "  -r, --region        AWS region (default: us-east-1)"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Services:"
    echo "  ui, catalog, cart, checkout, orders"
    echo ""
    echo "Examples:"
    echo "  $0 ui catalog                    # Build only UI and Catalog services"
    echo "  $0 --all                         # Build all services"
    echo "  $0 --all --push                  # Build all services and push to ECR"
    echo "  $0 ui --push --region us-west-2  # Build UI service and push to us-west-2"
}

# Function to check if Docker is running
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker and try again."
        exit 1
    fi
}

# Function to check AWS credentials (if pushing to ECR)
check_aws_credentials() {
    if [ "$PUSH_TO_ECR" = true ]; then
        if ! aws sts get-caller-identity >/dev/null 2>&1; then
            print_error "AWS credentials not configured. Please run 'aws configure' or set environment variables."
            exit 1
        fi
        
        # Get AWS account ID for ECR registry
        AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
        ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        
        print_status "Using ECR registry: $ECR_REGISTRY"
        
        # Login to ECR
        print_status "Logging in to Amazon ECR..."
        aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY
    fi
}

# Function to create ECR repository if it doesn't exist
create_ecr_repo() {
    local service=$1
    local repo_name="retail-store-$service"
    
    if [ "$PUSH_TO_ECR" = true ]; then
        print_status "Checking ECR repository: $repo_name"
        
        if ! aws ecr describe-repositories --repository-names $repo_name --region $AWS_REGION >/dev/null 2>&1; then
            print_status "Creating ECR repository: $repo_name"
            aws ecr create-repository \
                --repository-name $repo_name \
                --region $AWS_REGION \
                --image-scanning-configuration scanOnPush=true \
                --encryption-configuration encryptionType=AES256 >/dev/null
            print_success "ECR repository created: $repo_name"
        fi
    fi
}

# Function to build a service
build_service() {
    local service=$1
    local service_path="src/$service"
    local dockerfile="$service_path/Dockerfile"
    
    print_status "Building service: $service"
    
    # Check if service directory exists
    if [ ! -d "$service_path" ]; then
        print_error "Service directory not found: $service_path"
        return 1
    fi
    
    # Check if Dockerfile exists
    if [ ! -f "$dockerfile" ]; then
        print_error "Dockerfile not found: $dockerfile"
        return 1
    fi
    
    # Generate image tags
    local git_sha=$(git rev-parse --short HEAD 2>/dev/null || echo "local")
    local git_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "local")
    local timestamp=$(date +%Y%m%d-%H%M%S)
    
    local image_name="retail-store-$service"
    local local_tag="$image_name:$git_branch-$git_sha"
    local latest_tag="$image_name:latest"
    
    # Build the Docker image
    print_status "Building Docker image: $local_tag"
    
    if docker build \
        -t "$local_tag" \
        -t "$latest_tag" \
        -f "$dockerfile" \
        "$service_path"; then
        print_success "Successfully built: $local_tag"
    else
        print_error "Failed to build: $service"
        return 1
    fi
    
    # Push to ECR if requested
    if [ "$PUSH_TO_ECR" = true ]; then
        create_ecr_repo "$service"
        
        local ecr_tag="$ECR_REGISTRY/$image_name:$git_branch-$git_sha"
        local ecr_latest="$ECR_REGISTRY/$image_name:latest"
        
        print_status "Tagging for ECR: $ecr_tag"
        docker tag "$local_tag" "$ecr_tag"
        docker tag "$latest_tag" "$ecr_latest"
        
        print_status "Pushing to ECR: $ecr_tag"
        if docker push "$ecr_tag" && docker push "$ecr_latest"; then
            print_success "Successfully pushed: $ecr_tag"
        else
            print_error "Failed to push: $service"
            return 1
        fi
    fi
}

# Function to run tests for a service
run_tests() {
    local service=$1
    local service_path="src/$service"
    
    print_status "Running tests for service: $service"
    
    cd "$service_path"
    
    case $service in
        "ui"|"cart"|"orders")
            if [ -f "./mvnw" ]; then
                print_status "Running Maven tests..."
                ./mvnw test -q
            else
                print_warning "Maven wrapper not found, skipping tests"
            fi
            ;;
        "catalog")
            if [ -f "go.mod" ]; then
                print_status "Running Go tests..."
                go test ./...
            else
                print_warning "go.mod not found, skipping tests"
            fi
            ;;
        "checkout")
            if [ -f "package.json" ]; then
                print_status "Installing dependencies..."
                yarn install --frozen-lockfile --silent
                print_status "Running Node.js tests..."
                yarn test
            else
                print_warning "package.json not found, skipping tests"
            fi
            ;;
        *)
            print_warning "Unknown service type, skipping tests"
            ;;
    esac
    
    cd - >/dev/null
    print_success "Tests completed for: $service"
}

# Parse command line arguments
SERVICES_TO_BUILD=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--all)
            BUILD_ALL=true
            shift
            ;;
        -p|--push)
            PUSH_TO_ECR=true
            shift
            ;;
        -r|--region)
            AWS_REGION="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        -*)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
        *)
            # Check if it's a valid service
            if [[ " ${SERVICES[@]} " =~ " $1 " ]]; then
                SERVICES_TO_BUILD+=("$1")
            else
                print_error "Unknown service: $1"
                print_error "Valid services: ${SERVICES[*]}"
                exit 1
            fi
            shift
            ;;
    esac
done

# Determine which services to build
if [ "$BUILD_ALL" = true ]; then
    SERVICES_TO_BUILD=("${SERVICES[@]}")
elif [ ${#SERVICES_TO_BUILD[@]} -eq 0 ]; then
    print_error "No services specified. Use --all or specify service names."
    show_usage
    exit 1
fi

# Main execution
print_status "Starting local build process..."
print_status "Services to build: ${SERVICES_TO_BUILD[*]}"
print_status "Push to ECR: $PUSH_TO_ECR"
print_status "AWS Region: $AWS_REGION"

# Pre-flight checks
check_docker
check_aws_credentials

# Build services
failed_services=()
successful_services=()

for service in "${SERVICES_TO_BUILD[@]}"; do
    print_status "Processing service: $service"
    
    # Run tests first
    if run_tests "$service"; then
        # Build if tests pass
        if build_service "$service"; then
            successful_services+=("$service")
        else
            failed_services+=("$service")
        fi
    else
        print_error "Tests failed for: $service"
        failed_services+=("$service")
    fi
    
    echo ""
done

# Summary
echo "=================================="
print_status "Build Summary"
echo "=================================="

if [ ${#successful_services[@]} -gt 0 ]; then
    print_success "Successfully built: ${successful_services[*]}"
fi

if [ ${#failed_services[@]} -gt 0 ]; then
    print_error "Failed to build: ${failed_services[*]}"
    exit 1
else
    print_success "All services built successfully!"
fi
