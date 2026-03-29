# MCP Server Guide — SafeTrack Agent Integration

> Connect any AI agent to SafeTrack's safety data in under 5 minutes.

---

## Overview

SafeTrack exposes a **Model Context Protocol (MCP)** server that lets AI agents programmatically interact with safety data — create incidents, run investigations, manage CAPAs, pull dashboard metrics, and more.

| Property | Value |
|---|---|
| Protocol | JSON-RPC 2.0 over HTTP POST |
| Endpoint | `POST /mcp/` |
| Auth | Bearer token with `stk_`-prefixed API key |
| Rate limit | 60 requests/minute per key |
| Request size | 1MB max |
| Methods | `initialize`, `tools/list`, `tools/call` |

---

## Quick Start (60 seconds)

### Option A: Use the pre-seeded demo key (fastest)

A demo API key is seeded automatically when the app starts:

```
stk_demo_judge_key_2026
```

This key has **admin** access (all tools available). Skip to [Connecting Your Agent](#connecting-your-agent).

### Option B: Create your own key

1. Log in as admin (`admin@safetrack.demo` / `demo1234`)
2. Navigate to **Admin → API Keys**
3. Click **Create Key**, name it (e.g. "My Agent")
4. Copy the key (shown once — starts with `stk_`)

---

## Connecting Your Agent

### Verify the server is running

```bash
curl -X POST http://localhost:8000/mcp/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer stk_demo_judge_key_2026" \
  -d '{"jsonrpc":"2.0","method":"initialize","id":1}'
```

Expected response:
```json
{
  "jsonrpc": "2.0",
  "result": {
    "protocolVersion": "1.0",
    "serverInfo": {"name": "SafeTrack", "version": "1.0"},
    "capabilities": {"tools": {"listChanged": false}}
  },
  "id": 1
}
```

### Claude Code (`.mcp.json`)

Create `.mcp.json` in your project directory:

```json
{
  "mcpServers": {
    "safetrack": {
      "type": "url",
      "url": "http://localhost:8000/mcp/",
      "headers": {
        "Authorization": "Bearer stk_demo_judge_key_2026"
      }
    }
  }
}
```

### Claude Desktop (`claude_desktop_config.json`)

Claude Desktop uses stdio-based MCP servers. For HTTP-based servers like SafeTrack, use a bridge script:

```json
{
  "mcpServers": {
    "safetrack": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "http://localhost:8000/mcp/"],
      "env": {
        "MCP_AUTH_HEADER": "Bearer stk_demo_judge_key_2026"
      }
    }
  }
}
```

### curl (any HTTP-capable agent)

**List available tools:**
```bash
curl -X POST http://localhost:8000/mcp/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer stk_demo_judge_key_2026" \
  -d '{"jsonrpc":"2.0","method":"tools/list","id":2}'
```

**Call a tool:**
```bash
curl -X POST http://localhost:8000/mcp/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer stk_demo_judge_key_2026" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "list_incidents",
      "arguments": {}
    },
    "id": 3
  }'
```

### Python (minimal example)

```python
import json, urllib.request

MCP_URL = "http://localhost:8000/mcp/"
API_KEY = "stk_demo_judge_key_2026"

def mcp_call(method, params=None):
    body = {"jsonrpc": "2.0", "method": method, "id": 1}
    if params:
        body["params"] = params
    req = urllib.request.Request(MCP_URL,
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json",
                 "Authorization": f"Bearer {API_KEY}"})
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read())

# Initialize
print(mcp_call("initialize"))

# List available tools
tools = mcp_call("tools/list")
print(f"{len(tools['result']['tools'])} tools available")

# List incidents
incidents = mcp_call("tools/call", {
    "name": "list_incidents",
    "arguments": {}
})
print(incidents["result"]["content"][0]["text"][:200])
```

---

## Available Tools by Role

### Admin (full access — 40+ tools)

The admin role inherits everything from safety_manager plus audit logs. The pre-seeded demo key (`stk_demo_judge_key_2026`) has admin access.

### Tool Reference

#### Incident Management

| Tool | Method | Description | Roles |
|---|---|---|---|
| `create_incident` | POST | Create a new incident report | field_reporter+ |
| `list_incidents` | GET | List incidents (RBAC-scoped) | All roles |
| `get_incident` | GET | Get incident by ID | All roles |
| `update_incident` | PUT | Update an incident report | field_reporter+ |
| `upload_photo` | POST | Attach photo (REST only, not via MCP) | field_reporter+ |
| `get_incident_timeline` | GET | Lifecycle timeline for an incident | coordinator+ |
| `get_incident_links` | GET | Get recurrence links for an incident | All roles |
| `create_incident_link` | POST | Link two related incidents | coordinator+ |
| `delete_incident_link` | DELETE | Remove an incident link | coordinator+ |
| `get_incident_clusters` | GET | Get grouped recurrence clusters | All roles |

**`create_incident` parameters:**

| Parameter | Type | Required | Values |
|---|---|---|---|
| `type` | string | yes | Injury, Near Miss, Property Damage, Environmental, Vehicle, Fire, Utility Strike |
| `date` | string | yes | RFC3339 format |
| `location` | string | yes | |
| `division` | string | no | |
| `projectJobSite` | string | no | |
| `description` | string | yes | |
| `severity` | string | no | Fatality, Lost Time, Medical Treatment, First Aid, Near Miss |
| `potentialSeverity` | string | no | Same enum as severity |
| `immediateActions` | string | no | |
| `shift` | string | no | Day, Night, Swing |
| `weather` | string | no | |
| `isDraft` | bool | no | true = draft (visible only to reporter) |

#### Investigation Management

| Tool | Method | Description | Roles |
|---|---|---|---|
| `create_investigation` | POST | Create investigation for an incident | safety_manager+ |
| `list_investigations` | GET | List investigations (RBAC-scoped) | coordinator+ |
| `get_investigation` | GET | Get investigation by ID | coordinator+ |
| `update_investigation` | PUT | Update investigation details | coordinator+ |
| `submit_investigation_for_review` | POST | Submit for Safety Manager review | coordinator+ |
| `approve_investigation` | POST | Approve or return an investigation | safety_manager+ |
| `create_five_why` | POST | Add/update a 5-Why root cause entry | coordinator+ |
| `delete_five_why` | DELETE | Remove a 5-Why entry | coordinator+ |
| `create_contributing_factor` | POST | Add a contributing factor | coordinator+ |
| `delete_contributing_factor` | DELETE | Remove a contributing factor | coordinator+ |
| `create_witness_statement` | POST | Record a witness statement | coordinator+ |
| `update_witness_statement` | PUT | Edit a witness statement | coordinator+ |

#### CAPA Management

| Tool | Method | Description | Roles |
|---|---|---|---|
| `create_capa` | POST | Create a corrective/preventive action | coordinator+ |
| `list_capas` | GET | List CAPAs (RBAC-scoped) | coordinator+ |
| `get_capa` | GET | Get CAPA by ID | coordinator+ |
| `update_capa` | PUT | Update a CAPA | coordinator+ |
| `complete_capa` | POST | Mark CAPA as completed | coordinator+ |
| `verify_capa` | POST | Verify CAPA effectiveness (verifier != assignee) | coordinator+ |
| `get_capa_dashboard` | GET | CAPA summary KPIs | coordinator+ |

#### Training

| Tool | Method | Description | Roles |
|---|---|---|---|
| `create_training` | POST | Create training requirement (linked to Training CAPA) | coordinator+ |
| `list_training` | GET | List training requirements | coordinator+ |
| `get_training` | GET | Get training by ID | coordinator+ |
| `complete_training` | POST | Mark training completed | coordinator+ |

#### Dashboard & Analytics

| Tool | Method | Description | Roles |
|---|---|---|---|
| `get_dashboard` | GET | TRIR, DART, trends, leading indicators | pm+ |
| `create_hours_worked` | POST | Submit hours for TRIR/DART calculation | safety_manager+ |
| `list_hours_worked` | GET | List hours-worked records | executive+ |
| `search` | GET | Cross-entity search (RBAC-scoped) | All roles |
| `get_activity` | GET | Live activity feed | All roles |

#### OSHA Compliance

| Tool | Method | Description | Roles |
|---|---|---|---|
| `get_osha_300` | GET | Export OSHA Form 300 log | safety_manager+ |
| `get_osha_300a` | GET | Export OSHA Form 300A summary | safety_manager+ |
| `get_osha_301` | GET | Export OSHA Form 301 per incident | safety_manager+ |

#### Admin

| Tool | Method | Description | Roles |
|---|---|---|---|
| `list_settings` | GET | List system settings | safety_manager+ |
| `get_setting` | GET | Get a setting value | safety_manager+ |
| `update_setting` | PUT | Update a setting | safety_manager+ |
| `create_agent_key` | POST | Generate a new API key | safety_manager+ |
| `list_agent_keys` | GET | List active API keys | safety_manager+ |
| `revoke_agent_key` | DELETE | Revoke an API key | safety_manager+ |
| `get_audit_logs` | GET | Query immutable audit trail | admin only |

---

## Example Workflows

### Scenario A: Report and investigate an incident

```bash
# 1. Create a near-miss incident
curl -X POST http://localhost:8000/mcp/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer stk_demo_judge_key_2026" \
  -d '{
    "jsonrpc": "2.0", "method": "tools/call", "id": 1,
    "params": {
      "name": "create_incident",
      "arguments": {
        "type": "Near Miss",
        "date": "2026-03-29T10:00:00Z",
        "location": "Building A, Floor 2",
        "description": "Unsecured scaffolding nearly fell on workers below",
        "severity": "First Aid",
        "potentialSeverity": "Lost Time",
        "shift": "Day"
      }
    }
  }'

# 2. Create an investigation (note the incident ID from step 1)
curl -X POST http://localhost:8000/mcp/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer stk_demo_judge_key_2026" \
  -d '{
    "jsonrpc": "2.0", "method": "tools/call", "id": 2,
    "params": {
      "name": "create_investigation",
      "arguments": {
        "incidentId": 111,
        "leadInvestigatorId": "2"
      }
    }
  }'

# 3. Add root cause analysis (5-Why)
curl -X POST http://localhost:8000/mcp/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer stk_demo_judge_key_2026" \
  -d '{
    "jsonrpc": "2.0", "method": "tools/call", "id": 3,
    "params": {
      "name": "create_five_why",
      "arguments": {
        "id": 46,
        "level": 1,
        "question": "Why was the scaffolding unsecured?",
        "answer": "Locking pins were not installed after last repositioning"
      }
    }
  }'

# 4. Add a contributing factor
curl -X POST http://localhost:8000/mcp/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer stk_demo_judge_key_2026" \
  -d '{
    "jsonrpc": "2.0", "method": "tools/call", "id": 4,
    "params": {
      "name": "create_contributing_factor",
      "arguments": {
        "id": 46,
        "factorType": "Procedural",
        "description": "No checklist for scaffolding repositioning sign-off"
      }
    }
  }'

# 5. Create a corrective action
curl -X POST http://localhost:8000/mcp/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer stk_demo_judge_key_2026" \
  -d '{
    "jsonrpc": "2.0", "method": "tools/call", "id": 5,
    "params": {
      "name": "create_capa",
      "arguments": {
        "investigationId": 46,
        "title": "Create scaffolding repositioning checklist",
        "category": "Procedure Change",
        "priority": "High",
        "description": "Develop and implement a mandatory checklist for scaffolding repositioning that includes pin verification"
      }
    }
  }'
```

### Scenario B: Executive safety briefing

```bash
# Pull dashboard KPIs
curl -X POST http://localhost:8000/mcp/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer stk_demo_judge_key_2026" \
  -d '{"jsonrpc":"2.0","method":"tools/call","id":1,
    "params":{"name":"get_dashboard","arguments":{}}}'

# Search for specific incidents
curl -X POST http://localhost:8000/mcp/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer stk_demo_judge_key_2026" \
  -d '{"jsonrpc":"2.0","method":"tools/call","id":2,
    "params":{"name":"search","arguments":{"q":"scaffolding"}}}'

# Check recurrence patterns
curl -X POST http://localhost:8000/mcp/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer stk_demo_judge_key_2026" \
  -d '{"jsonrpc":"2.0","method":"tools/call","id":3,
    "params":{"name":"get_incident_clusters","arguments":{}}}'
```

### Scenario C: Audit trail review

```bash
# Pull recent audit entries
curl -X POST http://localhost:8000/mcp/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer stk_demo_judge_key_2026" \
  -d '{"jsonrpc":"2.0","method":"tools/call","id":1,
    "params":{"name":"get_audit_logs","arguments":{"pageSize":"10"}}}'

# Trace an incident's full lifecycle
curl -X POST http://localhost:8000/mcp/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer stk_demo_judge_key_2026" \
  -d '{"jsonrpc":"2.0","method":"tools/call","id":2,
    "params":{"name":"get_incident_timeline","arguments":{"id":"1"}}}'
```

---

## Error Handling

The MCP server returns standard JSON-RPC 2.0 error responses:

| Code | Meaning | Common Cause |
|---|---|---|
| `-32700` | Parse error | Invalid JSON in request body |
| `-32600` | Invalid request | Missing `jsonrpc: "2.0"` or empty method |
| `-32601` | Method not found | Unknown method or tool name not available for your role |
| `-32602` | Invalid params | Missing required parameters |
| `-32603` | Internal error | Server-side failure |
| `-32000` | Unauthorized | Bad or missing API key |
| `-32001` | Forbidden | Role doesn't have access to this tool |
| `-32002` | Not found | Resource doesn't exist |
| `-32003` | Conflict | Duplicate or state conflict |
| `-32005` | Rate limited | Exceeded 60 requests/minute |

**Example error response:**
```json
{
  "jsonrpc": "2.0",
  "error": {
    "code": -32001,
    "message": "tool not found: create_investigation (not available for role field_reporter)"
  },
  "id": 1
}
```

---

## Security Notes

- API keys are **bcrypt-hashed** server-side — never stored in plaintext
- The full key is shown **exactly once** at creation — copy it immediately
- Keys inherit the creating user's **RBAC role** — a field_reporter key cannot access admin tools
- Rate limited to **60 requests/minute** per key
- Request bodies capped at **1MB**
- **Photo upload** is NOT available via MCP (requires multipart/form-data) — use the REST API directly: `POST /api/incidents/{id}/photos`
- All tool calls are **audit-logged** with the agent's identity

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `"unauthorized: missing or invalid Authorization header"` | Check your `Authorization: Bearer stk_...` header. Key must start with `stk_` |
| `"tool not found: X (not available for role Y)"` | Your key's role doesn't have access to this tool. Check the role table above |
| Empty `tools` array from `tools/list` | The key's associated user may have an unrecognized role. Verify with `GET /api/agent/capabilities` |
| Connection refused | Ensure the Go backend is running on port 8000: `curl http://localhost:8000/health` |
| Rate limited (`-32005`) | Wait 60 seconds or use a different key |
| `"upload_photo is not available via MCP"` | Photo upload requires multipart/form-data. Use the REST API directly |
| Need to revoke a key | Admin → API Keys → click revoke, or use `tools/call` with `revoke_agent_key` |
