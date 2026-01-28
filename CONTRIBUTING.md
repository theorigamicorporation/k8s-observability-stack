# Contributing to k8s-observability-stack

Thank you for your interest in contributing! This document provides guidelines and instructions for contributing to this project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Pull Request Process](#pull-request-process)
- [Coding Standards](#coding-standards)
- [Testing Guidelines](#testing-guidelines)
- [Documentation](#documentation)
- [Release Process](#release-process)

---

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](https://www.contributor-covenant.org/version/2/1/code_of_conduct/). By participating, you are expected to uphold this code.

---

## Getting Started

### Prerequisites

See [RUNBOOK.md](RUNBOOK.md#prerequisites) for required tools.

### Setup Development Environment

```bash
# Fork the repository on GitHub, then clone your fork
git clone https://github.com/YOUR_USERNAME/k8s-observability-stack.git
cd k8s-observability-stack

# Add upstream remote
git remote add upstream https://github.com/theorigamicorporation/k8s-observability-stack.git

# Install dependencies
make deps

# Verify everything works
make lint
```

### Understanding the Codebase

1. **Read the docs**: Start with [README.md](README.md) and [RUNBOOK.md](RUNBOOK.md)
2. **Explore the architecture**: See [docs/architecture.md](docs/architecture.md)
3. **Check subchart values**: Run `make refresh-values` and browse `external-values/`

---

## Development Workflow

### Branch Strategy

- `main` - Production-ready code, protected
- `dev` - Development branch (optional)
- `feature/*` - New features
- `fix/*` - Bug fixes
- `docs/*` - Documentation changes
- `chore/*` - Maintenance tasks

### Creating a Feature Branch

```bash
# Sync with upstream
git fetch upstream
git checkout main
git merge upstream/main

# Create feature branch
git checkout -b feature/my-awesome-feature
```

### Making Changes

1. **Templates** (`templates/`): Follow Helm best practices
2. **Values** (`values.yaml`): Document all new values with comments
3. **Dependencies** (`Chart.yaml`): Pin specific versions, add ArtifactHub links

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
type(scope): description

[optional body]

[optional footer]
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `chore`: Maintenance
- `refactor`: Code refactoring
- `test`: Adding tests
- `ci`: CI/CD changes

Examples:
```
feat(grafana): add support for external OAuth configuration
fix(vmalert): resolve recursive template include
docs(readme): update installation instructions
chore(deps): bump loki to 6.52.0
```

---

## Pull Request Process

### Before Submitting

1. **Sync with upstream**:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Run tests locally**:
   ```bash
   make lint
   make template
   # Optionally: make dev (full install test)
   ```

3. **Update documentation** if needed

4. **Add/update test values** in `ci/test-values/` if adding new features

### Submitting a PR

1. Push your branch:
   ```bash
   git push origin feature/my-awesome-feature
   ```

2. Open a PR on GitHub with:
   - Clear title following commit conventions
   - Description of changes
   - Link to related issues
   - Screenshots if UI-related

3. Fill out the PR template (if provided)

### PR Requirements

- [ ] All CI checks pass
- [ ] Code follows project conventions
- [ ] Documentation updated (if applicable)
- [ ] Test values added/updated (if applicable)
- [ ] No secrets or sensitive data included
- [ ] Commits are squashed/rebased cleanly

### Review Process

1. Maintainers will review within 1-2 business days
2. Address feedback by pushing new commits
3. Once approved, a maintainer will merge

---

## Coding Standards

### Helm Templates

```yaml
# Use named templates for reusable logic
{{- define "myapp.labels" -}}
app.kubernetes.io/name: {{ include "myapp.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

# Always check if values exist before using
{{- if .Values.myFeature.enabled }}
# ...
{{- end }}

# Use proper indentation with nindent
labels:
  {{- include "myapp.labels" . | nindent 4 }}

# Quote string values
value: {{ .Values.myValue | quote }}
```

### Values File

```yaml
# Group related values
myComponent:
  # Enable/disable the component
  enabled: true
  
  # Resource configuration
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi
  
  # Document complex values
  # Format: "duration" (e.g., "24h", "7d", "1w")
  retentionPeriod: "7d"
```

### Naming Conventions

- Templates: `kebab-case` (e.g., `grafana-instance.yaml`)
- Values: `camelCase` (e.g., `adminCredentials`)
- Kubernetes resources: Use helper templates for consistent naming

---

## Testing Guidelines

### Required Tests

1. **Lint** - `make lint` must pass
2. **Template render** - Must render without errors for all test values
3. **Install test** - Should install successfully on kind cluster

### Adding Test Values

When adding new features, update test values in `ci/test-values/`:

```yaml
# ci/test-values/all-enabled-values.yaml
myNewFeature:
  enabled: true
  config:
    key: value
```

### Running Tests

```bash
# Quick lint
make lint

# Template all test values
for f in ci/test-values/*.yaml; do
  echo "Testing $f..."
  helm template test . -f "$f" > /dev/null
done

# Full integration test
make dev
# Wait for pods to be ready
kubectl get pods -n observability -w
make dev-cleanup
```

### CI Pipeline

PRs automatically run:
1. Lint (helm lint, ct lint)
2. Template render tests (default, cluster-mode, all-enabled)
3. Kubernetes manifest validation (kubeconform)
4. Security scan (Trivy)
5. Install tests (Kubernetes 1.29, 1.31, 1.33, 1.35)

---

## Documentation

### When to Update Docs

- Adding new features → Update README.md, values.yaml comments
- Changing behavior → Update README.md, RUNBOOK.md
- Adding components → Update docs/architecture.md
- Changing CI/CD → Update RUNBOOK.md

### Documentation Files

| File | Purpose |
|------|---------|
| `README.md` | User-facing documentation |
| `RUNBOOK.md` | Operations guide |
| `CONTRIBUTING.md` | Contribution guidelines |
| `docs/architecture.md` | Technical architecture |
| `values.yaml` | Inline documentation for all values |

### Style Guide

- Use clear, concise language
- Include code examples
- Use tables for structured data
- Keep lines under 100 characters
- Use proper markdown formatting

---

## Release Process

Releases are handled by maintainers. If you're a maintainer:

### Version Bumping

Follow [Semantic Versioning](https://semver.org/):
- `MAJOR.MINOR.PATCH`
- MAJOR: Breaking changes
- MINOR: New features (backward compatible)
- PATCH: Bug fixes (backward compatible)

### Creating a Release

```bash
# 1. Update version in Chart.yaml
# 2. Update CHANGELOG (if maintained)
# 3. Commit and push
git add Chart.yaml
git commit -m "chore: release v0.2.0"
git push

# 4. Create tag
git tag v0.2.0
git push origin v0.2.0
```

The release workflow handles the rest automatically.

---

## Questions?

- Open a [GitHub Discussion](https://github.com/theorigamicorporation/k8s-observability-stack/discussions)
- Check existing [Issues](https://github.com/theorigamicorporation/k8s-observability-stack/issues)
- Review the [RUNBOOK.md](RUNBOOK.md) for operational guidance

Thank you for contributing! 🎉
