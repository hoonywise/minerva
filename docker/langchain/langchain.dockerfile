FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    libaio1 \
    libaio-dev \
    curl \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Set the working directory
WORKDIR /app

# Install Python packages
RUN pip install --no-cache-dir \
    langchain \
    openai \
    requests \
    flask \
    oracledb

# Copy application files
COPY . /app

# Set environment variables
ENV OLLAMA_API_BASE_URL=http://ollama-container:11434
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

# Expose the port for the Flask app
EXPOSE 5000

# Start the Flask server
CMD ["python", "app.py"]
