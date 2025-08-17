# Helm Chart Automatic Updates

This document explains the automated Helm chart update functionality that has been added to the CI/CD pipeline.

## Overview

The GitHub Actions workflow now automatically updates Helm chart `values.yaml` files with the latest Docker image tags whenever microservices are modified. This ensures that your Helm charts always reference the most recent Docker images built by the CI/CD pipeline.

## How It Works

### Workflow Integration

The pipeline includes a new job called `update-helm-charts` that:

1. **Detects Changes**: Only runs when changes are detected in microservice source code
2. **Updates Values**: Modifies the `values.yaml` file for each changed service
3. **Validates Charts**: Runs Helm lint and template validation
4. **Commits Changes**: Automatically commits the updated values back to the repository

### Updated Fields

For each service, the following fields in `values.yaml` are updated:

```yaml
image:
  repository: <ECR_REGISTRY>/retail-store-<service>
  tag: <COMMIT_SHA>
```

### Services Supported

- `ui` - Frontend service
- `catalog` - Product catalog service  
- `cart` - Shopping cart service
- `checkout` - Checkout service
- `orders` - Order management service

## Workflow Jobs

### 1. detect-changes
- Detects which services have been modified
- Uses `dorny/paths-filter` action to monitor `src/**` paths
- Outputs boolean flags for each service

### 2. build-and-push
- Builds and pushes Docker images to ECR
- Only runs for services that have changes
- Creates ECR repositories if they don't exist
- Runs security scans with Trivy

### 3. test
- Runs tests for changed services
- Supports different test frameworks per service
- Caches dependencies for faster execution

### 4. update-helm-charts (NEW)
- Updates Helm chart values.yaml files
- Only runs on `main` branch
- Uses `yq` tool for YAML manipulation
- Validates charts with Helm lint
- Commits changes back to repository

### 5. notify
- Provides pipeline status notifications
- Reports success/failure for all jobs including Helm updates

## Configuration

### Required Secrets

The workflow requires these GitHub secrets:

- `AWS_ACCESS_KEY_ID` - AWS access key for ECR access
- `AWS_SECRET_ACCESS_KEY` - AWS secret key for ECR access
- `AWS_ACCOUNT_ID` - AWS account ID for ECR registry URL
- `GITHUB_TOKEN` - Automatically provided by GitHub Actions

### Environment Variables

- `AWS_REGION` - Set to `us-east-1` (configurable)
- `ECR_REGISTRY` - Constructed from AWS account ID and region

## Manual Updates

### Using the Script

A helper script is provided for manual Helm chart updates:

```bash
# Update a single service
./.github/workflows/update-helm-charts.sh ui v1.2.3

# Update all services
./.github/workflows/update-helm-charts.sh all latest

# Specify custom ECR registry
./.github/workflows/update-helm-charts.sh catalog abc123 123456789.dkr.ecr.us-east-1.amazonaws.com
```

### Script Features

- ✅ Validates service names
- ✅ Backs up original files
- ✅ Shows diffs of changes
- ✅ Validates Helm charts
- ✅ Cross-platform support (Linux/macOS)
- ✅ Colored output for better readability

## File Structure

```
src/
├── ui/
│   └── chart/
│       └── values.yaml          # Updated automatically
├── catalog/
│   └── chart/
│       └── values.yaml          # Updated automatically
├── cart/
│   └── chart/
│       └── values.yaml          # Updated automatically
├── checkout/
│   └── chart/
│       └── values.yaml          # Updated automatically
└── orders/
    └── chart/
        └── values.yaml          # Updated automatically
```

## Troubleshooting

### Common Issues

1. **Permission Denied**
   - Ensure `GITHUB_TOKEN` has write permissions
   - Check repository settings for Actions permissions

2. **yq Installation Fails**
   - The workflow automatically installs `yq`
   - For manual runs, install `yq` separately

3. **Helm Validation Fails**
   - Check chart syntax in `templates/` directory
   - Ensure all required values are present

4. **Git Push Fails**
   - May occur if multiple services are updated simultaneously
   - The workflow handles this with proper git configuration

### Debugging

Enable debug logging by setting these repository secrets:
- `ACTIONS_STEP_DEBUG` = `true`
- `ACTIONS_RUNNER_DEBUG` = `true`

### Logs and Monitoring

- Check the Actions tab in GitHub for detailed logs
- Each service update creates a deployment summary
- Failed updates are reported in the notification job

## Best Practices

### Branch Protection

Consider setting up branch protection rules:
- Require pull request reviews
- Require status checks to pass
- Include administrators in restrictions

### Monitoring

- Set up notifications for failed workflows
- Monitor ECR repository sizes
- Review Helm chart changes in pull requests

### Security

- Regularly rotate AWS credentials
- Use least-privilege IAM policies
- Enable ECR image scanning
- Review Trivy security scan results

## Integration with GitOps

This workflow is designed to work with GitOps tools like ArgoCD:

1. **Automatic Sync**: ArgoCD can monitor the repository for changes
2. **Image Updates**: Updated Helm charts trigger deployments
3. **Rollback**: Git history provides easy rollback capability

### ArgoCD Configuration

Example ArgoCD application configuration:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: retail-store-ui
spec:
  source:
    repoURL: <your-repo-url>
    path: src/ui/chart
    targetRevision: main
  destination:
    server: https://kubernetes.default.svc
    namespace: retail-store
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Future Enhancements

Potential improvements to consider:

- [ ] Support for multiple environments (dev, staging, prod)
- [ ] Semantic versioning for image tags
- [ ] Integration with external secret management
- [ ] Slack/Teams notifications
- [ ] Rollback automation on deployment failures
- [ ] Multi-cluster deployment support

## Contributing

When modifying the workflow:

1. Test changes in a feature branch
2. Update this documentation
3. Ensure backward compatibility
4. Add appropriate error handling
5. Update the manual script if needed

## Support

For issues or questions:

1. Check the GitHub Actions logs
2. Review this documentation
3. Create an issue in the repository
4. Contact the DevOps team
