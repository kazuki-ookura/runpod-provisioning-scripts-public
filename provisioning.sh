#!/bin/bash
# RunPod Provisioning Script for AI Girl Pipeline

export COM_DIR=/workspace/ComfyUI
mkdir -p $COM_DIR/custom_nodes
cd $COM_DIR/custom_nodes

echo "Installing aria2c..."
apt-get update && apt-get install -y aria2

echo "Cloning custom nodes..."
[ ! -d ComfyUI-Manager ] && git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Manager.git
[ ! -d ComfyUI_IPAdapter_plus ] && git clone --depth 1 https://github.com/cubiq/ComfyUI_IPAdapter_plus.git
[ ! -d comfyui-reactor-node ] && git clone --depth 1 https://github.com/Gourieff/comfyui-reactor-node.git
[ ! -d ComfyUI-Custom-Scripts ] && git clone --depth 1 https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git

echo "Downloading models with aria2c..."
mkdir -p $COM_DIR/models/checkpoints $COM_DIR/models/loras $COM_DIR/models/ipadapter $COM_DIR/models/clip_vision

# aria2c for parallel parts
[ ! -f $COM_DIR/models/checkpoints/cyberrealisticPony_v11.safetensors ] && aria2c -x 16 -s 16 -o cyberrealisticPony_v11.safetensors -d $COM_DIR/models/checkpoints "https://civitai.com/api/download/models/414418"
[ ! -f $COM_DIR/models/loras/ip-adapter-faceid-plusv2_sdxl_lora.safetensors ] && aria2c -x 16 -s 16 -o ip-adapter-faceid-plusv2_sdxl_lora.safetensors -d $COM_DIR/models/loras "https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid-plusv2_sdxl_lora.safetensors"
[ ! -f $COM_DIR/models/ipadapter/ip-adapter-faceid-plusv2_sdxl.bin ] && aria2c -x 16 -s 16 -o ip-adapter-faceid-plusv2_sdxl.bin -d $COM_DIR/models/ipadapter "https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid-plusv2_sdxl.bin"
[ ! -f $COM_DIR/models/clip_vision/clip_vision_g.safetensors ] && aria2c -x 16 -s 16 -o clip_vision_g.safetensors -d $COM_DIR/models/clip_vision "https://huggingface.co/h94/IP-Adapter/resolve/main/models/image_encoder/CLIP-ViT-bigG-14-laion2B-32k-b79k.safetensors"

echo "Setup complete. ComfyUI will restart shortly."
