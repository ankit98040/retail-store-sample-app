# DevOps Setup Guide for Retail Store Microservices

## 🎯 Overview

This guide provides complete setup instructions for the automated CI/CD pipeline that builds and deploys the retail store microservices to Amazon ECR. The pipeline is designed to be efficient, secure, and scalable.

## 🏗️ Architecture

### Microservices Identified
- **UI Service** (Java/Spring Boot) - Frontend web application
- **Catalog Service** (Go) - Product catalog management
- **Cart Service** (Java/Spring Boot) - Shopping cart functionality
- **Checkout Service** (Node.js/NestJS) - Order processing
- **Orders Service** (Java/Spring Boot) - Order management

### CI/CD Pipeline Features
- ✅ **Smart Change Detection** - Only builds changed services
- ✅ **Multi-language Support** - Java, Go, Node.js
- ✅ **Parallel Builds** - Matrix strategy for efficiency
- ✅ **Security Scanning** - Trivy, Snyk, CodeQL integration
- ✅ **Automated Testing** - Service-specific test execution
- ✅ **ECR Integration** - Automatic repository creation and image push
- ✅ **Dependency Management** - Dependabot automation
- ✅ **Local Development** - Helper scripts for testing

## 🚀 Quick Start

### Prerequisites
- AWS Account with ECR access
- GitHub repository
- Docker installed locally (for testing)
- AWS CLI configured (for local testing)

### 1. AWS Setup

#### Create IAM User for GitHub Actions
```bash
# Create IAM user
aws iam create-user --user-name github-actions-ecr

# Create and attach policy
cat > ecr-policy.json << EOF
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
EOF

aws iam put-user-policy --user-name github-actions-ecr --policy-name ECRFullAccess --policy-document file://ecr-policy.json

# Create access keys
aws iam create-access-key --user-name github-actions-ecr
```

#### Pre-create ECR Repositories (Optional)
```bash
# The workflow will auto-create these, but you can pre-create them
services=("ui" "catalog" "cart" "checkout" "orders")
region="us-east-1"

for service in "${services[@]}"; do
    aws ecr create-repository \
        --repository-name "retail-store-$service" \
        --region $region \
        --image-scanning-configuration scanOnPush=true \
        --encryption-configuration encryptionType=AES256
done
```

### 2. GitHub Configuration

#### Required Secrets
Navigate to your GitHub repository → Settings → Secrets and variables → Actions

Add these repository secrets:

| Secret Name | Description | Where to Find |
|-------------|-------------|---------------|
| `AWS_ACCESS_KEY_ID` | IAM user access key | From `aws iam create-access-key` output |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key | From `aws iam create-access-key` output |
| `AWS_ACCOUNT_ID` | Your AWS account ID | Run `aws sts get-caller-identity` |

#### Optional Secrets (for enhanced security scanning)
| Secret Name | Description | How to Get |
|-------------|-------------|------------|
| `SNYK_TOKEN` | Snyk API token | Sign up at snyk.io |
| `SEMGREP_APP_TOKEN` | Semgrep token | Sign up at semgrep.dev |

### 3. Workflow Files

The following files have been created in `.github/workflows/`:

1. **`ci-cd-microservices.yml`** - Main CI/CD pipeline
2. **`security-scan.yml`** - Security and compliance scanning
3. **`local-build.sh`** - Local development helper script

### 4. Test the Setup

#### Local Testing
```bash
# Make the script executable
chmod +x .github/workflows/local-build.sh

# Test building a single service
./.github/workflows/local-build.sh ui

# Test building all services
./.github/workflows/local-build.sh --all

# Test with ECR push (requires AWS credentials)
./.github/workflows/local-build.sh --all --push
```

#### GitHub Actions Testing
```bash
# Make a small change to trigger the pipeline
echo "# Test change" >> src/ui/README.md
git add src/ui/README.md
git commit -m "test: trigger CI/CD pipeline"
git push origin main
```

## 📋 Workflow Details

### Main CI/CD Pipeline (`ci-cd-microservices.yml`)

#### Triggers
- Push to `main` or `develop` branches (with changes in `src/`)
- Pull requests to `main` branch (with changes in `src/`)
- Manual dispatch with force build option

#### Jobs
1. **detect-changes** - Identifies which services have changed
2. **build-and-push** - Builds and pushes Docker images to ECR
3. **test** - Runs service-specific tests
4. **update-manifests** - Updates deployment manifests (placeholder)
5. **notify** - Sends build notifications

#### Matrix Strategy
Each service builds in parallel with appropriate:
- Build context and Dockerfile path
- Technology-specific setup (Java 21, Go 1.21, Node.js 20)
- Caching strategies (Maven, Go modules, Yarn)
- Test commands

### Security Pipeline (`security-scan.yml`)

#### Scans Performed
- **Code Analysis** - CodeQL and Semgrep
- **Dependency Scanning** - Snyk for all package managers
- **Container Scanning** - Trivy and Grype
- **Infrastructure Scanning** - Checkov and TruffleHog
- **License Compliance** - Automated license checking
- **Policy Compliance** - Security policy validation

#### Schedule
- Daily at 2 AM UTC for comprehensive scans
- On every push/PR for critical checks

### Dependency Management (`dependabot.yml`)

#### Update Schedule
- **Monday** - GitHub Actions dependencies
- **Tuesday** - Java/Maven dependencies
- **Wednesday** - Go dependencies
- **Thursday** - Node.js dependencies
- **Friday** - Docker base images

