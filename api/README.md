# Health Steps Sync API Server

A Python Flask API server for storing and retrieving step count data with built-in thread safety and JSONL-based persistence.

## Prerequisites

- **Python 3.8+** (check with `python3 --version`)
- **pip** (comes with Python)

## Dependencies

The API uses the following Python packages (installed via `pip install -r requirements.txt`):
- **Flask** - Web framework for HTTP endpoints
- **Flask-CORS** - Cross-Origin Resource Sharing support for iOS app requests

## Installation (macOS)

1. Navigate to the API directory:
```bash
cd api
```

2. Create a Python virtual environment to isolate dependencies:
```bash
python3 -m venv venv
```

3. Activate the virtual environment:
```bash
source venv/bin/activate
```

4. Install dependencies:
```bash
pip install -r requirements.txt
```

You should see output like:
```
Collecting Flask==2.3.2
Collecting Flask-CORS==4.0.0
...
Successfully installed Flask-2.3.2 Flask-CORS-4.0.0
```

## Running the Server (macOS)

1. Ensure you're in the `api` directory with the venv activated:
```bash
cd api
source venv/bin/activate  # If not already activated
```

2. Start the server:
```bash
python3 main.py
```

You should see output like:
```
 * Serving Flask app 'main'
 * Debug mode: on
Starting Flask API server on http://0.0.0.0:8000
Data will be stored in: /path/to/api/data/steps.jsonl
```

The server is now accessible at `http://localhost:8000` on your local machine. The `api/data/` directory and `steps.jsonl` file are created automatically on first run.

### Physical Device Testing (Same WiFi Network)

To test the API from an iPhone on the same WiFi network:

1. **Find your Mac's local IP:**
   ```bash
   ifconfig | grep -E "inet " | grep -v 127.0.0.1
   ```
   Example output: `inet 192.168.0.200` (use this, not the loopback address)

2. **Test connectivity from iPhone Safari:**
   - Navigate to: `http://192.168.0.200:8000/health`
   - Should see: `{"status": "ok"}`

3. **If successful**, update the iOS app's endpoint at `ios/HealthStepsSync/Services/Network/Endpoint.swift` line 24:
   ```swift
   #else
       static var baseURL: String = "http://192.168.0.200:8000"  // Update to your Mac's IP
   #endif
   ```
   Replace `192.168.0.200` with your actual Mac IP from step 1.

4. **Run the app on physical device** - it will now sync data to your Mac's API

## API Documentation

See [SCHEMA.md](SCHEMA.md) for detailed API endpoint documentation, including:
- All available endpoints and their parameters
- Complete data schema with field descriptions
- Request/response examples with curl commands
- Error handling and troubleshooting

## Troubleshooting

### Python command not found

**Symptom:**
```
python3: command not found
```

**Solution:**
- Install Python 3.8+ from [python.org](https://www.python.org/downloads/)
- Or use Homebrew: `brew install python3`
- Verify: `python3 --version`

### pip install fails

**Symptom:**
```
command not found: pip
```

**Solution:**
- pip comes with Python 3.8+
- Try: `python3 -m pip install -r requirements.txt`
- If still failing, reinstall Python

### Virtual environment not activated

**Symptom:**
```
(base) $ python3 main.py  # Note: not in venv
```

**Solution:**
- Make sure you see `(venv)` at the start of your terminal prompt
- Activate with: `source venv/bin/activate`
- You should see: `(venv) $ python3 main.py`

### API requests fail with connection refused

**Symptom:**
```
curl: (7) Failed to connect to localhost port 8000
```

**Troubleshooting:**
1. Verify the server is running:
   ```bash
   curl http://localhost:8000/health
   ```
   Should return: `{"status": "ok"}`

2. If server is not running, start it:
   ```bash
   cd api
   source venv/bin/activate
   python3 main.py
   ```

3. Check if port 8000 is in use:
   ```bash
   lsof -i :8000
   ```
   If another process is using it, either stop that process or change the port in `main.py` (line 100)

4. Try accessing via IP instead of localhost:
   ```bash
   curl http://127.0.0.1:8000/health
   ```

### Data not persisting between requests

**Symptom:**
```
POST /steps returns 200, but GET /steps returns no data
```

**Troubleshooting:**

1. Verify the data directory exists:
   ```bash
   ls -la api/data/
   ```
   If missing, restart the server (creates automatically)

2. Check the JSONL file directly:
   ```bash
   cat api/data/steps.jsonl
   ```
   Should show one JSON object per line. If empty, POST requests may have failed.

3. Verify file permissions:
   ```bash
   ls -la api/data/steps.jsonl
   ```
   Should be readable/writable by your user. If not:
   ```bash
   chmod 644 api/data/steps.jsonl
   chmod 755 api/data/
   ```

4. Check server logs for errors (visible in terminal where server is running)

### Server crashes or exits unexpectedly

**Symptom:**
```
Starting Flask API server...
[process exits]
```

**Troubleshooting:**

1. Check for Python syntax errors:
   ```bash
   python3 -m py_compile main.py
   ```

2. Verify all dependencies are installed:
   ```bash
   pip list | grep Flask
   ```
   Should show Flask and Flask-CORS

3. Try running with explicit error output:
   ```bash
   python3 main.py 2>&1 | head -20
   ```

4. Check if port 8000 is already in use (see above)

### Firewall blocks iOS app from connecting

**Symptom (on physical device):**
```
Connection timeout when iOS app tries to sync
```

**Solution:**
1. When you first run the server, macOS may ask for firewall permission
   - Click "Allow" to permit Flask to accept connections
2. Manually allow in System Preferences → Security & Privacy → Firewall:
   - Add Python to allowed apps: `which python3`
3. Verify from iPhone:
   ```bash
   curl http://192.168.0.200:8000/health
   ```
   (Replace IP with your Mac's actual IP)

### JSONL file becomes corrupted

**Symptom:**
```
GET /steps returns partial data or errors
```

**Solution:**
- Corrupted lines are automatically skipped (see SCHEMA.md)
- To clean up: backup and delete the file
  ```bash
  mv api/data/steps.jsonl api/data/steps.jsonl.backup
  ```
- Restart the server (creates fresh file)
- Re-sync data from the iOS app
