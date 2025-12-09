# Helm Chart Release Process

This document describes how to cut new releases of the Spark Operator Helm chart and publish them via GitHub Pages.

## Overview

The Spark Operator Helm chart is published to GitHub Pages at `https://vedant-deshpande.github.io/spark-operator` using a `gh-pages` branch that contains:
- Packaged Helm chart (.tgz files)
- Helm repository index (`index.yaml`)

## Prerequisites

- Helm 3+ installed
- Git access to this repository
- GitHub Pages enabled on the `gh-pages` branch (Settings → Pages → Build and deployment → gh-pages branch)

## Release Process

### Step 1: Update Chart Version (if needed)

Edit `charts/spark-operator-chart/Chart.yaml` and update:
- `version`: The chart version (e.g., `2.3.1`)
- `appVersion`: The Spark Operator app version (e.g., `2.3.0`)

### Step 2: Commit Your Changes

```bash
git add charts/spark-operator-chart/Chart.yaml
git commit -m "Bump chart version to X.Y.Z"
git push origin odh  # or your branch
```

### Step 3: Package the Chart

Switch to the branch with your changes and package the chart:

```bash
git checkout odh  # or your release branch
mkdir -p /tmp/helm-charts
helm package charts/spark-operator-chart -d /tmp/helm-charts
```

This creates a file like: `/tmp/helm-charts/spark-operator-2.3.1.tgz`

### Step 4: Generate/Update the Repository Index

Generate the Helm repository index with the GitHub Pages URL:

```bash
helm repo index /tmp/helm-charts --url https://vedant-deshpande.github.io/spark-operator
```

This creates/updates `/tmp/helm-charts/index.yaml` with references to all chart versions.

### Step 5: Update the gh-pages Branch

```bash
# Switch to gh-pages branch
git checkout gh-pages

# Copy the new/updated files
cp /tmp/helm-charts/spark-operator-*.tgz .
cp /tmp/helm-charts/index.yaml .

# Stage and commit
git add spark-operator-*.tgz index.yaml
git commit -m "Release Spark Operator Helm chart version X.Y.Z"

# Push to GitHub
git push origin gh-pages
```

### Step 6: Verify the Release

Wait a few seconds for GitHub Pages to rebuild, then verify:

```bash
# Update your local helm repos
helm repo update spark-operator

# Search for the new version
helm search repo spark-operator
```

You should see the new version listed.

## Automated Script (Optional)

You can create a release script to automate steps 3-5:

```bash
#!/bin/bash
set -e

CHART_DIR="charts/spark-operator-chart"
VERSION=$(grep "^version:" $CHART_DIR/Chart.yaml | awk '{print $2}')

echo "Packaging Spark Operator Helm chart v$VERSION..."
mkdir -p /tmp/helm-charts
helm package $CHART_DIR -d /tmp/helm-charts

echo "Generating Helm repository index..."
helm repo index /tmp/helm-charts --url https://vedant-deshpande.github.io/spark-operator

echo "Updating gh-pages branch..."
git checkout gh-pages
cp /tmp/helm-charts/spark-operator-*.tgz .
cp /tmp/helm-charts/index.yaml .
git add spark-operator-*.tgz index.yaml
git commit -m "Release Spark Operator Helm chart version $VERSION"
git push origin gh-pages

echo "Release complete! Version $VERSION is now available."
echo "Run 'helm repo update spark-operator' to get the latest charts."
```

## Using the Helm Repository

Once a release is published, users can install the chart:

```bash
# Add the repository (if not already added)
helm repo add spark-operator https://vedant-deshpande.github.io/spark-operator
helm repo update

# Install the chart
helm install my-spark-operator spark-operator/spark-operator \
  --namespace spark-operator \
  --create-namespace \
  --values values.yaml
```

## Troubleshooting

### GitHub Pages not updating
- Wait 1-2 minutes for GitHub Pages to rebuild
- Check that the `gh-pages` branch is selected in Settings → Pages
- Verify files are in the root of the `gh-pages` branch

### index.yaml 404 errors
- Ensure `index.yaml` is in the root of the `gh-pages` branch
- Check that GitHub Pages is enabled and pointed to the `gh-pages` branch

### Chart not found in search
- Run `helm repo update spark-operator` to refresh the local cache
- Verify the chart URL in `index.yaml` is accessible

## References

- [Helm Chart Repository Guide](https://helm.sh/docs/topics/chart_repository/)
- [GitHub Pages Documentation](https://docs.github.com/en/pages)
