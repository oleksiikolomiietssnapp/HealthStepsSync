import json
import os
import threading
from flask import Flask, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# Thread lock for safe file operations
file_lock = threading.Lock()

# Data directory and file paths
DATA_DIR = os.path.join(os.path.dirname(__file__), 'data')
JSONL_FILE = os.path.join(DATA_DIR, 'steps.jsonl')

# Ensure data directory exists
os.makedirs(DATA_DIR, exist_ok=True)


@app.route('/steps', methods=['POST'])
def save_steps():
    """Store step sample data to .jsonl file"""
    try:
        data = request.get_json()
        if not data or 'samples' not in data:
            return jsonify({'error': 'Invalid request body. Expected {"samples": [...]}'}), 400

        samples = data['samples']
        if not isinstance(samples, list):
            return jsonify({'error': 'samples must be a list'}), 400

        # Write samples to .jsonl file with thread safety
        with file_lock:
            with open(JSONL_FILE, 'a') as f:
                for sample in samples:
                    # Ensure sample is a dict
                    if not isinstance(sample, dict):
                        return jsonify({'error': 'Each sample must be a JSON object'}), 400

                    # Write as single line JSON
                    f.write(json.dumps(sample) + '\n')

        return jsonify({'saved': len(samples), 'message': 'Success'}), 200

    except json.JSONDecodeError:
        return jsonify({'error': 'Invalid JSON'}), 400
    except Exception as e:
        return jsonify({'error': f'Server error: {str(e)}'}), 500


@app.route('/steps', methods=['GET'])
def get_steps():
    """Retrieve all stored step samples"""
    try:
        samples = []

        # Read samples from .jsonl file with thread safety
        with file_lock:
            if os.path.exists(JSONL_FILE):
                with open(JSONL_FILE, 'r') as f:
                    for line in f:
                        line = line.strip()
                        if line:  # Skip empty lines
                            try:
                                samples.append(json.loads(line))
                            except json.JSONDecodeError:
                                # Skip malformed lines
                                continue

        return jsonify({'samples': samples, 'total': len(samples)}), 200

    except Exception as e:
        return jsonify({'error': f'Server error: {str(e)}'}), 500


@app.route('/steps', methods=['DELETE'])
def delete_all_steps():
    """Delete all stored step samples"""
    try:
        with file_lock:
            if os.path.exists(JSONL_FILE):
                os.remove(JSONL_FILE)
                return jsonify({'message': 'All steps deleted successfully'}), 200
            else:
                return jsonify({'message': 'No steps file to delete'}), 200

    except Exception as e:
        return jsonify({'error': f'Server error: {str(e)}'}), 500


@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({'status': 'ok'}), 200

if __name__ == '__main__':
    print("Starting Flask API server on http://0.0.0.0:8000")
    print(f"Data will be stored in: {JSONL_FILE}")
    app.run(host='0.0.0.0', port=8000, debug=True, threaded=True)