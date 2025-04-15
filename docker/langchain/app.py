from flask import Flask, request, jsonify
import requests
import os
import json

app = Flask(__name__)

# Correctly use the internal service name
OLLAMA_API_BASE_URL = os.getenv("OLLAMA_API_BASE_URL", "http://ollama-container:11434")

@app.route("/health", methods=["GET"])
@app.route("/langchain/health", methods=["GET"])
def health_check():
    return jsonify(status="ok", message="LangChain service is running")

@app.route("/generate", methods=["POST"])
@app.route("/langchain/generate", methods=["POST"])
def generate_text():
    try:
        data = request.get_json()
        prompt = data.get("prompt", "")
        model = data.get("model", "qwen2.5:14b")  # Default model if not specified
        
        # Make the API call with streaming enabled
        response = requests.post(
            f"{OLLAMA_API_BASE_URL}/api/generate",
            json={"model": model, "prompt": prompt},
            stream=True
        )
        
        # Collect response data line by line
        generated_text = ""
        for line in response.iter_lines():
            if line:
                try:
                    # Parse each line as JSON
                    part = json.loads(line)
                    generated_text += part.get("response", "")
                except json.JSONDecodeError:
                    return jsonify(error="Invalid JSON response from Ollama", details=line.decode("utf-8")), response.status_code

        # Return the full generated text
        return jsonify(text=generated_text)
    except Exception as e:
        return jsonify(error=str(e)), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
