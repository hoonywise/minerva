FROM jupyter/minimal-notebook:latest

USER root
# Install system dependencies if needed
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    && rm -rf /var/lib/apt/lists/*

USER ${NB_UID}
# Install Python packages - match your command from docker-compose
RUN pip install --no-cache-dir \
    matplotlib seaborn numpy pandas scipy scikit-learn \
    pydantic fastapi requests beautifulsoup4 plotly \
    nltk pillow openpyxl PyPDF2 lxml rich \
    jupyter_ai tiktoken transformers \
    torch torchvision torchaudio \
    langchain langchain_ollama

# Set working directory
WORKDIR /home/jovyan/work

# Add this at the end of jupyter.dockerfile
CMD ["start-notebook.sh", "--ServerApp.disable_check_xsrf=True", "--ServerApp.token=''", "--ServerApp.password=''", "--ServerApp.base_url=''", "--ServerApp.allow_origin=*", "--ServerApp.ip=0.0.0.0"]