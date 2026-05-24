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

The xdaco-ultimate containers share one common base, with language-specific
toolchains layered on top as siblings:

```
xdaco-ultimate-base            (shared by everyone)
    ├── xdaco-ultimate-cpp     (base + heavy C/C++ toolchain)
    └── xdaco-ultimate-php     (base + php-cli + extensions + Composer)
```

**Important:** `base` must have a multi-arch manifest before building `cpp`/`php`,
since both are `FROM xdaco-ultimate-base:latest`.

---

## Tagging Convention & Incremental Updates

Updates to these images are **incremental**: only the changed layers are rebuilt,
and the `debian:trixie` base layers are shared, so consumers re-pull only the diff.

To keep updates non-breaking and rollback-safe, **always push two tags per image**:

| Tag | Purpose |
| --- | --- |
| `:latest` | Moving tag consumers track. Must **always** be a multi-arch manifest list. |
| `:YYYY-MM-DD` | Immutable snapshot of that day's build. Never overwritten — use it to pin or roll back. |

Rules that protect the multi-arch design:

1. **Never push `:latest` from a single-arch build.** Doing so replaces the
   manifest list with a one-architecture image and breaks every consumer on the
   other architecture. Always build the full platform set and push the index in
   one operation (Buildx `--push`, or `podman manifest push`).
2. **Publish `base` first**, then `cpp`/`php` — both resolve `base`'s `:latest`
   manifest from the registry via their `FROM` line.
3. **Pin downstream `FROM` lines to an immutable tag** when you need a
   reproducible build instead of tracking a moving `:latest`.

> The CI workflow in `.github/workflows/build.yml` follows these rules
> automatically: every push/PR verifies a multi-arch build, and a
> `workflow_dispatch` with `push_to_registry=true` publishes `:latest` +
> `:YYYY-MM-DD` as proper manifest lists.

---

## One-Command Publish (Local)

For local publishing without CI, use the helper script. It builds every target
platform into a manifest list and pushes `:latest` + an immutable `:YYYY-MM-DD`
tag for each image, in dependency order — all from a single command.

```bash
podman login docker.io          # once

# Build + push all images (base first, then cpp/php), both arches:
scripts/publish-containers.sh

# A subset, or a single image:
scripts/publish-containers.sh base cpp

# Local multi-arch build only (no push), e.g. to test changes:
scripts/publish-containers.sh --no-push base
```

Common options (also settable via env vars):

| Flag | Env | Default | Meaning |
| --- | --- | --- | --- |
| `-r, --registry` | `REGISTRY` | `docker.io` | Target registry |
| `-n, --namespace` | `NAMESPACE` | `1xdaco` | Registry namespace |
| `-p, --platforms` | `PLATFORMS` | `linux/amd64,linux/arm64` | Platforms to build |
| `-t, --tag` | `DATE_TAG` | UTC `YYYY-MM-DD` | Immutable snapshot tag |
| `--no-latest` | — | (push latest) | Skip updating `:latest` |
| `--no-push` | — | (push) | Build the manifest locally only |

Run `scripts/publish-containers.sh --help` for full usage.

> Building a non-native architecture locally (e.g. `amd64` on an Apple Silicon
> Mac) runs under QEMU inside the podman machine and is slow for source-compiled
> layers. Prefer CI (native runners per arch) for routine multi-arch publishes;
> use this script for one-offs or when CI isn't available.

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

# Build xdaco-ultimate-cpp (AMD64)
cd ../xdaco-ultimate-cpp
podman build --platform linux/amd64 -t docker.io/1xdaco/xdaco-ultimate-cpp:amd64 .
podman push docker.io/1xdaco/xdaco-ultimate-cpp:amd64

# Build xdaco-ultimate-php (AMD64)
cd ../xdaco-ultimate-php
podman build --platform linux/amd64 -t docker.io/1xdaco/xdaco-ultimate-php:amd64 .
podman push docker.io/1xdaco/xdaco-ultimate-php:amd64
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

# Build xdaco-ultimate-cpp (ARM64)
cd ../xdaco-ultimate-cpp
podman build --platform linux/arm64 -t docker.io/1xdaco/xdaco-ultimate-cpp:arm64 .
podman push docker.io/1xdaco/xdaco-ultimate-cpp:arm64

# Create and push manifest for cpp
podman manifest create docker.io/1xdaco/xdaco-ultimate-cpp:latest
podman manifest add docker.io/1xdaco/xdaco-ultimate-cpp:latest docker.io/1xdaco/xdaco-ultimate-cpp:amd64
podman manifest add docker.io/1xdaco/xdaco-ultimate-cpp:latest docker.io/1xdaco/xdaco-ultimate-cpp:arm64
podman manifest push --all docker.io/1xdaco/xdaco-ultimate-cpp:latest

# Build xdaco-ultimate-php (ARM64)
cd ../xdaco-ultimate-php
podman build --platform linux/arm64 -t docker.io/1xdaco/xdaco-ultimate-php:arm64 .
podman push docker.io/1xdaco/xdaco-ultimate-php:arm64

