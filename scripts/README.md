# Manual Unity Build System

This directory contains scripts and workflows for manually triggering Unity Docker image builds. The original bot-based trigger system has been replaced with a manual trigger system that you can control.

## Quick Start

The easiest way to build Unity 6000.3 images is using the GitHub Actions UI:

1. Go to your repository on GitHub
2. Click **Actions** tab → **Manual Unity Build 🚀**
3. Click **Run workflow**
4. Leave Unity version empty for auto-detection, or specify one (e.g., `6000.0.23f1`)
5. Click **Run workflow**

## Unity Version Manager Script

The `unity-version-manager.sh` script helps you manage Unity versions and trigger builds from the command line.

### Prerequisites

- `curl` (for API calls)
- `jq` (for JSON processing)  
- `gh` (GitHub CLI, for triggering workflows)
- **Unity License configured** (see [Unity Licensing Guide](../UNITY_LICENSING_GUIDE.md))

Install missing dependencies:
```bash
# macOS
brew install jq gh

# Ubuntu/Debian  
sudo apt install jq curl
# Install GitHub CLI: https://cli.github.com/

# Windows (WSL)
sudo apt install jq curl
# Install GitHub CLI: https://cli.github.com/
```

### Usage Examples

#### Check Latest Unity 6000.3 Version
```bash
./scripts/unity-version-manager.sh latest 6000
```

#### Check if Specific Version is Available in Unity CI
```bash
./scripts/unity-version-manager.sh check 2023.2.20f1
```

#### List All Available Unity 6000 Versions
```bash
./scripts/unity-version-manager.sh versions 6000
```

#### Trigger Manual Build (Latest Version)
```bash
# This will auto-detect the latest Unity 6000.3 version and trigger a build
./scripts/unity-version-manager.sh trigger
```

#### Trigger Manual Build (Specific Version)
```bash
./scripts/unity-version-manager.sh trigger 2023.2.20f1
```

#### Trigger Build for Specific Platforms Only
```bash
./scripts/unity-version-manager.sh trigger 2023.2.20f1 "base,android,webgl"
```

#### Trigger Build Without Base Images (if they already exist)
```bash
./scripts/unity-version-manager.sh trigger 2023.2.20f1 "base,linux-il2cpp,android,webgl" false
```

## GitHub Actions Manual Trigger

You can also trigger builds directly from the GitHub Actions UI:

1. Go to your repository on GitHub
2. Click on the "Actions" tab
3. Select "Manual Unity Build 🚀" from the workflow list
4. Click "Run workflow"
5. Fill in the parameters:
   - **Unity version**: Leave empty for auto-detection of latest 6000.3, or specify (e.g., `2023.2.20f1`)
   - **Repository version**: Leave empty for auto-generation, or specify (e.g., `4.0.0`)
   - **Target platforms**: Comma-separated list of platforms to build
   - **Build base images**: Whether to build base and hub images first

### Available Target Platforms

- `base` - Base editor without additional modules
- `linux-il2cpp` - Linux IL2CPP support
- `windows-mono` - Windows Mono support  
- `mac-mono` - macOS Mono support
- `ios` - iOS build support
- `android` - Android build support
- `webgl` - WebGL build support

## Available Workflows

### 1. Manual Unity Build 🚀 (Recommended)
**File**: `manual-unity-build.yml`
**Purpose**: Complete build pipeline for Unity images

This workflow:
- Auto-detects latest Unity 6000.3 version (or uses your specified version)
- Builds base and hub images (optional)
- Builds editor images for selected platforms
- Handles all dependencies and build order automatically

**Trigger via GitHub UI or CLI:**
```bash
gh workflow run "Manual Unity Build 🚀" \
  --field unity_version="6000.0.23f1" \
  --field target_platforms="base,linux-il2cpp,android,webgl" \
  --field build_base_images="true"
```

### 2. Individual Component Workflows
**Files**: Various `new-*-requested.yml` files
**Purpose**: Build specific components manually

These workflows now support both `repository_dispatch` (for compatibility) and manual `workflow_dispatch` triggers.

## How It Works

The manual trigger system:

1. **Auto-detects** the latest Unity 6000.3 version using Unity's GraphQL API
2. **Validates** that Unity CI base images are available on Docker Hub
3. **Generates** repository version numbers based on current date/time
4. **Builds** images directly in your GitHub Actions pipelines
5. **Handles** dependencies and build order (base → hub → editor platforms)

## Build Process

```
Unity Version Detection
         ↓
Base Image Build (Ubuntu)
         ↓ 
Hub Image Build (Unity Hub)
         ↓
Editor Image Builds (Parallel)
├── base (no modules)
├── linux-il2cpp
├── android  
├── webgl
├── ios
├── windows-mono
└── mac-mono
```

## Troubleshooting

### "Unity version X not found in unity-ci"
The Unity version doesn't have pre-built Unity CI base images. Check [Unity CI Docker Hub](https://hub.docker.com/r/jpellet/gameci-editor/tags) for available versions.

### "GitHub CLI (gh) is not installed"
Install GitHub CLI to enable command-line workflow triggering:
```bash
brew install gh  # macOS
```

### "Not authenticated with GitHub CLI"
Authenticate with GitHub:
```bash
gh auth login
```

### Workflow fails with Docker Hub authentication
Make sure your repository has these secrets configured:
- `DOCKERHUB_USERNAME` 
- `DOCKERHUB_TOKEN`

### Build takes too long or fails
Builds are resource-intensive (30+ minutes per platform). Check workflow logs in GitHub Actions for detailed errors. Common issues:
- Disk space (handled by free_disk_space.sh)
- Network timeouts (automatic retry logic included)
- Unity download failures (check Unity version availability)

### Script shows "unknown changeset"
This is usually not a problem. The changeset is auto-detected but may fall back to a default value if Unity's API structure changes.

## Migration from Bot System

- **Before**: External bot sent `repository_dispatch` events
- **After**: Manual triggers via GitHub UI or CLI
- **Compatibility**: Old `repository_dispatch` triggers still work
- **Benefits**: Direct control, better visibility, easier debugging

The new system builds the same Docker images with the same tags and structure.
