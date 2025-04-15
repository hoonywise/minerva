#!/bin/bash

# Set Critical Runtime Environment Variables
export HUGGINGFACE_HUB_TOKEN=${HUGGINGFACE_HUB_TOKEN}
export OLLAMA_API_KEY=${OLLAMA_API_KEY}
export WEBUI_OLLAMA_API_KEY=${OLLAMA_API_KEY}
export OLLAMA_API_BASE_URL="http://ollama-container:11434/"

# Configure Ollama if config doesn't exist
if [ ! -f /root/.ollama/config.json ]; then
    mkdir -p /root/.ollama/models
    chmod 755 /root/.ollama/models
    
    cat > /root/.ollama/config.json <<CONF
{
  "num_threads": 14,
  "batch_size": 2048,
  "num_ctx": 8192,
  "num_gpu_layers": -1,
  "rope_frequency_base": 10000,
  "rope_frequency_scale": 1.0,
  "mlock": true,
  "gpu_device_index": 0,
  "f16": true
}
CONF
fi

echo "Logging in to HuggingFace..."
python3 -c "from huggingface_hub import login; login('${HUGGINGFACE_HUB_TOKEN}')" || echo "HuggingFace login failed, continuing anyway"

# Download just the GPU version of Whisper
echo "Pre-downloading Faster Whisper..."
python3.11 -c "from faster_whisper import WhisperModel; WhisperModel('large-v3-turbo', device='cuda', compute_type='float16')"

# Download sentence transformer model separately
echo "Pre-downloading Reranker Model..."
python3.11 -c "from sentence_transformers import CrossEncoder; CrossEncoder('mixedbread-ai/mxbai-rerank-base-v1')"

# Clean ChromaDB storage on startup
echo "Cleaning ChromaDB temporary storage..."
rm -rf /tmp/chromadb/* || true
mkdir -p /tmp/chromadb/web-search-qwen
touch /tmp/chromadb/web-search-qwen/.keep
chown -R 1000:1000 /tmp/chromadb

# Start Ollama
ollama serve &
OLLAMA_PID=$!
sleep 10

# Auto-install models if needed
if ! ollama list | grep -q "qwen2.5:14b"; then
    echo "Installing Qwen2.5 14B model..."
    ollama pull qwen2.5:14b
fi

# Install nomic-embed-text model for embeddings via Ollama API
if ! ollama list | grep -q "nomic-embed-text"; then
    echo "Installing Nomic Embed Text model for embeddings..."
    ollama pull nomic-embed-text
fi

# CRITICAL: Add startup sequence delay to prevent race conditions
echo "Allowing GPU memory to stabilize before starting services..."
sleep 5

# Set WebUI and RAG optimization variables
echo "Configuring WebUI optimizations..."

# Context settings
export OLLAMA_MODEL_CONTEXT_WINDOW=8192
export OLLAMA_MODEL_CONTEXT_SIZE_OPTIMIZED=true
export OLLAMA_CONTEXT_RESET_BETWEEN_SESSIONS=true

# RAG enhancements
export RAG_EMBEDDING_INITIALIZED_CHECK=true
export RAG_WAIT_FOR_MODEL_READY=true
export RAG_VECTOR_DB_INITIALIZED_CHECK=true
export RAG_RETRY_ON_FIRST_FAILURE=true
export RAG_VECTOR_DB_COLLECTION_PER_QUERY=true
export RAG_RESET_CONTEXT_ON_TOPIC_CHANGE=true
export RAG_TOOL_INIT_TIMEOUT=30s

# WebUI optimizations
export WEBUI_RETRIEVAL_CONTEXT_FIX=true
export WEBUI_FIRST_REQUEST_DELAY=30000ms
export WEBUI_SEARCH_WARMUP=true
export WEBUI_SEARCH_PRIORITIZE_WARMUP=true
export WEBUI_CLEAR_CONTEXT_BETWEEN_TOOLS=true
export OLLAMA_TOOL_LOADING_STRATEGY=sequential

# Modify WebUI title to Minerva
echo "Setting WebUI title to Minerva..."
ENV_PY="/usr/local/lib/python3.11/dist-packages/open_webui/env.py"
if [ -f "$ENV_PY" ]; then
    # Replace the WEBUI_NAME setting
    sed -i 's/WEBUI_NAME = os.environ.get("WEBUI_NAME", "Open WebUI")/WEBUI_NAME = "Minerva"/g' "$ENV_PY"
    # Remove the conditional that appends "(Open WebUI)"
    sed -i '/if WEBUI_NAME != "Open WebUI":/,/WEBUI_NAME += " (Open WebUI)"/d' "$ENV_PY"
    
    # Also update favicon if needed
    sed -i 's/WEBUI_FAVICON_URL = "https:\/\/openwebui.com\/favicon.png"/WEBUI_FAVICON_URL = "\/favicon.ico"/g' "$ENV_PY"
    echo "WebUI title set to 'Minerva'"
else
    echo "Warning: WebUI env.py file not found at $ENV_PY"
fi

# Replace favicon files for both HTTP and HTTPS connections
echo "Replacing favicon files for Minerva branding..."

# Define the static directories
STATIC_DIR="/usr/local/lib/python3.11/dist-packages/open_webui/static"
FRONTEND_DIR="/usr/local/lib/python3.11/dist-packages/open_webui/frontend"
FRONTEND_STATIC_DIR="/usr/local/lib/python3.11/dist-packages/open_webui/frontend/static"

# Create directories if they don't exist
mkdir -p "$STATIC_DIR"
mkdir -p "$FRONTEND_STATIC_DIR"

# Copy favicon.ico to all possible locations
if [ -f "/app/custom/assets/favicon.ico" ]; then
    # Replace in the static directories
    cp "/app/custom/assets/favicon.ico" "$STATIC_DIR/favicon.ico"
    cp "/app/custom/assets/favicon.ico" "$FRONTEND_STATIC_DIR/favicon.ico"
    
    # Also replace in the frontend root (sometimes needed for HTTPS)
    cp "/app/custom/assets/favicon.ico" "$FRONTEND_DIR/favicon.ico"
    
    echo "Replaced favicon.ico in all directories"
fi

# Also update the manifest.json file if it exists to ensure PWA icon is updated
MANIFEST_FILE="$STATIC_DIR/manifest.json"
if [ -f "$MANIFEST_FILE" ]; then
    # Update the icons in the manifest file
    sed -i 's|"icons":\s*\[[^]]*\]|"icons": [{"src": "/favicon.ico", "sizes": "64x64 32x32 24x24 16x16", "type": "image/x-icon"}]|g' "$MANIFEST_FILE"
    echo "Updated manifest.json icons to use favicon.ico"
fi

echo "Favicon replacement completed"

# Setup WebUI directories
mkdir -p /usr/local/lib/python3.11/dist-packages/open_webui/data/uploads
chmod -R 777 /usr/local/lib/python3.11/dist-packages/open_webui/data

# Start WebUI
cd /usr/local/lib/python3.11/dist-packages/open_webui
open-webui serve &

# Keep container running
exec tail -f /dev/null