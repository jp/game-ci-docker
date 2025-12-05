# Manual Unity Build Guide

This guide shows you how to manually trigger Unity Docker image builds now that the original bot system no longer works.

## Quick Start - GitHub Actions UI

The easiest way to build images:

1. **Navigate to Actions**: Go to your repository → **Actions** tab
2. **Select Workflow**: Click **"Manual Unity Build 🚀"** 
3. **Run Workflow**: Click **"Run workflow"** button
4. **Configure Build**:
   - **Unity version**: Leave empty for latest 6000.3, or specify (e.g., `6000.0.23f1`)
   - **Target platforms**: Default is `base,linux-il2cpp,android,webgl`
   - **Build base images**: Check if you need new base/hub images
5. **Start Build**: Click **"Run workflow"**

## Command Line Usage

### Prerequisites
```bash
# Install dependencies
brew install jq gh  # macOS
# OR
sudo apt install jq curl && <install gh separately>  # Linux

# Authenticate with GitHub
gh auth login
```

### Quick Commands

```bash
# Test Unity version detection
./scripts/unity-version-manager.sh latest 6000

# Check specific version availability  
./scripts/unity-version-manager.sh check 6000.0.23f1

# List available Unity 6000.x versions
./scripts/unity-version-manager.sh versions 6000

# Trigger build with latest Unity 6000.3
./scripts/unity-version-manager.sh trigger

# Trigger build with specific version
./scripts/unity-version-manager.sh trigger 6000.0.23f1

# Trigger build for specific platforms only
./scripts/unity-version-manager.sh trigger 6000.0.23f1 "base,android,webgl"
```

## Build Configuration

### Target Platforms
- `base` - Editor without additional modules
- `linux-il2cpp` - Linux IL2CPP build support
- `windows-mono` - Windows Mono build support
- `mac-mono` - macOS Mono build support
- `ios` - iOS build support
- `android` - Android build support
- `webgl` - WebGL build support

### Build Options
- **Build base images**: Creates new `unityci/base` and `unityci/hub` images
- **Unity version**: Auto-detects latest 6000.3 LTS if not specified
- **Repository version**: Auto-generated timestamp if not specified

## What Gets Built

The system creates Docker images with these naming patterns:

```
# Base images (if enabled)
unityci/base:ubuntu-2024.12.05.1430
unityci/hub:ubuntu-2024.12.05.1430

# Editor images (per platform)
unityci/editor:6000.0.23f1-base-2024.12.05.1430
unityci/editor:6000.0.23f1-android-2024.12.05.1430
unityci/editor:6000.0.23f1-webgl-2024.12.05.1430
# ... etc for each platform
```

## Monitoring Builds

1. **GitHub Actions**: Check the **Actions** tab for build progress
2. **Docker Hub**: Monitor image publication at [hub.docker.com/u/unityci](https://hub.docker.com/u/unityci)
3. **Build Logs**: Click on workflow runs for detailed logs and error messages

## Typical Build Times

- **Base images**: ~10-15 minutes
- **Hub images**: ~5-10 minutes  
- **Editor images**: ~30-60 minutes per platform
- **Total time**: 1-3 hours depending on platform count

## Troubleshooting

### Common Issues

**"Unity version X not found in unity-ci"**
- The version lacks Unity CI base images
- Check: https://hub.docker.com/r/unityci/editor/tags
- Try a different Unity version

**"Not authenticated with GitHub CLI"**
```bash
gh auth login
```

**"Workflow not found"**
- Ensure you're in the correct repository directory
- Check workflow file exists: `.github/workflows/manual-unity-build.yml`

**Docker Hub authentication errors**
- Verify repository secrets are configured:
  - `DOCKERHUB_USERNAME`
  - `DOCKERHUB_TOKEN`

### Build Failures

**Disk space errors**
- The workflow includes automatic cleanup
- Retry the build - transient storage issues are common

**Unity download timeouts**
- Builds include automatic retry logic
- Check Unity's download servers aren't experiencing issues

**Platform-specific failures**
- Some platforms (like iOS) may have additional requirements
- Check build logs for platform-specific error messages

## Testing Your Setup

Run the test workflow to verify everything is working:

1. Go to **Actions** → **"Test Unity Version Detection 🧪"**
2. Click **"Run workflow"**
3. Optionally specify Unity major version (6000, 2023, etc.)
4. Check results for Unity version detection and CI image availability

## Migration Notes

- **Old system**: External bot triggered via repository_dispatch
- **New system**: Manual triggers with same build logic
- **Compatibility**: Repository dispatch events still work if needed
- **Images**: Same Docker images, tags, and functionality

The manual system gives you full control over when builds happen and with which Unity versions.
