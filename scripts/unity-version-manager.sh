#!/bin/bash

# Unity Version Manager Script
# Fetches Unity versions and can trigger builds

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to get latest Unity version for a major version
get_latest_unity_version() {
    local major_version=${1:-6000}
    
    log_info "Fetching latest Unity version for $major_version..."
    
    log_info "Making GraphQL request to Unity API..."
    local out=$(
        curl 'https://services.unity.com/graphql' -s \
            --compressed \
            -X POST \
            -H 'content-type: application/json' \
            --data-raw '{"operationName":"GetRelease","variables":{"version":"'${major_version}'","limit":1000},"query":"query GetRelease($limit: Int, $skip: Int, $version: String!, $stream: [UnityReleaseStream!]) {\n  getUnityReleases(\n    limit: $limit\n    skip: $skip\n    stream: $stream\n    version: $version\n    entitlements: [XLTS]\n  ) {\n    totalCount\n    edges {\n      node {\n        version\n        entitlements\n        releaseDate\n        unityHubDeepLink\n        stream\n        __typename\n      }\n      __typename\n    }\n    __typename\n  }\n}"}'
    )
    
    if [[ $? -ne 0 ]] || [[ -z "$out" ]]; then
        log_error "Failed to fetch Unity releases from API or empty response"
        return 1
    fi
    
    # Check for API errors
    if echo "$out" | jq -e '.errors' >/dev/null 2>&1; then
        log_error "Unity API returned errors:"
        echo "$out" | jq '.errors'
        return 1
    fi
    
    # Check if data exists
    if ! echo "$out" | jq -e '.data.getUnityReleases.edges' >/dev/null 2>&1; then
        log_error "No Unity releases data found in response"
        echo "Response: $out" | head -200
        return 1
    fi
    
    # Try SUPPORTED versions first
    local lts=$(echo "$out" | jq -r '.data.getUnityReleases.edges[]?.node | select(.stream | contains("SUPPORTED"))' 2>/dev/null || echo "")
    
    if [[ -z "$lts" ]]; then
        log_warning "No SUPPORTED versions found, trying LTS..."
        lts=$(echo "$out" | jq -r '.data.getUnityReleases.edges[]?.node | select(.stream | contains("LTS"))' 2>/dev/null || echo "")
    fi
    
    if [[ -z "$lts" ]]; then
        log_warning "No LTS versions found, taking first stable version..."
        lts=$(echo "$out" | jq -r '.data.getUnityReleases.edges[]?.node | select(.stream != "ALPHA" and .stream != "BETA")' 2>/dev/null | head -1)
    fi
    
    local unity_version=$(echo "$lts" | jq --slurp -r '.[0].version // empty' 2>/dev/null)
    
    if [[ -z "$unity_version" ]] || [[ "$unity_version" == "null" ]]; then
        log_error "No suitable Unity version found for $major_version"
        log_info "Available versions:"
        echo "$out" | jq -r '.data.getUnityReleases.edges[]?.node | "\(.version) - \(.stream)"' | head -5
        return 1
    fi
    
    echo "$unity_version"
}

# Function to check if Unity CI images are available
check_unity_ci_availability() {
    local unity_version=$1
    
    log_info "Checking Unity CI image availability for $unity_version..."
    
    local docker_response=$(curl -s "https://hub.docker.com/v2/repositories/unityci/editor/tags?page_size=25&page=1&ordering=last_updated&name=${unity_version}")
    local count=$(echo "$docker_response" | jq -r '.count // 0' 2>/dev/null || echo "0")
    
    if [[ $count -eq 0 ]]; then
        log_error "Unity version $unity_version not found in unity-ci Docker Hub repository"
        log_info "Check: https://hub.docker.com/r/unityci/editor/tags?name=${unity_version}"
        log_info "Docker Hub API response: $(echo "$docker_response" | head -200)"
        return 1
    fi
    
    log_success "Found $count Unity CI images for version $unity_version"
    return 0
}

