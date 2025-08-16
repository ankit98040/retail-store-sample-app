# Microservices CI/CD Pipeline Documentation

## Overview

This GitHub Actions workflow provides automated CI/CD for the retail store microservices application. It detects changes in individual microservices and builds/deploys only the affected services, optimizing build time and resources.

## Architecture

The pipeline consists of 5 microservices:
- **UI Service** (Java/Spring Boot)
- **Catalog Service** (Go)
- **Cart Service** (Java/Spring Boot) 
- **Checkout Service** (Node.js/NestJS)
- **Orders Service** (Java/Spring Boot)

## Workflow Features

### 🔍 Smart Change Detection
- Uses `dorny/paths-filter` to detect changes in specific service directories
- Only builds and tests services that have actual code changes
- Supports manual override to force build all services

### 🐳 Docker Image Management
- Builds multi-architecture Docker images (linux/amd64)
- Pushes images to Amazon ECR with proper tagging strategy
- Implements Docker layer caching for faster builds
- Auto-creates ECR repositories if they don't exist

### 🧪 Comprehensive Testing
- Runs service-specific tests based on technology stack
- Caches dependencies (Maven, Go modules, Yarn) for faster execution
- Parallel test execution for multiple services

### 🔒 Security & Quality
- Trivy vulnerability scanning for all Docker images
- SARIF report upload to GitHub Security tab
- Image scanning enabled on ECR repositories

### 📊 Monitoring & Notifications
- Build status notifications
- Detailed logging for troubleshooting
- Matrix strategy for parallel processing

## Setup Instructions

### 1. AWS Configuration

#### Create ECR Repositories (Optional - Auto-created by workflow)
```bash
# The workflow will auto-create these, but you can pre-create them:
aws ecr create-repository --repository-name retail-store-ui --region us-east-1
aws ecr create-repository --repository-name retail-store-catalog --region us-east-1
aws ecr create-repository --repository-name retail-store-cart --region us-east-1
aws ecr create-repository --repository-name retail-store-checkout --region us-east-1
aws ecr create-repository --repository-name retail-store-orders --region us-east-1
```

#### IAM Policy for GitHub Actions
Create an IAM user with the following policy:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr:InitiateLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:CompleteLayerUpload",
                "ecr:PutImage",
                "ecr:CreateRepository",
                "ecr:DescribeRepositories",
                "ecr:PutImageScanningConfiguration"
            ],
            "Resource": "*"
        }
    ]
}
```

### 2. GitHub Secrets Configuration

Add the following secrets to your GitHub repository:

| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `AWS_ACCESS_KEY_ID` | AWS Access Key ID | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | AWS Secret Access Key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| `AWS_ACCOUNT_ID` | Your AWS Account ID | `123456789012` |

### 3. Workflow Configuration

#### Environment Variables
Update these in the workflow file if needed:

```yaml
env:
  AWS_REGION: us-east-1  # Change to your preferred region
  ECR_REGISTRY: ${{ secrets.AWS_ACCOUNT_ID }}.dkr.ecr.us-east-1.amazonaws.com
```

#### Trigger Configuration
The workflow triggers on:
- Push to `main` or `develop` branches (with changes in `src/` directory)
- Pull requests to `main` branch (with changes in `src/` directory)
- Manual dispatch with option to force build all services

## Usage Examples

### 1. Normal Development Flow
```bash
# Make changes to a specific service
git checkout -b feature/update-catalog-api
# Edit files in src/catalog/
git add src/catalog/
git commit -m "Update catalog API endpoint"
git push origin feature/update-catalog-api
```
**Result**: Only the catalog service will be built and tested.

### 2. Multi-Service Changes
```bash
# Make changes to multiple services
git checkout -b feature/update-checkout-flow
# Edit files in src/checkout/ and src/orders/
git add src/checkout/ src/orders/
git commit -m "Update checkout and order processing"
git push origin feature/update-checkout-flow
```
**Result**: Both checkout and orders services will be built and tested.

### 3. Force Build All Services
Use the GitHub Actions UI:
1. Go to Actions tab
2. Select "Microservices CI/CD Pipeline"
3. Click "Run workflow"
4. Check "Force build all services"
5. Click "Run workflow"

## Image Tagging Strategy

Images are tagged with multiple tags for flexibility:

- `latest` - Latest build from main branch
- `main-<sha>` - Specific commit from main branch
- `develop-<sha>` - Specific commit from develop branch
- `pr-<number>` - Pull request builds

Example:
```
123456789012.dkr.ecr.us-east-1.amazonaws.com/retail-store-ui:latest
123456789012.dkr.ecr.us-east-1.amazonaws.com/retail-store-ui:main-abc1234
123456789012.dkr.ecr.us-east-1.amazonaws.com/retail-store-ui:pr-42
```

## Monitoring and Troubleshooting

### Build Logs
- Check the Actions tab in GitHub for detailed build logs
- Each service builds in parallel for faster execution
- Failed builds will show specific error messages

### Security Scanning
- Trivy scan results are available in the Security tab
- Critical vulnerabilities will fail the build
- SARIF reports provide detailed vulnerability information

### Common Issues

#### 1. ECR Authentication Failure
```
Error: Cannot perform an interactive login from a non TTY device
```
**Solution**: Verify AWS credentials are correctly set in GitHub secrets.

#### 2. Docker Build Context Issues
```
Error: failed to solve: failed to read dockerfile
```
**Solution**: Ensure Dockerfile paths are correct in the matrix configuration.

#### 3. Test Failures
```
Error: Tests failed for service X
```
**Solution**: Check service-specific test logs and fix failing tests.

## Customization

### Adding New Services
1. Add the service directory under `src/`
2. Update the workflow matrix in both `detect-changes` and `build-and-push` jobs
3. Add appropriate test configuration

### Changing Build Arguments
Update the `build_args` in the matrix configuration:

```yaml
- service: my-service
  path: src/my-service
  dockerfile: src/my-service/Dockerfile
  build_args: |
    BUILD_ENV=production
    VERSION=1.0.0
```

### Custom Test Commands
Modify the test matrix to include service-specific test commands:

```yaml
- service: my-service
  path: src/my-service
  test_command: "npm run test:ci"
  setup_command: "npm ci"
```

## Best Practices

1. **Keep Dockerfiles optimized** - Use multi-stage builds and minimize layers
2. **Use .dockerignore** - Exclude unnecessary files from build context
3. **Cache dependencies** - Leverage Docker layer caching and GitHub Actions cache
4. **Security scanning** - Always scan images for vulnerabilities
5. **Proper tagging** - Use semantic versioning for production releases
6. **Resource limits** - Set appropriate resource limits in Kubernetes deployments

## Integration with Deployment

This workflow focuses on CI (Continuous Integration). For CD (Continuous Deployment), consider:

1. **GitOps with ArgoCD** - Update manifest repository with new image tags
2. **Direct Kubernetes deployment** - Use kubectl or Helm in additional workflow steps
3. **AWS ECS/Fargate** - Deploy to ECS services with new task definitions
4. **Terraform** - Update infrastructure as code with new image references

## Support

For issues or questions:
1. Check the workflow logs in GitHub Actions
2. Review this documentation
3. Check AWS CloudTrail for ECR-related issues
4. Verify IAM permissions and secrets configuration
