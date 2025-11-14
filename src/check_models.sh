#!/usr/bin/env bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "======================================================================"
echo "worker-comfyui-faceswap: Checking RunPod Volume Models"
echo "======================================================================"

# Network volume base path
VOLUME_BASE="/runpod-volume"

# Function to check if a directory exists and has files
check_directory() {
    local dir_path=$1
    local dir_name=$2
    local required=${3:-false}
    
    if [ -d "$dir_path" ]; then
        local file_count=$(find "$dir_path" -type f 2>/dev/null | wc -l)
        if [ "$file_count" -gt 0 ]; then
            echo -e "${GREEN}✓${NC} $dir_name: Found $file_count file(s)"
            return 0
        else
            if [ "$required" = true ]; then
                echo -e "${RED}✗${NC} $dir_name: Directory exists but is EMPTY"
                return 1
            else
                echo -e "${YELLOW}⚠${NC} $dir_name: Directory exists but is empty"
                return 0
            fi
        fi
    else
        if [ "$required" = true ]; then
            echo -e "${RED}✗${NC} $dir_name: Directory NOT FOUND at $dir_path"
            return 1
        else
            echo -e "${YELLOW}⚠${NC} $dir_name: Directory not found (optional)"
            return 0
        fi
    fi
}

# Check if volume is mounted
if [ ! -d "$VOLUME_BASE" ]; then
    echo -e "${RED}ERROR: RunPod volume not found at $VOLUME_BASE${NC}"
    echo "This worker requires a network volume to be attached."
    echo "Please ensure your RunPod endpoint has a network volume mounted at $VOLUME_BASE"
    exit 1
fi

echo -e "${GREEN}✓${NC} RunPod volume mounted at: $VOLUME_BASE"
echo ""

# Track overall status
ERRORS=0
WARNINGS=0

echo "Checking model directories..."
echo "----------------------------------------------------------------------"

# Check required base models
echo ""
echo "Base Models (REQUIRED):"
check_directory "$VOLUME_BASE/models/checkpoints" "Checkpoints" true || ((ERRORS++))

# Check optional but recommended models
echo ""
echo "Recommended Models:"
check_directory "$VOLUME_BASE/models/vae" "VAE Models" false || ((WARNINGS++))
check_directory "$VOLUME_BASE/models/clip" "CLIP Models" false || ((WARNINGS++))
check_directory "$VOLUME_BASE/models/unet" "UNET Models" false || ((WARNINGS++))

# Check optional enhancement models
echo ""
echo "Optional Enhancement Models:"
check_directory "$VOLUME_BASE/models/loras" "LoRA Models" false || ((WARNINGS++))
check_directory "$VOLUME_BASE/models/controlnet" "ControlNet Models" false || ((WARNINGS++))
check_directory "$VOLUME_BASE/models/upscale_models" "Upscale Models" false || ((WARNINGS++))
check_directory "$VOLUME_BASE/models/embeddings" "Embeddings" false || ((WARNINGS++))

echo ""
echo "======================================================================"

# Print summary
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo "======================================================================"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ Checks completed with $WARNINGS warning(s)${NC}"
    echo "The worker will start, but some optional features may not be available."
    echo "======================================================================"
    exit 0
else
    echo -e "${RED}✗ Checks failed with $ERRORS error(s) and $WARNINGS warning(s)${NC}"
    echo ""
    echo "REQUIRED MODELS MISSING!"
    echo ""
    echo "Please ensure your RunPod network volume contains:"
    echo "  • At least one checkpoint model in: $VOLUME_BASE/models/checkpoints/"
    echo ""
    echo "Your faceswap workflow may also need additional models in:"
    echo "  • $VOLUME_BASE/models/vae/"
    echo "  • $VOLUME_BASE/models/clip/"
    echo "  • $VOLUME_BASE/models/unet/"
    echo "  • Any other model directories your workflow uses"
    echo "======================================================================"
    
    # Allow override with environment variable for testing
    if [ "${SKIP_MODEL_CHECK:-false}" = "true" ]; then
        echo -e "${YELLOW}WARNING: Continuing despite errors (SKIP_MODEL_CHECK=true)${NC}"
        exit 0
    fi
    
    exit 1
fi