# Function to get changeset for Unity version
get_changeset() {
    local version=$1
    
    log_info "Attempting to get changeset for Unity $version..."
    
    # Try to extract changeset from Unity download URL
    local changeset=$(curl -s -I "https://download.unity3d.com/download_unity/LinuxEditorInstaller/Unity-${version}.tar.xz" 2>/dev/null | grep -i location | grep -o '/[0-9a-f]\{12\}/' | tr -d '/' || echo "")
    
    if [[ -z "$changeset" ]]; then
        # Alternative: try to parse from version string
        changeset=$(echo "$version" | grep -o '[0-9a-f]\{12\}' | head -1 || echo "unknown")
    fi
    
    if [[ "$changeset" == "unknown" ]]; then
        log_warning "Could not determine changeset for $version, using 'unknown'"
    else
        log_success "Changeset: $changeset"
    fi
    
    echo "$changeset"
}

# Function to generate repository version
generate_repo_version() {
    local version=$(date +"%Y.%m.%d.%H%M")
    log_info "Generated repository version: $version"
    echo "$version"
}

# Function to trigger GitHub workflow
trigger_build() {
    local unity_version=$1
    local repo_version=$2
    local platforms=$3
    local build_base=${4:-true}
    local build_windows=${5:-false}
    
    if [[ ! -d "$REPO_ROOT/.git" ]]; then
        log_error "This script must be run from within the git repository"
        return 1
    fi
    
    if ! command -v gh &> /dev/null; then
        log_error "GitHub CLI (gh) is not installed. Please install it to trigger workflows."
        log_info "Install with: brew install gh"
        return 1
    fi
    
    log_info "Triggering manual build workflow..."
    log_info "Unity version: $unity_version"
    log_info "Repository version: $repo_version"
    log_info "Target platforms: $platforms"
    log_info "Build base images: $build_base"
    log_info "Build Windows images: $build_windows"
    
    cd "$REPO_ROOT"
    
    # Check if we're authenticated with GitHub
    if ! gh auth status &>/dev/null; then
        log_error "Not authenticated with GitHub CLI"
        log_info "Run: gh auth login"
        return 1
    fi
    
    gh workflow run "Manual Unity Build 🚀" \
        --field unity_version="$unity_version" \
        --field repo_version="$repo_version" \
        --field target_platforms="$platforms" \
        --field build_base_images="$build_base" \
        --field build_windows_images="$build_windows"
    
    if [[ $? -eq 0 ]]; then
        log_success "Workflow triggered successfully!"
        
        # Get repository info and construct URL
        local repo_info=$(gh repo view --json owner,name -q '.owner.login + "/" + .name' 2>/dev/null)
        if [[ -n "$repo_info" ]]; then
            log_info "Check workflow status at: https://github.com/${repo_info}/actions"
        else
            log_info "Check workflow status in the GitHub Actions tab of your repository"
        fi
        
        # Try to get the workflow run URL
        sleep 2
        local latest_run=$(gh run list --workflow="Manual Unity Build 🚀" --limit=1 --json url -q '.[0].url' 2>/dev/null)
        if [[ -n "$latest_run" ]]; then
            log_info "Direct link to workflow run: $latest_run"
        fi
    else
        log_error "Failed to trigger workflow"
        return 1
    fi
}

# Function to show available versions
show_versions() {
    local major_version=${1:-6000}
    
    log_info "Fetching all available Unity $major_version versions..."
    
    local out=$(
        curl 'https://services.unity.com/graphql' -s \
            --compressed \
            -X POST \
            -H 'content-type: application/json' \
            --data-raw '{"operationName":"GetRelease","variables":{"version":"'${major_version}'","limit":50},"query":"query GetRelease($limit: Int, $skip: Int, $version: String!, $stream: [UnityReleaseStream!]) {\n  getUnityReleases(\n    limit: $limit\n    skip: $skip\n    stream: $stream\n    version: $version\n    entitlements: [XLTS]\n  ) {\n    totalCount\n    edges {\n      node {\n        version\n        entitlements\n        releaseDate\n        unityHubDeepLink\n        stream\n        __typename\n      }\n      __typename\n    }\n    __typename\n  }\n}"}'
    )
    
    echo "$out" | jq -r '.data.getUnityReleases.edges[].node | "\(.version) - \(.stream) - \(.releaseDate)"' | sort -r
}

