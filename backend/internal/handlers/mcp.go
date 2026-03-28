package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/http/httptest"
	"strings"
	"time"

	"gorm.io/gorm"

	"github.com/lxRbckl/highlander/backend/internal/middleware"
)

// ---------- JSON-RPC 2.0 types (edge case 3: minimal custom parser) ----------

// jsonRPCRequest represents an incoming JSON-RPC 2.0 request.
type jsonRPCRequest struct {
	JSONRPC string           `json:"jsonrpc"`
	Method  string           `json:"method"`
	Params  *json.RawMessage `json:"params,omitempty"`
	ID      *json.RawMessage `json:"id"`
}

// jsonRPCResponse represents an outgoing JSON-RPC 2.0 response.
type jsonRPCResponse struct {
	JSONRPC string           `json:"jsonrpc"`
	Result  interface{}      `json:"result,omitempty"`
	Error   *jsonRPCError    `json:"error,omitempty"`
	ID      *json.RawMessage `json:"id"`
}

// jsonRPCError represents a JSON-RPC 2.0 error object.
type jsonRPCError struct {
	Code    int         `json:"code"`
	Message string      `json:"message"`
	Data    interface{} `json:"data,omitempty"`
}

// Standard JSON-RPC 2.0 error codes.
const (
	jsonRPCParseError     = -32700
	jsonRPCInvalidRequest = -32600
	jsonRPCMethodNotFound = -32601
	jsonRPCInvalidParams  = -32602
	jsonRPCInternalError  = -32603
)

