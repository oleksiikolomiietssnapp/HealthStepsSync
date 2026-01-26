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
METADATA_FILE = os.path.join(DATA_DIR, 'metadata.json')

# Ensure data directory exists
os.makedirs(DATA_DIR, exist_ok=True)


def get_stored_count():
    """Get stored count from metadata file"""
    try:
        if os.path.exists(METADATA_FILE):
            with open(METADATA_FILE, 'r') as f:
                data = json.load(f)
                return data.get('count', 0)
    except:
        pass
    return 0


def set_stored_count(count):
    """Save stored count to metadata file"""
    with open(METADATA_FILE, 'w') as f:
        json.dump({'count': count}, f)


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

            # Update stored count
            current_count = get_stored_count()
            set_stored_count(current_count + len(samples))

        return jsonify({'saved': len(samples), 'message': 'Success'}), 200

    except json.JSONDecodeError:
        return jsonify({'error': 'Invalid JSON'}), 400
    except Exception as e:
        return jsonify({'error': f'Server error: {str(e)}'}), 500


@app.route('/steps', methods=['GET'])
def count_steps():
    """Retrieve total count of stored step samples"""
    try:
        stored_count = get_stored_count()
        return jsonify({'storedCount': stored_count}), 200

    except Exception as e:
        return jsonify({'error': f'Server error: {str(e)}'}), 500


@app.route('/steps', methods=['DELETE'])
def delete_all_steps():
    """Delete all stored step samples"""
    try:
        with file_lock:
            if os.path.exists(JSONL_FILE):
                os.remove(JSONL_FILE)
            # Reset stored count
            set_stored_count(0)
            return jsonify({'message': 'All steps deleted successfully'}), 200

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