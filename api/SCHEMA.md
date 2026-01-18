# API Documentation

## Endpoints

### GET /health

Health check endpoint to verify the server is running and responsive.

**Request:**
```bash
curl http://localhost:8000/health
```

**Response (Success):**
```json
{
  "status": "ok"
}
```

**Status Code:** 200

---

### POST /steps

Store step sample data to the server. Accepts one or more step samples in a single request and appends them to the persistent data store.

**Request:**
```bash
curl -X POST http://localhost:8000/steps \
  -H "Content-Type: application/json" \
  -d '{
    "samples": [
      {
        "uuid": "550E8400-E29B-41D4-A716-446655440000",
        "startDate": "2024-01-15T08:00:00Z",
        "endDate": "2024-01-15T09:00:00Z",
        "count": 1250,
        "sourceBundleId": "com.apple.health",
        "sourceDeviceName": "iPhone 15"
      }
    ]
  }'
```

**Response (Success):**
```json
{
  "saved": 1,
  "message": "Success"
}
```

**Status Code:** 200

**Response (Missing or Invalid Request Body):**
```json
{
  "error": "Invalid request body. Expected {\"samples\": [...]}"
}
```

**Status Code:** 400

**Response (Malformed JSON):**
```json
{
  "error": "Invalid JSON"
}
```

**Status Code:** 400

**Response (Server Error):**
```json
{
  "error": "Server error: [error details]"
}
```

**Status Code:** 500

**Notes:**
- The `samples` field must be present and must be a list
- Each sample must be a valid JSON object
- Multiple samples can be sent in a single request
- The response indicates how many samples were successfully saved

---

### GET /steps

Retrieve all stored step samples from the server.

**Request:**
```bash
curl http://localhost:8000/steps
```

**Response (Success):**
```json
{
  "samples": [
    {
      "uuid": "550E8400-E29B-41D4-A716-446655440000",
      "startDate": "2024-01-15T08:00:00Z",
      "endDate": "2024-01-15T09:00:00Z",
      "count": 1250,
      "sourceBundleId": "com.apple.health",
      "sourceDeviceName": "iPhone 15"
    },
    {
      "uuid": "550E8400-E29B-41D4-A716-446655440001",
      "startDate": "2024-01-15T09:00:00Z",
      "endDate": "2024-01-15T10:00:00Z",
      "count": 890,
      "sourceBundleId": "com.apple.health",
      "sourceDeviceName": "iPhone 15"
    }
  ],
  "total": 2
}
```

**Status Code:** 200

**Response (Server Error):**
```json
{
  "error": "Server error: [error details]"
}
```

**Status Code:** 500

**Notes:**
- Returns all samples in the order they were stored
- If no samples have been stored yet, returns an empty array with `total: 0`
- Large result sets will return all samples in one response

---

### DELETE /steps

Delete all stored step samples from the server.

**Request:**
```bash
curl -X DELETE http://localhost:8000/steps
```

**Response (Success):**
```json
{
  "message": "All steps deleted successfully"
}
```

**Status Code:** 200

**Response (No Data to Delete):**
```json
{
  "message": "No steps file to delete"
}
```

**Status Code:** 200

**Response (Server Error):**
```json
{
  "error": "Server error: [error details]"
}
```

**Status Code:** 500

**Notes:**
- Deletes the entire `api/data/steps.jsonl` file
- Always returns success (200) even if no data exists
- This is a destructive operation - all stored samples are permanently removed
- The app uses this when the user taps the trash button to clear all local chunks and server data

---

## Data Schema

### StepSampleData

Each step sample stored on the server follows this schema:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `uuid` | string | Yes | Unique identifier for the step sample in UUID format |
| `startDate` | string | Yes | ISO 8601 timestamp when step counting started (e.g., `2024-01-15T08:00:00Z`) |
| `endDate` | string | Yes | ISO 8601 timestamp when step counting ended (e.g., `2024-01-15T09:00:00Z`) |
| `count` | integer | Yes | Number of steps counted during this sample period |
| `sourceBundleId` | string | Yes | iOS bundle ID of the app that recorded the data (e.g., `com.apple.health`) |
| `sourceDeviceName` | string | No | Optional device name where the sample originated (e.g., `iPhone 15`, `iPad Pro`) |

**Complete Example:**
```json
{
  "uuid": "550E8400-E29B-41D4-A716-446655440000",
  "startDate": "2024-01-15T08:00:00Z",
  "endDate": "2024-01-15T09:00:00Z",
  "count": 1250,
  "sourceBundleId": "com.apple.health",
  "sourceDeviceName": "iPhone 15"
}
```

