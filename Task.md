# **iOS Health steps sync**

## **Take-home assignment:**

Build a small iOS app that reads **raw step count data** from Apple Health and syncs it to a **mock API** you run locally.

### **Requirements**

- Read **raw step samples** (not aggregated data)
- Sync **all available history** (assume up to ~10 years back)
- Send the data to a locally running API written in a language of your choice
- The API should persist the received data to a **.jsonl file**
- Sync should be done in a way that is reasonably safe for large data volumes

### **Notes**

- The API must be reachable from the app (you may use tools like **ngrok** to expose a local server to a physical device if needed)
- You are free to make assumptions that **limit scope or simplify the solution**, as long as they are clearly documented
- AI Usage in coding and planning is welcomed

### **Deliverables**

- iOS app source code + Mock API source code, same github repo for simplicity.
- Short README explaining how to run both and listing assumptions made