// writeJSONRPCResult writes a successful JSON-RPC 2.0 response.
func writeJSONRPCResult(w http.ResponseWriter, id *json.RawMessage, result interface{}) {
	resp := jsonRPCResponse{
		JSONRPC: "2.0",
		Result:  result,
		ID:      id,
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

// writeJSONRPCError writes a JSON-RPC 2.0 error response with appropriate HTTP status.
// Edge case 9: all MCP errors use JSON-RPC envelope, never plain text.
func writeJSONRPCError(w http.ResponseWriter, id *json.RawMessage, code int, message string, httpStatus int) {
	resp := jsonRPCResponse{
		JSONRPC: "2.0",
		Error: &jsonRPCError{
			Code:    code,
			Message: message,
		},
		ID: id,
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(httpStatus)
	json.NewEncoder(w).Encode(resp)
}

// ---------- MCP tool schema types ----------

// mcpToolInputSchema describes the JSON schema for a tool's input parameters.
type mcpToolInputSchema struct {
	Type       string                       `json:"type"`
	Properties map[string]mcpPropertySchema `json:"properties,omitempty"`
	Required   []string                     `json:"required,omitempty"`
}

// mcpPropertySchema describes a single property in the tool input schema.
type mcpPropertySchema struct {
	Type        string   `json:"type"`
	Description string   `json:"description,omitempty"`
	Enum        []string `json:"enum,omitempty"`
}

// mcpTool is the MCP tool definition returned by tools/list.
type mcpTool struct {
	Name        string             `json:"name"`
	Description string             `json:"description"`
	InputSchema mcpToolInputSchema `json:"inputSchema"`
}

// ---------- initialize response ----------

type mcpServerInfo struct {
	Name    string `json:"name"`
	Version string `json:"version"`
}

type mcpInitializeResult struct {
	ProtocolVersion string                 `json:"protocolVersion"`
	ServerInfo      mcpServerInfo          `json:"serverInfo"`
	Capabilities    map[string]interface{} `json:"capabilities"`
}

// ---------- tools/call request params ----------

type toolCallParams struct {
	Name      string          `json:"name"`
	Arguments json.RawMessage `json:"arguments"`
}

// toolCallResult is the MCP result for a successful tools/call.
type toolCallResult struct {
	Content []toolCallContent `json:"content"`
	IsError bool              `json:"isError,omitempty"`
}

type toolCallContent struct {
	Type string `json:"type"`
	Text string `json:"text"`
}

// ---------- capability-to-tool mapping ----------

// capabilityToTool converts a Capability (from agent_capabilities.go) into
// an MCP tool definition with a proper JSON Schema for the input.
func capabilityToTool(cap Capability) mcpTool {
	tool := mcpTool{
		Name:        cap.Action,
		Description: cap.Description,
		InputSchema: mcpToolInputSchema{
			Type:       "object",
			Properties: make(map[string]mcpPropertySchema),
		},
	}

	// For capabilities that require path parameters (e.g., {id}), add them.
	if strings.Contains(cap.Path, "{id}") {
		tool.InputSchema.Properties["id"] = mcpPropertySchema{
			Type:        "string",
			Description: "Resource ID",
		}
		tool.InputSchema.Required = append(tool.InputSchema.Required, "id")
	}
	// Additional path params for nested resources.
	if strings.Contains(cap.Path, "{whyId}") {
		tool.InputSchema.Properties["whyId"] = mcpPropertySchema{
			Type:        "string",
			Description: "Five-why entry ID",
		}
		tool.InputSchema.Required = append(tool.InputSchema.Required, "whyId")
	}
	if strings.Contains(cap.Path, "{factorId}") {
		tool.InputSchema.Properties["factorId"] = mcpPropertySchema{
			Type:        "string",
			Description: "Contributing factor ID",
		}
		tool.InputSchema.Required = append(tool.InputSchema.Required, "factorId")
	}
	if strings.Contains(cap.Path, "{witnessId}") {
		tool.InputSchema.Properties["witnessId"] = mcpPropertySchema{
			Type:        "string",
			Description: "Witness statement ID",
		}
		tool.InputSchema.Required = append(tool.InputSchema.Required, "witnessId")
	}
	if strings.Contains(cap.Path, "{incidentId}") {
		tool.InputSchema.Properties["incidentId"] = mcpPropertySchema{
			Type:        "string",
			Description: "Incident ID",
		}
		tool.InputSchema.Required = append(tool.InputSchema.Required, "incidentId")
	}
	if strings.Contains(cap.Path, "{key}") {
		tool.InputSchema.Properties["key"] = mcpPropertySchema{
			Type:        "string",
			Description: "Setting key",
		}
		tool.InputSchema.Required = append(tool.InputSchema.Required, "key")
	}

	// Convert Parameters map to JSON Schema properties.
	if cap.Parameters != nil {
		for name, typeDesc := range cap.Parameters {
			prop := parseParamType(typeDesc)
			tool.InputSchema.Properties[name] = prop

			// Mark required fields.
			if strings.Contains(typeDesc, "(required") || strings.Contains(typeDesc, "required)") {
				tool.InputSchema.Required = append(tool.InputSchema.Required, name)
			}
		}
	}

	// For GET methods with query parameters, add common ones.
	if cap.Method == "GET" && cap.Action == "search" {
		// search has its own params already in Parameters map
	} else if cap.Method == "GET" && strings.Contains(cap.Path, "?") == false {
		// GET endpoints may accept query params like page, pageSize
		if cap.Action == "get_audit_logs" {
			// Already defined in Parameters
		}
	}

	return tool
}

// parseParamType converts a capability parameter type description into an
// mcpPropertySchema. Handles enum, type annotations, and descriptions.
func parseParamType(typeDesc string) mcpPropertySchema {
	prop := mcpPropertySchema{
		Description: typeDesc,
	}

	lower := strings.ToLower(typeDesc)

	// Detect type.
	switch {
	case strings.HasPrefix(lower, "bool"):
		prop.Type = "boolean"
	case strings.HasPrefix(lower, "uint") || strings.HasPrefix(lower, "int") || strings.HasPrefix(lower, "float"):
		prop.Type = "number"
	default:
		prop.Type = "string"
	}

	// Detect enum values.
	if idx := strings.Index(typeDesc, "enum ["); idx >= 0 {
		end := strings.Index(typeDesc[idx:], "]")
		if end > 0 {
			enumStr := typeDesc[idx+6 : idx+end]
			values := strings.Split(enumStr, ", ")
			for i := range values {
				values[i] = strings.TrimSpace(values[i])
			}
			prop.Enum = values
			prop.Type = "string"
		}
	}

	return prop
}

// ---------- tool execution: proxy to REST handlers ----------

// toolRouter stores the mapping from MCP tool names to REST handler dispatch
// info. Built once during RegisterMCPRoutes.
type toolRouter struct {
	db  *gorm.DB
	mux *http.ServeMux
}

// buildRESTPath converts an MCP tool name and arguments into the REST path,
// HTTP method, and request body for proxying.
func buildRESTPath(cap Capability, args map[string]interface{}) (method, path string, body map[string]interface{}, err error) {
	method = cap.Method
	path = cap.Path

	// Replace path parameters from arguments.
	body = make(map[string]interface{})
	for k, v := range args {
		placeholder := "{" + k + "}"
		if strings.Contains(path, placeholder) {
			path = strings.Replace(path, placeholder, fmt.Sprintf("%v", v), 1)
		} else {
			body[k] = v
		}
	}

	// For GET requests, convert body params to query string.
	if method == "GET" && len(body) > 0 {
		params := make([]string, 0, len(body))
		for k, v := range body {
			params = append(params, fmt.Sprintf("%s=%v", k, v))
		}
		path += "?" + strings.Join(params, "&")
		body = nil
	}

	return method, path, body, nil
}

// ---------- MCP handler ----------

// MCPHandler is the main JSON-RPC 2.0 handler for the /mcp/ endpoint.
// It dispatches to initialize, tools/list, and tools/call methods.
func MCPHandler(db *gorm.DB, restMux *http.ServeMux) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// Edge case 9: all responses must be JSON-RPC, never plain text.
		if r.Method != http.MethodPost {
			writeJSONRPCError(w, nil, jsonRPCInvalidRequest, "MCP endpoint accepts POST only", http.StatusMethodNotAllowed)
			return
		}

		// Parse JSON-RPC request.
		var req jsonRPCRequest
		decoder := json.NewDecoder(r.Body)
		if err := decoder.Decode(&req); err != nil {
			writeJSONRPCError(w, nil, jsonRPCParseError, "parse error: invalid JSON", http.StatusBadRequest)
			return
		}

		// Edge case 15: validate JSON before processing.
		if req.JSONRPC != "2.0" {
			writeJSONRPCError(w, req.ID, jsonRPCInvalidRequest, "invalid request: jsonrpc must be \"2.0\"", http.StatusBadRequest)
			return
		}

		if req.Method == "" {
			writeJSONRPCError(w, req.ID, jsonRPCInvalidRequest, "invalid request: method is required", http.StatusBadRequest)
			return
		}

		// Dispatch to method handlers.
		switch req.Method {
		case "initialize":
			handleInitialize(w, r, req)
		case "tools/list":
			handleToolsList(w, r, req)
		case "tools/call":
			handleToolsCall(w, r, req, db, restMux)
		case "notifications/list":
			// Edge case 2: WebSocket event namespacing — use mcp.* prefix.
			// Notifications are delivered via WebSocket, not polling.
			writeJSONRPCResult(w, req.ID, map[string]interface{}{
				"notifications": []interface{}{},
				"note":          "Real-time notifications are delivered via WebSocket with mcp.* event types",
			})
		default:
			writeJSONRPCError(w, req.ID, jsonRPCMethodNotFound, fmt.Sprintf("method not found: %s", req.Method), http.StatusNotFound)
		}
	}
}

// handleInitialize returns server info and capabilities.
// Edge case 13: returns protocolVersion "1.0".
func handleInitialize(w http.ResponseWriter, r *http.Request, req jsonRPCRequest) {
	// Edge case 13: check client protocol version if provided.
	if req.Params != nil {
		var params map[string]interface{}
		if err := json.Unmarshal(*req.Params, &params); err == nil {
			if clientVersion, ok := params["protocolVersion"].(string); ok {
				if clientVersion != "1.0" && clientVersion != "" {
					writeJSONRPCError(w, req.ID, jsonRPCInvalidRequest,
						fmt.Sprintf("unsupported protocol version: %s (server supports 1.0)", clientVersion),
						http.StatusBadRequest)
					return
				}
			}
		}
	}

	result := mcpInitializeResult{
		ProtocolVersion: "1.0",
		ServerInfo: mcpServerInfo{
			Name:    "SafeTrack",
			Version: "1.0",
		},
		Capabilities: map[string]interface{}{
			"tools": map[string]interface{}{
				"listChanged": false,
			},
			"notifications": map[string]interface{}{
				"transport": "websocket",
				"prefix":    "mcp.",
			},
		},
	}

	writeJSONRPCResult(w, req.ID, result)
}

// handleToolsList maps the authenticated user's capabilities to MCP tool
// definitions with JSON schemas. RBAC enforced: tools only listed if the
// agent's role permits them (edge case from build plan).
func handleToolsList(w http.ResponseWriter, r *http.Request, req jsonRPCRequest) {
	role := middleware.GetUserRole(r)

	var caps []Capability
	switch role {
	case "field_reporter":
		caps = fieldReporterCaps()
	case "safety_coordinator":
		caps = safetyCoordinatorCaps()
	case "safety_manager":
		caps = safetyManagerCaps()
	case "pm":
		caps = pmCaps()
	case "division_manager":
		caps = divisionManagerCaps()
	case "executive":
		caps = executiveCaps()
	case "admin":
		caps = adminCaps()
	default:
		caps = []Capability{}
	}

	// Edge case 19: photo upload via MCP — document limitation.
	// Filter out upload_photo since MCP uses JSON, not multipart/form-data.
	filtered := make([]Capability, 0, len(caps))
	for _, cap := range caps {
		if cap.Action == "upload_photo" {
			// Replace with documentation note about the limitation.
			continue
		}
		filtered = append(filtered, cap)
	}

	tools := make([]mcpTool, len(filtered))
	for i, cap := range filtered {
		tools[i] = capabilityToTool(cap)
	}

	result := map[string]interface{}{
		"tools": tools,
	}

	// Edge case 19: include a note about photo upload limitation.
	// Edge case 14: include API versioning note.
	result["_meta"] = map[string]interface{}{
		"photoUploadNote": "Photo upload requires multipart/form-data and is not available via MCP JSON-RPC. Use the REST API directly: POST /api/incidents/{id}/photos",
		"apiVersionNote":  "API endpoints are unversioned (/api/incidents, not /api/v1/incidents). MCP tool schemas must be regenerated when API fields change.",
		"protocolVersion": "1.0",
	}

	writeJSONRPCResult(w, req.ID, result)
}

// handleToolsCall executes a tool by proxying to the corresponding REST handler.
// Edge case 4: validates input before proxying.
// Edge case 10: 30s context timeout on tool execution.
// Edge case 11: idempotency key support via X-Idempotency-Key header.
func handleToolsCall(w http.ResponseWriter, r *http.Request, req jsonRPCRequest, db *gorm.DB, restMux *http.ServeMux) {
	if req.Params == nil {
		writeJSONRPCError(w, req.ID, jsonRPCInvalidParams, "invalid params: tools/call requires name and arguments", http.StatusBadRequest)
		return
	}

	var params toolCallParams
	if err := json.Unmarshal(*req.Params, &params); err != nil {
		writeJSONRPCError(w, req.ID, jsonRPCInvalidParams, "invalid params: "+err.Error(), http.StatusBadRequest)
		return
	}

	if params.Name == "" {
		writeJSONRPCError(w, req.ID, jsonRPCInvalidParams, "invalid params: tool name is required", http.StatusBadRequest)
		return
	}

	// Edge case 19: reject photo upload via MCP.
	if params.Name == "upload_photo" {
		writeJSONRPCError(w, req.ID, jsonRPCInvalidParams,
			"upload_photo is not available via MCP (requires multipart/form-data). Use REST API directly: POST /api/incidents/{id}/photos",
			http.StatusBadRequest)
		return
	}

	// Look up the capability matching this tool name for the user's role.
	role := middleware.GetUserRole(r)
	cap, found := findCapability(role, params.Name)
	if !found {
		writeJSONRPCError(w, req.ID, jsonRPCMethodNotFound,
			fmt.Sprintf("tool not found: %s (not available for role %s)", params.Name, role),
			http.StatusNotFound)
		return
	}

	// Parse arguments.
	var args map[string]interface{}
	if params.Arguments != nil && len(params.Arguments) > 0 {
		if err := json.Unmarshal(params.Arguments, &args); err != nil {
			writeJSONRPCError(w, req.ID, jsonRPCInvalidParams, "invalid arguments: "+err.Error(), http.StatusBadRequest)
			return
		}
	}
	if args == nil {
		args = make(map[string]interface{})
	}

	// Edge case 4: validate required parameters before proxying.
	tool := capabilityToTool(cap)
	for _, reqField := range tool.InputSchema.Required {
		// Skip path params that are set from the tool name context.
		if _, ok := args[reqField]; !ok {
			writeJSONRPCError(w, req.ID, jsonRPCInvalidParams,
				fmt.Sprintf("missing required parameter: %s", reqField),
				http.StatusBadRequest)
			return
		}
	}

	// Edge case 6: input sanitization — GORM handles SQL injection via
	// parameterized queries. Verify arguments are valid JSON types.
	if err := validateArguments(args); err != nil {
		writeJSONRPCError(w, req.ID, jsonRPCInvalidParams, "invalid arguments: "+err.Error(), http.StatusBadRequest)
		return
	}

	// Build REST request path and body.
	method, path, body, err := buildRESTPath(cap, args)
	if err != nil {
		writeJSONRPCError(w, req.ID, jsonRPCInternalError, "internal error: "+err.Error(), http.StatusInternalServerError)
		return
	}

	// Edge case 10: 30s context timeout on tool execution.
	ctx, cancel := context.WithTimeout(r.Context(), 30*time.Second)
	defer cancel()

	// Build the internal HTTP request.
	var bodyReader io.Reader
	if body != nil && len(body) > 0 {
		bodyBytes, err := json.Marshal(body)
		if err != nil {
			writeJSONRPCError(w, req.ID, jsonRPCInternalError, "internal error: failed to marshal body", http.StatusInternalServerError)
			return
		}
		bodyReader = bytes.NewReader(bodyBytes)
	}

	internalReq, err := http.NewRequestWithContext(ctx, method, path, bodyReader)
	if err != nil {
		writeJSONRPCError(w, req.ID, jsonRPCInternalError, "internal error: "+err.Error(), http.StatusInternalServerError)
		return
	}

	if body != nil {
		internalReq.Header.Set("Content-Type", "application/json")
	}

	// Edge case 11: pass through idempotency key if provided.
	if idempotencyKey := r.Header.Get("X-Idempotency-Key"); idempotencyKey != "" {
		internalReq.Header.Set("X-Idempotency-Key", idempotencyKey)
	}

	// Copy auth context from the original request — the REST handlers read
	// user identity from context values set by MCPAuth.
	internalReq = internalReq.WithContext(ctx)

	// Use httptest.ResponseRecorder to capture the REST response.
	recorder := httptest.NewRecorder()

	// Proxy to the REST mux.
	restMux.ServeHTTP(recorder, internalReq)

	// Edge case 9: convert HTTP response to JSON-RPC format.
	result := recorder.Result()
	defer result.Body.Close()

	respBody, err := io.ReadAll(result.Body)
	if err != nil {
		writeJSONRPCError(w, req.ID, jsonRPCInternalError, "internal error: failed to read response", http.StatusInternalServerError)
		return
	}

	// Check if the REST handler returned an error.
	if result.StatusCode >= 400 {
		// Edge case 9: wrap HTTP error in JSON-RPC error envelope.
		errorMsg := strings.TrimSpace(string(respBody))
		if errorMsg == "" {
			errorMsg = http.StatusText(result.StatusCode)
		}

		rpcCode := jsonRPCInternalError
		switch {
		case result.StatusCode == http.StatusBadRequest:
			rpcCode = jsonRPCInvalidParams
		case result.StatusCode == http.StatusUnauthorized:
			rpcCode = -32000
		case result.StatusCode == http.StatusForbidden:
			rpcCode = -32001
		case result.StatusCode == http.StatusNotFound:
			rpcCode = -32002
		case result.StatusCode == http.StatusConflict:
			rpcCode = -32003
		case result.StatusCode == http.StatusTooManyRequests:
			rpcCode = -32005
		}

		writeJSONRPCError(w, req.ID, rpcCode, errorMsg, result.StatusCode)
		return
	}

	// Try to parse response as JSON for structured output.
	var jsonResult interface{}
	if json.Valid(respBody) && len(respBody) > 0 {
		json.Unmarshal(respBody, &jsonResult)
	}

	// Return as MCP tool call result.
	if jsonResult != nil {
		callResult := toolCallResult{
			Content: []toolCallContent{
				{
					Type: "text",
					Text: string(respBody),
				},
			},
		}
		writeJSONRPCResult(w, req.ID, callResult)
	} else {
		// Non-JSON response (e.g., 204 No Content).
		callResult := toolCallResult{
			Content: []toolCallContent{
				{
					Type: "text",
					Text: func() string {
						if len(respBody) > 0 {
							return string(respBody)
						}
						return fmt.Sprintf("Success (HTTP %d)", result.StatusCode)
					}(),
				},
			},
		}
		writeJSONRPCResult(w, req.ID, callResult)
	}
}

// findCapability looks up a capability by tool name for the given role.
func findCapability(role, toolName string) (Capability, bool) {
	var caps []Capability
	switch role {
	case "field_reporter":
		caps = fieldReporterCaps()
	case "safety_coordinator":
		caps = safetyCoordinatorCaps()
	case "safety_manager":
		caps = safetyManagerCaps()
	case "pm":
		caps = pmCaps()
	case "division_manager":
		caps = divisionManagerCaps()
	case "executive":
		caps = executiveCaps()
	case "admin":
		caps = adminCaps()
	}

	for _, cap := range caps {
		if cap.Action == toolName {
			return cap, true
		}
	}
	return Capability{}, false
}

// validateArguments performs basic input sanitization on tool arguments.
// Edge case 6: GORM handles SQL injection via parameterized queries, but
// we validate argument types here to reject obviously malformed input.
func validateArguments(args map[string]interface{}) error {
	for key, val := range args {
		if val == nil {
			continue
		}
		// Reject nested objects deeper than 2 levels to prevent abuse.
		if m, ok := val.(map[string]interface{}); ok {
			for _, v := range m {
				if _, isMap := v.(map[string]interface{}); isMap {
					return fmt.Errorf("parameter %s: nested objects too deep (max 2 levels)", key)
				}
			}
		}
		// String values: reject excessively long strings (> 10KB).
		if s, ok := val.(string); ok {
			if len(s) > 10240 {
				return fmt.Errorf("parameter %s: value too long (max 10KB)", key)
			}
		}
	}
	return nil
}

// ---------- route registration ----------

// RegisterMCPRoutes wires up the /mcp/ endpoint on the top-level mux
// with MCPAuth middleware. This is called from main.go and uses the
// public mux (NOT the api mux behind FirebaseAuth).
//
// Edge case 1: route namespace — /mcp/* uses separate MCPAuth (API key).
// Edge case 8: CORS for MCP clients handled by the global CORS middleware
//
//	which now includes MCP-specific headers.
func RegisterMCPRoutes(mux *http.ServeMux, db *gorm.DB, restMux *http.ServeMux) {
	mcpMux := http.NewServeMux()
	mcpMux.HandleFunc("POST /mcp/", MCPHandler(db, restMux))

	// Wrap with MCPAuth middleware.
	mux.Handle("/mcp/", MCPAuth(db)(mcpMux))

	log.Println("[mcp] MCP server protocol registered at /mcp/")
}
