#!/bin/bash
# RunPod Provisioning Script for AI Girl Pipeline

set -e  # エラー時に即終了

export COM_DIR=/workspace/ComfyUI
mkdir -p $COM_DIR/custom_nodes
cd $COM_DIR/custom_nodes

echo "=== [1/5] Installing system packages ==="
apt-get update && apt-get install -y aria2 unzip build-essential cmake python3-dev

echo "=== [2/5] Cloning custom nodes ==="
[ ! -d ComfyUI-Manager ] && git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Manager.git
[ ! -d ComfyUI_IPAdapter_plus ] && git clone --depth 1 https://github.com/cubiq/ComfyUI_IPAdapter_plus.git
[ ! -d comfyui-reactor-node ] && git clone --depth 1 https://github.com/Gourieff/comfyui-reactor-node.git
[ ! -d ComfyUI-Custom-Scripts ] && git clone --depth 1 https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git

echo "=== [3/5] Installing Python dependencies for custom nodes ==="
PYTHON=/opt/venv/bin/python3
if [ ! -f "$PYTHON" ]; then
    PYTHON=python3
fi

# IPAdapter に必要なライブラリ（insightface はコンパイルが必要なので先に依存を入れる）
$PYTHON -m pip install --no-cache-dir \
    insightface \
    "onnxruntime-gpu>=1.16.0" \
    opencv-python-headless \
    numpy

# 各ノードの requirements.txt を実行
for dir in ComfyUI_IPAdapter_plus comfyui-reactor-node; do
    if [ -d "$dir" ] && [ -f "$dir/requirements.txt" ]; then
        echo "  -> pip install -r $dir/requirements.txt"
        $PYTHON -m pip install --no-cache-dir -r "$dir/requirements.txt"
    fi
done

echo "=== [4/5] Downloading models ==="
mkdir -p $COM_DIR/models/checkpoints $COM_DIR/models/loras $COM_DIR/models/ipadapter $COM_DIR/models/clip_vision

[ ! -f $COM_DIR/models/checkpoints/cyberrealisticPony_v15.safetensors ] && \
    aria2c -x 16 -s 16 -k 1M -o cyberrealisticPony_v15.safetensors -d $COM_DIR/models/checkpoints \
    "https://huggingface.co/cyberdelia/CyberRealisticPony/resolve/main/CyberRealisticPony_V15.0_FP16.safetensors"

[ ! -f $COM_DIR/models/loras/ip-adapter-faceid-plusv2_sdxl_lora.safetensors ] && \
    aria2c -x 16 -s 16 -k 1M -o ip-adapter-faceid-plusv2_sdxl_lora.safetensors -d $COM_DIR/models/loras \
    "https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid-plusv2_sdxl_lora.safetensors"

[ ! -f $COM_DIR/models/ipadapter/ip-adapter-faceid-plusv2_sdxl.bin ] && \
    aria2c -x 16 -s 16 -k 1M -o ip-adapter-faceid-plusv2_sdxl.bin -d $COM_DIR/models/ipadapter \
    "https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid-plusv2_sdxl.bin"

[ ! -f $COM_DIR/models/clip_vision/clip_vision_g.safetensors ] && \
    aria2c -x 16 -s 16 -k 1M -o clip_vision_g.safetensors -d $COM_DIR/models/clip_vision \
    "https://huggingface.co/h94/IP-Adapter/resolve/main/models/image_encoder/model.safetensors"

# InsightFace の antelopev2 モデル（IPAdapterFaceID に必須）
INSIGHT_DIR=/root/.insightface/models/antelopev2
if [ ! -d "$INSIGHT_DIR" ]; then
    mkdir -p /root/.insightface/models
    aria2c -x 16 -s 16 -k 1M -d /tmp -o antelopev2.zip \
        "https://huggingface.co/DIAMONIK7777/antelopev2/resolve/main/antelopev2.zip"
    unzip -o /tmp/antelopev2.zip -d /root/.insightface/models/
    rm /tmp/antelopev2.zip
fi

echo "=== [5/5] Setup complete! ComfyUI will restart. ==="
