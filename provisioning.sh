#!/bin/bash
# AI Girl Pipeline - Provisioning Script for ai-dock/comfyui
# Based on the official ai-dock provisioning format:
# https://github.com/ai-dock/comfyui/blob/main/config/provisioning/default.sh

# ai-dock カスタムノードリスト（NODES 配列）
NODES=(
    "https://github.com/ltdrdata/ComfyUI-Manager"
    "https://github.com/cubiq/ComfyUI_IPAdapter_plus"
    "https://github.com/Gourieff/comfyui-reactor-node"
    "https://github.com/pythongosssss/ComfyUI-Custom-Scripts"
)

# 追加でインストールする Python パッケージ
PIP_PACKAGES=(
    "insightface"
    "onnxruntime-gpu>=1.16.0"
    "opencv-python-headless"
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
    provisioning_get_additional_models
    provisioning_print_end
}

function pip_install() {
    if [[ -z $MAMBA_BASE ]]; then
        "$COMFYUI_VENV_PIP" install --no-cache-dir "$@"
    else
        micromamba run -n comfyui pip install --no-cache-dir "$@"
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

function provisioning_get_additional_models() {
    local COM_DIR=/opt/ComfyUI
    mkdir -p \
        "$COM_DIR/models/checkpoints" \
        "$COM_DIR/models/loras" \
        "$COM_DIR/models/ipadapter" \
        "$COM_DIR/models/clip_vision"

    # Checkpoint
    local CKPT="$COM_DIR/models/checkpoints/cyberrealisticPony_v15.safetensors"
    if [[ ! -f "$CKPT" ]]; then
        printf "Downloading cyberrealisticPony_v15...\n"
        aria2c -x 16 -s 16 -k 1M -o "$(basename $CKPT)" -d "$(dirname $CKPT)" \
            "https://huggingface.co/cyberdelia/CyberRealisticPony/resolve/main/CyberRealisticPony_V15.0_FP16.safetensors"
    fi

    # LoRA for IPAdapter FaceID
    local LORA="$COM_DIR/models/loras/ip-adapter-faceid-plusv2_sdxl_lora.safetensors"
    if [[ ! -f "$LORA" ]]; then
        printf "Downloading IPAdapter LoRA...\n"
        aria2c -x 16 -s 16 -k 1M -o "$(basename $LORA)" -d "$(dirname $LORA)" \
            "https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid-plusv2_sdxl_lora.safetensors"
    fi

    # IPAdapter model
    local IPA="$COM_DIR/models/ipadapter/ip-adapter-faceid-plusv2_sdxl.bin"
    if [[ ! -f "$IPA" ]]; then
        printf "Downloading IPAdapter model...\n"
        aria2c -x 16 -s 16 -k 1M -o "$(basename $IPA)" -d "$(dirname $IPA)" \
            "https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid-plusv2_sdxl.bin"
    fi

    # CLIP Vision
    local CLIP="$COM_DIR/models/clip_vision/clip_vision_g.safetensors"
    if [[ ! -f "$CLIP" ]]; then
        printf "Downloading CLIP Vision...\n"
        aria2c -x 16 -s 16 -k 1M -o "$(basename $CLIP)" -d "$(dirname $CLIP)" \
            "https://huggingface.co/h94/IP-Adapter/resolve/main/models/image_encoder/model.safetensors"
    fi

    # InsightFace antelopev2 (IPAdapter FaceID に必須)
    if [[ ! -d "/root/.insightface/models/antelopev2" ]]; then
        mkdir -p /root/.insightface/models
        aria2c -x 16 -s 16 -k 1M -d /tmp -o antelopev2.zip \
            "https://huggingface.co/DIAMONIK7777/antelopev2/resolve/main/antelopev2.zip"
        unzip -o /tmp/antelopev2.zip -d /root/.insightface/models/
        rm /tmp/antelopev2.zip
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
