# Health Steps Sync API Server

A Python Flask API server for storing and retrieving step count data with built-in thread safety and JSONL-based persistence.

## Prerequisites

- Python 3.8+
- pip

## Installation

```bash
cd api
pip install -r requirements.txt
```

## Running the Server

```bash
cd api
python3 main.py
```

You should see output like:
```
Starting Flask API server on http://0.0.0.0:8000
Data will be stored in: /path/to/api/data/steps.jsonl
```

The server is now accessible at `http://localhost:8000` on your local machine.

## API Documentation

See [SCHEMA.md](SCHEMA.md) for detailed API endpoint documentation, including:
- All available endpoints and their parameters
- Complete data schema with field descriptions
- Request/response examples with curl commands
- Error handling and troubleshooting

## Troubleshooting

### API requests fail with connection refused
- Verify the server is running: `curl http://localhost:8000/health`
- Check that you're using the correct port

### Data not persisting between requests
- Verify the `api/data/` directory exists and is writable
- Check the `api/data/steps.jsonl` file to see stored data
- Review server logs for any error messages
