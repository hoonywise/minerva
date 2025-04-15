#!/bin/sh
set -e

echo "Ensuring socat is installed..."
if ! command -v socat &> /dev/null; then
    if command -v apk &> /dev/null; then
        apk update && apk add --no-cache socat
    elif command -v apt-get &> /dev/null; then
        apt-get update && apt-get install -y socat
    else
        echo "ERROR: Package manager not found. Cannot install socat."
        exit 1
    fi
    echo "Socat installed successfully"
fi

# Start Tailscaled
tailscaled --tun=userspace-networking --state=/var/lib/tailscale/tailscaled.state &
sleep 2

# Show version and auth
tailscale version
echo "Authenticating with Tailscale..."
tailscale up --authkey=$TS_AUTHKEY --hostname=$TS_HOSTNAME --reset

# Show local tailnet IP
MY_IP=$(tailscale ip -4)
echo "My Tailscale IP: $MY_IP"

# Generate TLS certs for nginx
echo "Generating TLS certs..."
mkdir -p /etc/nginx/ssl
chmod 755 /etc/nginx/ssl
tailscale cert --cert-file=/etc/nginx/ssl/server.crt --key-file=/etc/nginx/ssl/server.key your.tailnet.ts.net

# Clear previous serve mappings
echo "Clearing previous serve mappings..."
tailscale serve --https=11434 off || true
tailscale serve --https=8888 off || true
tailscale serve --https=7860 off || true
tailscale serve --https=5000 off || true
tailscale serve --https=443 off || true
sleep 1

# Wait for container targets to be available
echo "Waiting for container services to be up..."
for i in {1..10}; do
  if nc -z ollama-container 8080 && nc -z jupyter-notebook 8888 && nc -z stable-diffusion 7860 && nc -z langchain-container 5000 && nc -z nginx-proxy 80; then
    echo "All containers are responding."
    break
  fi
  echo "Still waiting... ($i/10)"
  sleep 3
done

# Start persistent socat forwarders
echo "Starting socat forwarders..."

forward() {
  local LOCAL=$1
  local HOST=$2
  local REMOTE=$3
  (
    while true; do
      echo "Starting forwarder: $LOCAL → $HOST:$REMOTE"
      socat TCP-LISTEN:$LOCAL,reuseaddr,fork TCP:$HOST:$REMOTE
      echo "⚠ socat for $LOCAL died, restarting..."
      sleep 2
    done
  ) &
}

forward 80     nginx-proxy          80
forward 8080   ollama-container     8080
forward 9099   pipelines            9099
forward 8888   jupyter-notebook     8888
forward 9998   tika-server          9998
forward 7860   stable-diffusion     7860
forward 8880   kokoro-tts           8880
forward 5000   langchain-container  5000
forward 11434  ollama-container     11434

# Blocking wait for each local port
wait_for_port() {
  PORT=$1
  NAME=$2
  for i in $(seq 1 15); do
    if nc -z 127.0.0.1 $PORT; then
      echo "✔ $NAME (port $PORT) is up."
      return
    fi
    echo "⏳ Waiting for $NAME (port $PORT)... ($i/15)"
    sleep 2
  done
  echo "❌ $NAME (port $PORT) did not become ready in time."
}

echo "Waiting for local ports..."
wait_for_port 80 "NGINX"
wait_for_port 8888 "Jupyter"
wait_for_port 7860 "Stable Diffusion"
wait_for_port 5000 "Langchain"
wait_for_port 11434 "Ollama"

# Bind HTTPS ports with tailscale
echo "Binding Tailscale HTTPS ports..."
tailscale serve --bg --https=11434 http://127.0.0.1:11434
tailscale serve --bg --https=8888  http://127.0.0.1:8888
tailscale serve --bg --https=7860  http://127.0.0.1:7860
tailscale serve --bg --https=5000  http://127.0.0.1:5000
tailscale serve --bg --https=443   http://127.0.0.1:80

echo "Serve status:"
tailscale serve status

# Keep container alive
echo "Ready. Entering sleep loop..."
while true; do
  echo "[Tailscale] $(date) IP: $(tailscale ip -4)"
  sleep 900
done
