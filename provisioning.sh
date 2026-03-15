#!/bin/bash
# AI Girl Pipeline - Provisioning Script for ai-dock/comfyui
# Verified working paths based on live pod debugging (2026-03-15)
#
# InsightFace path rule: FaceAnalysis(root=R, name=N) → R/models/N/
# ComfyUI_IPAdapter_plus uses: root = /opt/ComfyUI/models/insightface
# → antelopev2 must be at: /opt/ComfyUI/models/insightface/models/antelopev2/

NODES=(
    "https://github.com/ltdrdata/ComfyUI-Manager"
    "https://github.com/cubiq/ComfyUI_IPAdapter_plus"
    "https://github.com/Gourieff/comfyui-reactor-node"
    "https://github.com/pythongosssss/ComfyUI-Custom-Scripts"
)

PIP_PACKAGES=(
    "insightface"
    "onnxruntime-gpu"
    "opencv-python-headless"
    "huggingface_hub"
)

# ========================
# DO NOT EDIT BELOW HERE UNLESS YOU KNOW WHAT YOU ARE DOING
# ========================

function provisioning_start() {
    source /opt/ai-dock/etc/environment.sh
    source /opt/ai-dock/bin/venv-set.sh comfyui

    provisioning_print_header
    provisioning_get_nodes
    provisioning_get_pip_packages
    provisioning_get_models
    provisioning_print_end
}

function pip_install() {
    if [[ -z $MAMBA_BASE ]]; then
        "$COMFYUI_VENV_PIP" install --no-cache-dir "$@"
    else
        micromamba run -n comfyui pip install --no-cache-dir "$@"
    fi
}

function venv_python() {
    # Get the Python interpreter for the comfyui venv
    if [[ -n $COMFYUI_VENV_PIP ]]; then
        echo "$(dirname "$COMFYUI_VENV_PIP")/python3"
    elif [[ -n $MAMBA_BASE ]]; then
        echo "micromamba run -n comfyui python3"
    else
        echo "python3"
    fi
}

function provisioning_get_pip_packages() {
    if [[ ${#PIP_PACKAGES[@]} -gt 0 ]]; then
        pip_install "${PIP_PACKAGES[@]}"
    fi
}

function provisioning_get_nodes() {
    for repo in "${NODES[@]}"; do
        dir="${repo##*/}"
        path="/opt/ComfyUI/custom_nodes/${dir}"
        requirements="${path}/requirements.txt"
        if [[ -d $path ]]; then
            printf "Updating node: %s...\n" "${repo}"
            ( cd "$path" && git pull )
            if [[ -e $requirements ]]; then
                pip_install -r "$requirements"
            fi
        else
            printf "Downloading node: %s...\n" "${repo}"
            git clone "${repo}" "${path}" --recursive
            if [[ -e $requirements ]]; then
                pip_install -r "${requirements}"
            fi
        fi
    done
}

function provisioning_get_models() {
    local COM_DIR=/opt/ComfyUI

    mkdir -p \
        "$COM_DIR/models/checkpoints" \
        "$COM_DIR/models/loras" \
        "$COM_DIR/models/ipadapter" \
        "$COM_DIR/models/clip_vision" \
        "$COM_DIR/models/insightface/models"

    # --- Checkpoint ---
    local CKPT="$COM_DIR/models/checkpoints/cyberrealisticPony_v15.safetensors"
    if [[ ! -f "$CKPT" ]]; then
        printf "Downloading cyberrealisticPony_v15...\n"
        wget -q --show-progress \
            -O "$CKPT" \
            "https://huggingface.co/cyberdelia/CyberRealisticPony/resolve/main/CyberRealisticPony_V15.0_FP16.safetensors"
    fi

    # --- IPAdapter LoRA ---
    local LORA="$COM_DIR/models/loras/ip-adapter-faceid-plusv2_sdxl_lora.safetensors"
    if [[ ! -f "$LORA" ]]; then
        printf "Downloading IPAdapter LoRA...\n"
        wget -q --show-progress \
            -O "$LORA" \
            "https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid-plusv2_sdxl_lora.safetensors"
    fi

    # --- IPAdapter model ---
    local IPA="$COM_DIR/models/ipadapter/ip-adapter-faceid-plusv2_sdxl.bin"
    if [[ ! -f "$IPA" ]]; then
        printf "Downloading IPAdapter model...\n"
        wget -q --show-progress \
            -O "$IPA" \
            "https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid-plusv2_sdxl.bin"
    fi

    # --- CLIP Vision ---
    local CLIP="$COM_DIR/models/clip_vision/clip_vision_g.safetensors"
    if [[ ! -f "$CLIP" ]]; then
        printf "Downloading CLIP Vision...\n"
        wget -q --show-progress \
            -O "$CLIP" \
            "https://huggingface.co/h94/IP-Adapter/resolve/main/models/image_encoder/model.safetensors"
    fi

    # --- antelopev2 (InsightFace face detection model) ---
    # IMPORTANT: FaceAnalysis(root=R, name=N) looks for models at R/models/N/
    # ComfyUI_IPAdapter_plus sets root = /opt/ComfyUI/models/insightface
    # → correct path: /opt/ComfyUI/models/insightface/models/antelopev2/
    local ANTELOPE_DIR="$COM_DIR/models/insightface/models/antelopev2"
    if [[ ! -f "$ANTELOPE_DIR/scrfd_10g_bnkps.onnx" ]]; then
        printf "Downloading antelopev2 (InsightFace)...\n"
        mkdir -p "$ANTELOPE_DIR"

        # Determine which python to use
        local PYTHON
        if [[ -n "$COMFYUI_VENV_PIP" ]]; then
            PYTHON="$(dirname "$COMFYUI_VENV_PIP")/python3"
        elif command -v micromamba &>/dev/null; then
            PYTHON="micromamba run -n comfyui python3"
        else
            PYTHON="python3"
        fi

        $PYTHON -c "
from huggingface_hub import snapshot_download
snapshot_download(
    repo_id='DIAMONIK7777/antelopev2',
    local_dir='${ANTELOPE_DIR}'
)
print('antelopev2 download complete')
"
        # Verify download
        if [[ -f "$ANTELOPE_DIR/scrfd_10g_bnkps.onnx" ]]; then
            printf "antelopev2: OK\n"
        else
            printf "ERROR: antelopev2 download failed!\n"
        fi
    fi
}

function provisioning_print_header() {
    printf "\n############################################\n"
    printf "#     AI Girl Pipeline Provisioning        #\n"
    printf "############################################\n\n"
}

function provisioning_print_end() {
    printf "\nProvisioning complete: ComfyUI will start now\n\n"
}

provisioning_start