#### Safety Features
- Major version updates ignored for critical frameworks
- Automatic reviewer assignment
- Proper commit message formatting
- Limited concurrent PRs

## 🔧 Customization

### Adding New Services

1. **Add service directory** under `src/`
2. **Update workflow matrix** in both pipelines:
   ```yaml
   - service: new-service
     path: src/new-service
     dockerfile: src/new-service/Dockerfile
     build_args: ""
     changed: ${{ needs.detect-changes.outputs.new-service }}
   ```
3. **Add change detection**:
   ```yaml
   new-service:
     - 'src/new-service/**'
   ```
4. **Update Dependabot** configuration
5. **Update local build script**

### Modifying Build Process

#### Custom Build Arguments
```yaml
- service: my-service
  build_args: |
    BUILD_ENV=production
    VERSION=${{ github.sha }}
    CUSTOM_ARG=value
```

#### Different Test Commands
```yaml
- service: my-service
  test_command: "npm run test:ci && npm run lint"
  setup_command: "npm ci && npm run build"
```

#### Custom Dockerfile Locations
```yaml
- service: my-service
  dockerfile: docker/Dockerfile.production
```

### Environment-Specific Configuration

#### Different AWS Regions
```yaml
env:
  AWS_REGION: us-west-2
  ECR_REGISTRY: ${{ secrets.AWS_ACCOUNT_ID }}.dkr.ecr.us-west-2.amazonaws.com
```

#### Multiple Environments
Create separate workflow files:
- `ci-cd-staging.yml`
- `ci-cd-production.yml`

With environment-specific triggers and configurations.

## 🔍 Monitoring and Troubleshooting

### Build Monitoring

#### GitHub Actions Dashboard
- Monitor workflow runs in the Actions tab
- Check individual job logs for detailed information
- Review security scan results in Security tab

#### Common Issues and Solutions

1. **ECR Authentication Failure**
   ```
   Error: Cannot perform an interactive login from a non TTY device
   ```
   **Solution**: Verify AWS credentials in GitHub secrets

2. **Docker Build Context Too Large**
   ```
   Error: failed to solve: failed to read dockerfile
   ```
   **Solution**: Add `.dockerignore` files to exclude unnecessary files

3. **Test Failures**
   ```
   Error: Tests failed for service X
   ```
   **Solution**: Check service-specific logs and fix failing tests

4. **ECR Repository Not Found**
   ```
   Error: Repository does not exist
   ```
   **Solution**: Workflow auto-creates repositories, check IAM permissions

### Performance Optimization

#### Build Time Optimization
- Docker layer caching enabled
- Dependency caching (Maven, Go, Yarn)
- Parallel matrix builds
- Smart change detection

#### Resource Usage
- Use appropriate runner sizes
- Optimize Docker images with multi-stage builds
- Cache frequently used dependencies

### Security Monitoring

#### Vulnerability Management
- Daily security scans
- SARIF report uploads to GitHub Security tab
- Automated dependency updates via Dependabot
- License compliance checking

#### Best Practices
- Regular base image updates
- Minimal container images
- Non-root user execution
- Secret scanning enabled

## 📈 Metrics and Analytics

### Key Performance Indicators

#### Build Metrics
- Build success rate
- Average build time per service
- Cache hit rates
- Parallel execution efficiency

#### Security Metrics
- Vulnerability detection rate
- Time to patch critical vulnerabilities
- License compliance percentage
- Security policy adherence

#### Deployment Metrics
- Deployment frequency
- Lead time for changes
- Mean time to recovery
- Change failure rate

### Monitoring Tools Integration

#### GitHub Insights
- Use GitHub's built-in Actions analytics
- Monitor workflow performance trends
- Track security alert resolution

#### External Monitoring
- Integrate with DataDog, New Relic, or similar
- Set up alerts for build failures
- Monitor ECR repository metrics

## 🚀 Next Steps

### Deployment Integration

1. **Kubernetes Deployment**
   - Add Helm chart updates to workflow
   - Integrate with ArgoCD for GitOps
   - Implement blue-green deployments

2. **AWS ECS/Fargate**
   - Update ECS task definitions
   - Implement rolling deployments
   - Add health checks

3. **Infrastructure as Code**
   - Terraform integration
   - CloudFormation updates
   - CDK deployments

### Advanced Features

1. **Multi-Environment Support**
   - Staging and production pipelines
   - Environment-specific configurations
   - Approval workflows for production

2. **Advanced Testing**
   - Integration tests
   - Performance testing
   - End-to-end testing

3. **Observability**
   - Distributed tracing
   - Metrics collection
   - Log aggregation

## 🆘 Support and Maintenance

### Regular Maintenance Tasks

#### Weekly
- Review Dependabot PRs
- Check security scan results
- Monitor build performance

#### Monthly
- Update base Docker images
- Review and update IAM policies
- Audit access permissions

#### Quarterly
- Review and update security policies
- Performance optimization review
- Disaster recovery testing

### Getting Help

1. **Documentation** - Check this guide and workflow README
2. **GitHub Issues** - Create issues for bugs or feature requests
3. **AWS Support** - For ECR or IAM related issues
4. **Community** - GitHub Discussions or relevant forums

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes and test locally
4. Submit a pull request
5. Ensure all checks pass

---

## 📝 Summary

This DevOps setup provides:
- ✅ Automated CI/CD for 5 microservices
- ✅ Smart change detection and parallel builds
- ✅ Comprehensive security scanning
- ✅ Automated dependency management
- ✅ Local development tools
- ✅ Production-ready configuration

The pipeline is designed to be maintainable, secure, and scalable for enterprise use.
