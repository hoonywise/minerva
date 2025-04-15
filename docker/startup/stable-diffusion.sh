#!/bin/bash
# Stable Diffusion startup script

# Check if repositories already exist (were persisted via volume)
if [ ! -d "/app/stable-diffusion-webui/repositories/generative-models" ]; then
  echo "Repository directory not found in volume, will download during startup..."
else
  echo "Using existing repositories from volume..."
fi

# Check if DreamShaper XL exists, download if missing
if [ ! -f "/app/stable-diffusion-webui/models/Stable-diffusion/dreamshaper_xl_v2.0.safetensors" ]; then
  echo "Downloading DreamShaper XL v2.0 model..."
  wget -q --show-progress https://civitai.com/api/download/models/251662 \
    -O /app/stable-diffusion-webui/models/Stable-diffusion/dreamshaper_xl_v2.0.safetensors
  echo "DreamShaper XL model downloaded successfully!"
else
  echo "Using existing DreamShaper XL model from volume..."
fi

# Check if xformers is already installed
if ! pip show xformers > /dev/null 2>&1; then
  echo "Installing xformers for accelerated performance..."
  pip install --no-cache-dir --no-dependencies xformers==0.0.23 packaging
else
  echo "xformers already installed, skipping..."
fi

# Set DreamShaper XL as the default model
echo "Setting DreamShaper XL as default model..."
mkdir -p /app/stable-diffusion-webui/config
cat > /app/stable-diffusion-webui/config/ui-config.json <<EOL
{
  "sd_model_checkpoint": "dreamshaper_xl_v2.0.safetensors [251662]"
}
EOL

# Launch WebUI with automatic1111 compatibility
echo "Starting Stable Diffusion WebUI..."
python3 -W ignore launch.py --listen --api --api-auth="${SD_WEBUI_AUTH}" --xformers --no-half-vae --skip-version-check