FROM nvidia/cuda:12.3.2-devel-ubuntu22.04

# Set build-time environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV HF_HOME=/root/.cache/huggingface
ENV PATH=/usr/local/nvidia/bin:/usr/local/cuda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV OLLAMA_HOST=0.0.0.0:11434
ENV HF_HUB_ENABLE_HF_TRANSFER=1
ENV PYTHONWARNINGS="ignore::FutureWarning"

# Runtime environment variables
ENV OLLAMA_NUM_GPU=1
ENV OLLAMA_GPU_LAYERS=-1
ENV RAG_EMBEDDING_ENGINE=ollama
ENV RAG_EMBEDDING_MODEL=nomic-embed-text
ENV RAG_RERANKING_MODEL=mixedbread-ai/mxbai-rerank-base-v1

WORKDIR /app

# System packages section
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    software-properties-common \
    curl \
    git \
    libgl1-mesa-glx \
    libglib2.0-0 \
    ffmpeg \
    libheif-dev \
    libde265-dev \
    netcat-openbsd \
    apache2 \
    default-jre \
    socat \
    wget \
    poppler-utils \
    && rm -rf /var/lib/apt/lists/*

# Add deadsnakes PPA for Python 3.11
RUN add-apt-repository ppa:deadsnakes/ppa -y

# Use faster mirror
RUN sed -i 's|http://\(archive\|security\).ubuntu.com|http://us.archive.ubuntu.com|g' /etc/apt/sources.list

# Update again to get the new packages
RUN apt-get update && \
    apt-get install -y \
    python3.11 \
    python3.11-venv \
    python3.11-dev \
    && rm -rf /var/lib/apt/lists/*

# Set Python 3.11 as the default Python
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 && \
    update-alternatives --install /usr/bin/python python /usr/bin/python3.11 1

# Install pip for Python 3.11
RUN python3.11 -m ensurepip && \
    python3.11 -m pip install --upgrade pip setuptools wheel

# Install Ollama
RUN curl -fsSL https://ollama.com/install.sh | sh && \
    echo "export PATH=\$PATH:/usr/local/bin" >> /root/.bashrc

# Install Apache Tika for content extraction
RUN mkdir -p /usr/share/java && \
    wget -O /usr/share/java/tika-server.jar https://dlcdn.apache.org/tika/3.1.0/tika-server-standard-3.1.0.jar

# Install Redis client for caching
RUN apt-get update && apt-get install -y redis-tools && \
    rm -rf /var/lib/apt/lists/*

# Python packages section
RUN python3.11 -m pip install --ignore-installed \
    # Core dependencies
    blinker \
    open-webui \
    chromadb \
    sentence-transformers \
    langchain \
    langchain-core \
    langchain-community \
    redis \
    # Image processing
    pillow-heif \
    pyheif \
    Pillow \
    # HuggingFace integration
    huggingface_hub \
    hf_transfer \
    # Speech-to-text
    faster-whisper \
    # Stock market tool dependencies
    finnhub-python \
    transformers \
    torch \
    bs4

# Create necessary directories
RUN mkdir -p /usr/local/lib/python3.11/dist-packages/open_webui/data/uploads && \
    mkdir -p /tmp/chromadb/web-search-qwen && \    
    mkdir -p /root/.cache/huggingface/hub && \
    mkdir -p /app/docker/startup && \
    chmod -R 777 /usr/local/lib/python3.11/dist-packages/open_webui/data && \
    chmod -R 777 /tmp/chromadb && \
    touch /tmp/chromadb/web-search-qwen/.keep && \
    mkdir -p /usr/local/lib/python3.11/dist-packages/open_webui/static/custom && \
    touch /usr/local/lib/python3.11/dist-packages/open_webui/static/custom/minerva-title.js

# Expose ports
EXPOSE 11434 8080

# Default entrypoint (expects ollama.sh to be mounted)
ENTRYPOINT ["/bin/bash", "-c", "if [ -f /app/ollama.sh ]; then chmod +x /app/ollama.sh && /app/ollama.sh; else echo 'ERROR: ollama.sh not mounted'; exit 1; fi"]