**Minimal Example (sourceDeviceName is optional):**
```json
{
  "uuid": "550E8400-E29B-41D4-A716-446655440000",
  "startDate": "2024-01-15T08:00:00Z",
  "endDate": "2024-01-15T09:00:00Z",
  "count": 1250,
  "sourceBundleId": "com.apple.health"
}
```

---

## Data Storage

### JSONL Format

Step data is stored in a JSONL (JSON Lines) file located at `api/data/steps.jsonl`.

**Format:** Each line in the file is a complete, valid JSON object representing one step sample:
```
{"uuid": "550E8400-E29B-41D4-A716-446655440000", "startDate": "2024-01-15T08:00:00Z", "endDate": "2024-01-15T09:00:00Z", "count": 1250, "sourceBundleId": "com.apple.health", "sourceDeviceName": "iPhone 15"}
{"uuid": "550E8400-E29B-41D4-A716-446655440001", "startDate": "2024-01-15T09:00:00Z", "endDate": "2024-01-15T10:00:00Z", "count": 890, "sourceBundleId": "com.apple.health", "sourceDeviceName": "iPhone 15"}
```

### Thread Safety

All file operations are protected by a thread lock to ensure data integrity when multiple requests are processed simultaneously. This means:
- Multiple concurrent POST requests can safely write data without corruption
- Concurrent reads and writes are serialized to prevent data loss
- The `api/data/` directory and `steps.jsonl` file are created automatically on first run

### Data Persistence

- Data persists between server restarts
- The `api/data/steps.jsonl` file continues to grow as new samples are added
- Samples are never deleted by API operations (append-only)
- To clear data, manually delete the `api/data/steps.jsonl` file and restart the server

---

## Request/Response Examples

### Example 1: Storing a Single Sample

**Request:**
```bash
curl -X POST http://localhost:8000/steps \
  -H "Content-Type: application/json" \
  -d '{
    "samples": [
      {
        "uuid": "550e8400-e29b-41d4-a716-446655440000",
        "startDate": "2024-01-15T08:00:00Z",
        "endDate": "2024-01-15T09:00:00Z",
        "count": 1250,
        "sourceBundleId": "com.apple.health",
        "sourceDeviceName": "iPhone 15"
      }
    ]
  }'
```

**Response:**
```json
{
  "saved": 1,
  "message": "Success"
}
```

---

### Example 2: Storing Multiple Samples

**Request:**
```bash
curl -X POST http://localhost:8000/steps \
  -H "Content-Type: application/json" \
  -d '{
    "samples": [
      {
        "uuid": "550e8400-e29b-41d4-a716-446655440001",
        "startDate": "2024-01-15T09:00:00Z",
        "endDate": "2024-01-15T10:00:00Z",
        "count": 890,
        "sourceBundleId": "com.apple.health",
        "sourceDeviceName": "iPhone 15"
      },
      {
        "uuid": "550e8400-e29b-41d4-a716-446655440002",
        "startDate": "2024-01-15T10:00:00Z",
        "endDate": "2024-01-15T11:00:00Z",
        "count": 1105,
        "sourceBundleId": "com.apple.health",
        "sourceDeviceName": "iPhone 15"
      }
    ]
  }'
```

**Response:**
```json
{
  "saved": 2,
  "message": "Success"
}
```

---

### Example 3: Retrieving All Samples

**Request:**
```bash
curl http://localhost:8000/steps
```

**Response:**
```json
{
  "samples": [
    {
      "uuid": "550e8400-e29b-41d4-a716-446655440000",
      "startDate": "2024-01-15T08:00:00Z",
      "endDate": "2024-01-15T09:00:00Z",
      "count": 1250,
      "sourceBundleId": "com.apple.health",
      "sourceDeviceName": "iPhone 15"
    },
    {
      "uuid": "550e8400-e29b-41d4-a716-446655440001",
      "startDate": "2024-01-15T09:00:00Z",
      "endDate": "2024-01-15T10:00:00Z",
      "count": 890,
      "sourceBundleId": "com.apple.health",
      "sourceDeviceName": "iPhone 15"
    },
    {
      "uuid": "550e8400-e29b-41d4-a716-446655440002",
      "startDate": "2024-01-15T10:00:00Z",
      "endDate": "2024-01-15T11:00:00Z",
      "count": 1105,
      "sourceBundleId": "com.apple.health",
      "sourceDeviceName": "iPhone 15"
    }
  ],
  "total": 3
}
```

