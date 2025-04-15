FROM ghcr.io/open-webui/pipelines:main

# Use the correct port
ENV PIPELINES_SERVER_PORT=9099
ENV PIPELINES_SERVER_HOST=0.0.0.0

# Update healthcheck port
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:9099/health || exit 1