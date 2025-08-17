#!/bin/bash

# Script to manually update Helm chart values.yaml files with new Docker image tags
# Usage: ./update-helm-charts.sh <service> <image-tag> [ecr-registry]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
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
    echo "Usage: $0 <service> <image-tag> [ecr-registry]"
    echo ""
    echo "Arguments:"
    echo "  service       - The microservice name (ui, catalog, cart, checkout, orders, or 'all')"
    echo "  image-tag     - The Docker image tag to use"
    echo "  ecr-registry  - ECR registry URL (optional, defaults to environment variable)"
    echo ""
    echo "Examples:"
    echo "  $0 ui v1.2.3"
    echo "  $0 all latest"
    echo "  $0 catalog abc123 123456789.dkr.ecr.us-east-1.amazonaws.com"
    echo ""
    echo "Environment Variables:"
    echo "  ECR_REGISTRY  - Default ECR registry URL"
}

# Check if required arguments are provided
if [ $# -lt 2 ]; then
    print_error "Missing required arguments"
    show_usage
    exit 1
fi

SERVICE="$1"
IMAGE_TAG="$2"
ECR_REGISTRY="${3:-${ECR_REGISTRY}}"

# Validate ECR registry
if [ -z "$ECR_REGISTRY" ]; then
    print_error "ECR registry not provided. Set ECR_REGISTRY environment variable or pass as third argument"
    exit 1
fi

# List of all services
ALL_SERVICES=("ui" "catalog" "cart" "checkout" "orders")

# Function to update a single service
update_service() {
    local service="$1"
    local values_file="src/${service}/chart/values.yaml"
    local ecr_repository="${ECR_REGISTRY}/retail-store-${service}"
    
    print_info "Updating Helm chart for service: ${service}"
    print_info "Values file: ${values_file}"
    print_info "New image tag: ${IMAGE_TAG}"
    print_info "ECR repository: ${ecr_repository}"
    
    # Check if values.yaml exists
    if [ ! -f "${values_file}" ]; then
        print_error "${values_file} not found!"
        return 1
    fi
    
    # Check if yq is installed
    if ! command -v yq &> /dev/null; then
        print_info "Installing yq..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            if command -v brew &> /dev/null; then
                brew install yq
            else
                print_error "Please install yq manually on macOS"
                return 1
            fi
        else
            # Linux
            sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
            sudo chmod +x /usr/local/bin/yq
        fi
    fi
    
    # Backup the original file
    cp "${values_file}" "${values_file}.backup"
    
    # Update the image repository and tag
    yq eval ".image.repository = \"${ecr_repository}\"" -i "${values_file}"
    yq eval ".image.tag = \"${IMAGE_TAG}\"" -i "${values_file}"
    
    # Verify the changes
    print_info "Updated values.yaml content for image section:"
    yq eval '.image' "${values_file}"
    
    # Show the diff
    print_info "Changes made to ${values_file}:"
    if command -v diff &> /dev/null; then
        diff "${values_file}.backup" "${values_file}" || true
    else
        print_warning "diff command not available, skipping diff display"
    fi
    
    # Validate Helm chart if helm is available
    if command -v helm &> /dev/null; then
        print_info "Validating Helm chart..."
        if helm lint "src/${service}/chart" > /dev/null 2>&1; then
            print_success "Helm chart validation passed"
        else
            print_warning "Helm chart validation failed, but continuing..."
        fi
    else
        print_warning "Helm not installed, skipping chart validation"
    fi
    
    # Clean up backup file
    rm "${values_file}.backup"
    
    print_success "Successfully updated Helm chart for ${service} service"
}

# Main logic
if [ "$SERVICE" == "all" ]; then
    print_info "Updating all services with image tag: ${IMAGE_TAG}"
    for service in "${ALL_SERVICES[@]}"; do
        echo ""
        update_service "$service"
    done
else
    # Validate service name
    if [[ ! " ${ALL_SERVICES[@]} " =~ " ${SERVICE} " ]]; then
        print_error "Invalid service name: ${SERVICE}"
        print_info "Valid services: ${ALL_SERVICES[*]}"
        exit 1
    fi
    
    update_service "$SERVICE"
fi

print_success "All updates completed successfully!"
print_info "Don't forget to commit and push your changes if you're satisfied with the updates."