---

## Error Handling

### 400 Bad Request

Returned when the request is malformed:

**Case 1: Missing samples field**
```bash
curl -X POST http://localhost:8000/steps \
  -H "Content-Type: application/json" \
  -d '{}'
```

**Response:**
```json
{
  "error": "Invalid request body. Expected {\"samples\": [...]}"
}
```

**Case 2: samples is not a list**
```bash
curl -X POST http://localhost:8000/steps \
  -H "Content-Type: application/json" \
  -d '{"samples": "not a list"}'
```

**Response:**
```json
{
  "error": "samples must be a list"
}
```

**Case 3: Invalid JSON**
```bash
curl -X POST http://localhost:8000/steps \
  -H "Content-Type: application/json" \
  -d '{invalid json}'
```

**Response:**
```json
{
  "error": "Invalid JSON"
}
```

### 500 Internal Server Error

Returned when an unexpected server error occurs:

```json
{
  "error": "Server error: [error details]"
}
```

Common causes:
- File system permission issues
- Disk space full
- Corrupted JSONL file

---

## Troubleshooting

### POST request returns 400 error

**Symptom:** POST requests fail with:
```json
{
  "error": "Invalid request body. Expected {\"samples\": [...]}"
}
```

**Causes and Solutions:**

1. **Missing Content-Type header:**
   - Add `-H "Content-Type: application/json"` to your curl command

2. **Invalid JSON in request body:**
   - Validate your JSON syntax (use a JSON validator like jsonlint)
   - Ensure all strings are properly quoted

3. **Missing or incorrectly formatted samples field:**
   - Ensure the request has: `{"samples": [...]}`
   - The `samples` field must be an array, not an object

4. **Empty samples array:**
   - An empty array is valid: `{"samples": []}`
   - This will return `{"saved": 0, "message": "Success"}`

---

### GET /steps returns empty array

**Symptom:** After sending POST requests, GET /steps returns:
```json
{
  "samples": [],
  "total": 0
}
```

**Troubleshooting steps:**

1. **Verify the server is running:**
   ```bash
   curl http://localhost:8000/health
   ```
   Should return `{"status": "ok"}`

2. **Check if POST requests succeeded:**
   - POST requests should return status 200 with `"message": "Success"`
   - Check for any error responses

3. **Verify data directory exists:**
   ```bash
   ls -la api/data/
   ```
   The directory should exist. If not, restart the server (it creates it automatically).

4. **Check the JSONL file directly:**
   ```bash
   cat api/data/steps.jsonl
   ```
   Should contain one JSON object per line. If empty, no data has been stored.

5. **Verify file permissions:**
   - The `api/data/` directory and `steps.jsonl` file should be readable by your user
   - If permission denied, fix with: `chmod -R 755 api/data/`

---

### CORS errors when calling from web client

**Symptom:** Browser console shows CORS error:
```
Access to XMLHttpRequest has been blocked by CORS policy
```

**Solution:**
- The API server has CORS enabled by default (all origins allowed)
- Verify you're making requests to the correct URL: `http://localhost:8000`
- If behind a reverse proxy, ensure headers are passed through correctly

---

### Connection refused errors

**Symptom:** Requests fail with:
```
Connection refused
```

**Troubleshooting:**

1. **Verify server is running:**
   ```bash
   curl http://localhost:8000/health
   ```

2. **Check you're using the correct port:**
   - Default is `8000`
   - If modified, update all requests accordingly

3. **Check localhost resolution:**
   ```bash
   ping localhost
   ```

4. **Try using IP address instead:**
   ```bash
   curl http://127.0.0.1:8000/health
   ```

---

### Malformed data in steps.jsonl

**Symptom:** Some lines in `api/data/steps.jsonl` are not valid JSON

**Solution:**
- The API automatically skips malformed lines when reading
- The corrupted data won't be returned by GET /steps
- To clean up the file, create a new one by backing up and removing the old file:
  ```bash
  mv api/data/steps.jsonl api/data/steps.jsonl.backup
  # Restart server or manually POST valid data again
  ```

---

## API Assumptions

1. **Single user** - No authentication required
2. **Trusted network** - API runs locally, no HTTPS
3. **Step data only** - API is specifically designed for step count samples
4. **UTC timestamps** - All dates must be in ISO 8601 format with Z suffix (UTC)
5. **Data append-only** - Samples are never modified or deleted via API
6. **UUIDs are unique** - No validation of UUID uniqueness (client responsibility)
