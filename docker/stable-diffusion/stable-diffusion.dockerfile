FROM universonic/stable-diffusion-webui:latest

USER root

# Install xformers compatible with PyTorch 2.2.0
RUN pip install --no-cache-dir --no-dependencies xformers==0.0.23 packaging

# Fix git security issue
RUN git config --global --add safe.directory /app/stable-diffusion-webui

# Create stable-diffusion directory structure
RUN mkdir -p /app/stable-diffusion-webui/models/Stable-diffusion /app/stable-diffusion-webui/config

# Download DreamShaper XL model
RUN wget -q https://civitai.com/api/download/models/251662 \
    -O /app/stable-diffusion-webui/models/Stable-diffusion/dreamshaper_xl_v2.0.safetensors

# Create config to make DreamShaper XL the default model
RUN echo '{"sd_model_checkpoint": "dreamshaper_xl_v2.0.safetensors [251662]"}' > \
    /app/stable-diffusion-webui/config/ui-config.json

# The entrypoint will use the mounted script from docker/startup/stable-diffusion.sh