# Main function
main() {
    case "${1:-help}" in
        "latest")
            local major_version=${2:-6000}
            local version=$(get_latest_unity_version $major_version)
            if [[ $? -eq 0 ]]; then
                log_success "Latest Unity $major_version version: $version"
                if check_unity_ci_availability "$version"; then
                    local changeset=$(get_changeset "$version")
                    echo
                    echo "Version: $version"
                    echo "Changeset: $changeset"
                    echo "Unity CI Available: Yes"
                fi
            fi
            ;;
        "check")
            local version=$2
            if [[ -z "$version" ]]; then
                log_error "Please specify a Unity version to check"
                exit 1
            fi
            
            if check_unity_ci_availability "$version"; then
                local changeset=$(get_changeset "$version")
                echo
                echo "Version: $version"
                echo "Changeset: $changeset"
                echo "Unity CI Available: Yes"
            fi
            ;;
        "versions")
            local major_version=${2:-6000}
            show_versions $major_version
            ;;
        "trigger")
            local unity_version=${2}
            local platforms=${3:-"base,linux-il2cpp,android,webgl"}
            local build_base=${4:-true}
            local build_windows=${5:-false}
            
            if [[ -z "$unity_version" ]]; then
                log_info "No Unity version specified, detecting latest..."
                unity_version=$(get_latest_unity_version 6000)
            fi
            
            if [[ $? -ne 0 ]] || [[ -z "$unity_version" ]]; then
                log_error "Failed to determine Unity version"
                exit 1
            fi
            
            log_info "Unity version: $unity_version"
            
            if ! check_unity_ci_availability "$unity_version"; then
                exit 1
            fi
            
            local repo_version=$(generate_repo_version)
            
            trigger_build "$unity_version" "$repo_version" "$platforms" "$build_base" "$build_windows"
            ;;
        "help"|*)
            echo "Unity Version Manager"
            echo
            echo "Usage: $0 <command> [options]"
            echo
            echo "Commands:"
            echo "  latest [major_version]     Get latest Unity version (default: 6000)"
            echo "  check <version>           Check if Unity version is available in CI"
            echo "  versions [major_version]  List all available versions (default: 6000)"
            echo "  trigger [version] [platforms] [build_base] [build_windows]  Trigger build workflow"
            echo "    - version: Unity version (auto-detect latest if not specified)"
            echo "    - platforms: Comma-separated list (default: base,linux-il2cpp,android,webgl)"
            echo "    - build_base: true/false (default: true)"
            echo "    - build_windows: true/false (default: false)"
            echo
            echo "Examples:"
            echo "  $0 latest                                    # Get latest Unity 6000.x version"
            echo "  $0 latest 2023                              # Get latest Unity 2023.x version"
            echo "  $0 check 2023.2.20f1                       # Check if specific version is available"
            echo "  $0 versions 6000                            # List all Unity 6000.x versions"
            echo "  $0 trigger                                  # Trigger build with latest version"
            echo "  $0 trigger 6000.0.23f1                     # Trigger build with specific version"
            echo "  $0 trigger 6000.0.23f1 'base,android'      # Trigger build for specific platforms"
            echo "  $0 trigger 6000.0.23f1 'base,android' true true  # Include Windows images"
            ;;
    esac
}

# Check dependencies
if ! command -v curl &> /dev/null; then
    log_error "curl is required but not installed"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    log_error "jq is required but not installed"
    exit 1
fi

# Run main function
main "$@"