# Create and push manifest for php
podman manifest create docker.io/1xdaco/xdaco-ultimate-php:latest
podman manifest add docker.io/1xdaco/xdaco-ultimate-php:latest docker.io/1xdaco/xdaco-ultimate-php:amd64
podman manifest add docker.io/1xdaco/xdaco-ultimate-php:latest docker.io/1xdaco/xdaco-ultimate-php:arm64
podman manifest push --all docker.io/1xdaco/xdaco-ultimate-php:latest
```

### Step 3: Verify Manifests

```bash
# Check that manifests contain both architectures
podman manifest inspect docker.io/1xdaco/xdaco-ultimate-base:latest
podman manifest inspect docker.io/1xdaco/xdaco-ultimate-cpp:latest
podman manifest inspect docker.io/1xdaco/xdaco-ultimate-php:latest
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
build_multiarch "xdaco-ultimate-cpp" "containers/xdaco-ultimate-cpp"
build_multiarch "xdaco-ultimate-php" "containers/xdaco-ultimate-php"

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

# Immutable snapshot tag for this publish (rollback / pinning)
DATE=$(date -u +'%Y-%m-%d')

# Build xdaco-ultimate-base (latest + immutable date tag)
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t docker.io/1xdaco/xdaco-ultimate-base:latest \
  -t docker.io/1xdaco/xdaco-ultimate-base:${DATE} \
  --provenance=false \
  --push \
  ./containers/xdaco-ultimate-base

# Build xdaco-ultimate-cpp (FROM base:latest — publish after base)
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t docker.io/1xdaco/xdaco-ultimate-cpp:latest \
  -t docker.io/1xdaco/xdaco-ultimate-cpp:${DATE} \
  --provenance=false \
  --push \
  ./containers/xdaco-ultimate-cpp

# Build xdaco-ultimate-php
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t docker.io/1xdaco/xdaco-ultimate-php:latest \
  -t docker.io/1xdaco/xdaco-ultimate-php:${DATE} \
  --provenance=false \
  --push \
  ./containers/xdaco-ultimate-php
```

**Note:** Buildx automatically creates and pushes the multi-arch manifest.

---

## Verifying Multi-Arch Images

### Check Manifest Content

```bash
# Inspect the manifest to see all architectures
podman manifest inspect docker.io/1xdaco/xdaco-ultimate-cpp:latest

# Or using Docker
docker manifest inspect docker.io/1xdaco/xdaco-ultimate-cpp:latest
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
podman pull docker.io/1xdaco/xdaco-ultimate-cpp:latest
podman inspect docker.io/1xdaco/xdaco-ultimate-cpp:latest --format '{{.Architecture}}'
# Output: amd64

# On ARM64 machine (Mac M1/M2)
podman pull docker.io/1xdaco/xdaco-ultimate-cpp:latest
podman inspect docker.io/1xdaco/xdaco-ultimate-cpp:latest --format '{{.Architecture}}'
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
podman rmi docker.io/1xdaco/xdaco-ultimate-cpp:latest
podman manifest create docker.io/1xdaco/xdaco-ultimate-cpp:latest
```

### Issue: "Image not found" when adding to manifest

**Cause:** Platform-specific images haven't been pushed to the registry yet.

**Solution:** Push images before creating manifests:
```bash
podman push docker.io/1xdaco/xdaco-ultimate-cpp:amd64
podman push docker.io/1xdaco/xdaco-ultimate-cpp:arm64
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

Two workflows drive CI:

- `.github/workflows/build.yml` — orchestrator. Resolves the run mode + shared
  date tag, then builds `base` then `cpp`/`php` and (optionally) signs.
- `.github/workflows/build-image.yml` — reusable, builds one image multi-arch.

How it works:
- **Native runners, no QEMU.** Each architecture builds on its own runner via a
  matrix: `amd64` on `ubuntu-latest`, `arm64` on `ubuntu-24.04-arm` (free for
  public repos). This avoids emulating the Rust-from-source layers in the base.
- **Every push/PR verifies both arches** (built in parallel, `push: false`) —
  catches arm64 regressions before they reach the registry.
- **`workflow_dispatch` with `push_to_registry=true`** pushes each arch *by
  digest*, then a `merge` job assembles a manifest list tagged `:latest` +
  immutable `:YYYY-MM-DD` via `docker buildx imagetools create`. `:latest` is
  therefore never published as a single-arch image.
- Builds in dependency order so `dev`'s `FROM base:latest` resolves the freshly
  merged parent.
- Generates an SBOM (Syft) per image and optionally signs each manifest-list
  digest with Cosign (keyless/OIDC).

> To add `ai`/`db` to CI, copy the `dev` job in `build.yml` (adjust `image`,
> `context`, and `needs` to chain after its parent).

---

## Additional Resources

- [Podman Manifest Documentation](https://docs.podman.io/en/latest/markdown/podman-manifest.1.html)
- [Docker Buildx Documentation](https://docs.docker.com/build/buildx/)
- [Multi-platform Images Best Practices](https://docs.docker.com/build/building/multi-platform/)