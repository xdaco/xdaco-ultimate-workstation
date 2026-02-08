# Multi-Architecture Container Build Guide

This guide explains how to build, tag, and push multi-architecture container images for the xdaco-ultimate project.

## Prerequisites

- Podman or Docker installed
- Docker Hub account (docker.io/1xdaco)
- Access to both AMD64 and ARM64 build environments (or QEMU for cross-compilation)

## Table of Contents

1. [Understanding the Build Hierarchy](#understanding-the-build-hierarchy)
2. [Option 1: Native Builds (Recommended)](#option-1-native-builds-recommended)
3. [Option 2: Cross-Platform Builds with QEMU](#option-2-cross-platform-builds-with-qemu)
4. [Option 3: Using Docker Buildx](#option-3-using-docker-buildx)
5. [Verifying Multi-Arch Images](#verifying-multi-arch-images)

---

## Understanding the Build Hierarchy

The xdaco-ultimate containers have a dependency chain:

```
xdaco-ultimate-base
    ↓
xdaco-ultimate-dev
    ↓
xdaco-ultimate-ai
```

**Important:** Each base image must have a multi-arch manifest before building dependent images.

---

## Option 1: Native Builds (Recommended)

Build each architecture on its native platform for best reliability and performance.

### Step 1: Build on AMD64 Machine (Linux Server/VM)

```bash
# Login to Docker Hub
podman login docker.io

# Build xdaco-ultimate-base (AMD64)
cd containers/xdaco-ultimate-base
podman build --platform linux/amd64 -t docker.io/1xdaco/xdaco-ultimate-base:amd64 .
podman push docker.io/1xdaco/xdaco-ultimate-base:amd64

# Build xdaco-ultimate-dev (AMD64)
cd ../xdaco-ultimate-dev
podman build --platform linux/amd64 -t docker.io/1xdaco/xdaco-ultimate-dev:amd64 .
podman push docker.io/1xdaco/xdaco-ultimate-dev:amd64

# Build xdaco-ultimate-ai (AMD64)
cd ../xdaco-ultimate-ai
podman build --platform linux/amd64 -t docker.io/1xdaco/xdaco-ultimate-ai:amd64 .
podman push docker.io/1xdaco/xdaco-ultimate-ai:amd64
```

### Step 2: Build on ARM64 Machine (Mac M1/M2 or ARM Server)

```bash
# Login to Docker Hub
podman login docker.io

# Build xdaco-ultimate-base (ARM64)
cd containers/xdaco-ultimate-base
podman build --platform linux/arm64 -t docker.io/1xdaco/xdaco-ultimate-base:arm64 .
podman push docker.io/1xdaco/xdaco-ultimate-base:arm64

# Create and push manifest for base
podman manifest create docker.io/1xdaco/xdaco-ultimate-base:latest
podman manifest add docker.io/1xdaco/xdaco-ultimate-base:latest docker.io/1xdaco/xdaco-ultimate-base:amd64
podman manifest add docker.io/1xdaco/xdaco-ultimate-base:latest docker.io/1xdaco/xdaco-ultimate-base:arm64
podman manifest push --all docker.io/1xdaco/xdaco-ultimate-base:latest

# Build xdaco-ultimate-dev (ARM64)
cd ../xdaco-ultimate-dev
podman build --platform linux/arm64 -t docker.io/1xdaco/xdaco-ultimate-dev:arm64 .
podman push docker.io/1xdaco/xdaco-ultimate-dev:arm64

# Create and push manifest for dev
podman manifest create docker.io/1xdaco/xdaco-ultimate-dev:latest
podman manifest add docker.io/1xdaco/xdaco-ultimate-dev:latest docker.io/1xdaco/xdaco-ultimate-dev:amd64
podman manifest add docker.io/1xdaco/xdaco-ultimate-dev:latest docker.io/1xdaco/xdaco-ultimate-dev:arm64
podman manifest push --all docker.io/1xdaco/xdaco-ultimate-dev:latest

# Build xdaco-ultimate-ai (ARM64)
cd ../xdaco-ultimate-ai
podman build --platform linux/arm64 -t docker.io/1xdaco/xdaco-ultimate-ai:arm64 .
podman push docker.io/1xdaco/xdaco-ultimate-ai:arm64

# Create and push manifest for ai
podman manifest create docker.io/1xdaco/xdaco-ultimate-ai:latest
podman manifest add docker.io/1xdaco/xdaco-ultimate-ai:latest docker.io/1xdaco/xdaco-ultimate-ai:amd64
podman manifest add docker.io/1xdaco/xdaco-ultimate-ai:latest docker.io/1xdaco/xdaco-ultimate-ai:arm64
podman manifest push --all docker.io/1xdaco/xdaco-ultimate-ai:latest
```

### Step 3: Verify Manifests

```bash
# Check that manifests contain both architectures
podman manifest inspect docker.io/1xdaco/xdaco-ultimate-base:latest
podman manifest inspect docker.io/1xdaco/xdaco-ultimate-dev:latest
podman manifest inspect docker.io/1xdaco/xdaco-ultimate-ai:latest
```

---

## Option 2: Cross-Platform Builds with QEMU

Build all architectures from a single machine using QEMU emulation.

### Setup QEMU (One-time)

```bash
# On Linux
sudo apt-get update
sudo apt-get install -y qemu-user-static

# Register QEMU handlers
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
```

### Build Script

```bash
#!/bin/bash
set -e

# Login
podman login docker.io

# Function to build multi-arch image
build_multiarch() {
    local IMAGE_NAME=$1
    local BUILD_DIR=$2
    
    echo "=== Building $IMAGE_NAME ==="
    cd "$BUILD_DIR"
    
    # Build both architectures
    podman build --platform linux/amd64 -t docker.io/1xdaco/${IMAGE_NAME}:amd64 .
    podman build --platform linux/arm64 -t docker.io/1xdaco/${IMAGE_NAME}:arm64 .
    
    # Push platform-specific images
    podman push docker.io/1xdaco/${IMAGE_NAME}:amd64
    podman push docker.io/1xdaco/${IMAGE_NAME}:arm64
    
    # Create and push manifest
    podman manifest rm docker.io/1xdaco/${IMAGE_NAME}:latest 2>/dev/null || true
    podman manifest create docker.io/1xdaco/${IMAGE_NAME}:latest
    podman manifest add docker.io/1xdaco/${IMAGE_NAME}:latest docker.io/1xdaco/${IMAGE_NAME}:amd64
    podman manifest add docker.io/1xdaco/${IMAGE_NAME}:latest docker.io/1xdaco/${IMAGE_NAME}:arm64
    podman manifest push --all docker.io/1xdaco/${IMAGE_NAME}:latest
    
    cd ..
}

# Build in dependency order
build_multiarch "xdaco-ultimate-base" "containers/xdaco-ultimate-base"
build_multiarch "xdaco-ultimate-dev" "containers/xdaco-ultimate-dev"
build_multiarch "xdaco-ultimate-ai" "containers/xdaco-ultimate-ai"

echo "=== All images built successfully! ==="
```

Save as `build-multiarch.sh` and run:

```bash
chmod +x build-multiarch.sh
./build-multiarch.sh
```

---

## Option 3: Using Docker Buildx

Docker Buildx provides the simplest multi-arch build experience.

### Setup Buildx (One-time)

```bash
# Create a new builder instance
docker buildx create --name multiarch --use
docker buildx inspect --bootstrap
```

### Build and Push

```bash
# Login
docker login docker.io

# Build xdaco-ultimate-base
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t docker.io/1xdaco/xdaco-ultimate-base:latest \
  --push \
  ./containers/xdaco-ultimate-base

# Build xdaco-ultimate-dev
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t docker.io/1xdaco/xdaco-ultimate-dev:latest \
  --push \
  ./containers/xdaco-ultimate-dev

# Build xdaco-ultimate-ai
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t docker.io/1xdaco/xdaco-ultimate-ai:latest \
  --push \
  ./containers/xdaco-ultimate-ai
```

**Note:** Buildx automatically creates and pushes the multi-arch manifest.

---

## Verifying Multi-Arch Images

### Check Manifest Content

```bash
# Inspect the manifest to see all architectures
podman manifest inspect docker.io/1xdaco/xdaco-ultimate-dev:latest

# Or using Docker
docker manifest inspect docker.io/1xdaco/xdaco-ultimate-dev:latest
```

Expected output should show both platforms:
```json
{
  "manifests": [
    {
      "platform": {
        "architecture": "amd64",
        "os": "linux"
      }
    },
    {
      "platform": {
        "architecture": "arm64",
        "os": "linux"
      }
    }
  ]
}
```

### Test Pull on Different Architectures

```bash
# On AMD64 machine
podman pull docker.io/1xdaco/xdaco-ultimate-dev:latest
podman inspect docker.io/1xdaco/xdaco-ultimate-dev:latest --format '{{.Architecture}}'
# Output: amd64

# On ARM64 machine (Mac M1/M2)
podman pull docker.io/1xdaco/xdaco-ultimate-dev:latest
podman inspect docker.io/1xdaco/xdaco-ultimate-dev:latest --format '{{.Architecture}}'
# Output: arm64
```

---

## Common Issues

### Issue: "No such file or directory" for `/bin/sh`

**Cause:** Cross-compilation without QEMU support.

**Solution:** Install QEMU (see Option 2) or use native builds (see Option 1).

### Issue: "Image is not a manifest list"

**Cause:** Trying to add images to a regular image tag instead of a manifest.

**Solution:** Delete the existing tag and create a new manifest:
```bash
podman rmi docker.io/1xdaco/xdaco-ultimate-dev:latest
podman manifest create docker.io/1xdaco/xdaco-ultimate-dev:latest
```

### Issue: "Image not found" when adding to manifest

**Cause:** Platform-specific images haven't been pushed to the registry yet.

**Solution:** Push images before creating manifests:
```bash
podman push docker.io/1xdaco/xdaco-ultimate-dev:amd64
podman push docker.io/1xdaco/xdaco-ultimate-dev:arm64
```

---

## Quick Reference

### Manifest Commands

```bash
# Create manifest
podman manifest create <manifest-name>

# Add image to manifest
podman manifest add <manifest-name> <image:tag>

# Inspect manifest
podman manifest inspect <manifest-name>

# Push manifest
podman manifest push --all <manifest-name>

# Remove manifest
podman manifest rm <manifest-name>
```

### Useful Aliases

Add to your shell config:

```bash
# Build and push multi-arch
alias build-multi='docker buildx build --platform linux/amd64,linux/arm64 --push'

# Inspect manifest
alias inspect-manifest='podman manifest inspect'
```

---

## CI/CD Integration

See `.github/workflows/build.yml` for automated multi-arch builds using GitHub Actions.

Key features:
- Builds on AMD64 runners
- Uses QEMU for ARM64 cross-compilation
- Automatically creates and pushes manifests
- Optional signing with Cosign

---

## Additional Resources

- [Podman Manifest Documentation](https://docs.podman.io/en/latest/markdown/podman-manifest.1.html)
- [Docker Buildx Documentation](https://docs.docker.com/build/buildx/)
- [Multi-platform Images Best Practices](https://docs.docker.com/build/building/multi-platform/)