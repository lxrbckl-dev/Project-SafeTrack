package handlers

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"regexp"
	"strings"
	"time"

	"gorm.io/gorm"

	"github.com/lxRbckl/highlander/backend/internal/middleware"
)

// ChatRequest is the JSON body sent by the Flutter client.
type ChatRequest struct {
	Prompt string `json:"prompt"`
	System string `json:"system,omitempty"`
}

// ChatAction represents a structured action the AI wants the client to execute.
type ChatAction struct {
	Action string            `json:"action"`
	Route  string            `json:"route,omitempty"`
	Fields map[string]string `json:"fields,omitempty"`
}

// ChatResponse is the structured response returned to the Flutter client.
// It always contains both a text response and an actions array (possibly empty).
type ChatResponse struct {
	Response string       `json:"response"`
	Actions  []ChatAction `json:"actions"`
}

// validActionTypes is the whitelist of action types the AI is allowed to return.
// Unknown types are logged and dropped (TASK-045 edge case #1).
var validActionTypes = map[string]bool{
	"navigate":          true,
	"fill":              true,
	"navigate_and_fill": true,
}

// roleRouteAccess defines which routes each role can access.
// Routes not listed are accessible to all authenticated roles.
// Key: route prefix. Value: map of allowed roles (true = allowed).
var roleRouteAccess = map[string]map[string]bool{
	"/investigations": {
		"safety_coordinator": true,
		"safety_manager":     true,
		"pm":                 true,
		"division_manager":   true,
		"executive":          true,
		"admin":              true,
	},
	"/capas": {
		"safety_coordinator": true,
		"safety_manager":     true,
		"pm":                 true,
		"division_manager":   true,
		"executive":          true,
		"admin":              true,
	},
	"/training": {
		"safety_coordinator": true,
		"safety_manager":     true,
		"pm":                 true,
		"division_manager":   true,
		"executive":          true,
		"admin":              true,
	},
	"/admin": {
		"safety_manager": true,
		"admin":          true,
	},
	"/audit-log": {
		"safety_manager": true,
		"admin":          true,
	},
}

// agentSystemPromptBase is the core system prompt for the AI chat.
// It is combined with role-specific route information at request time.
const agentSystemPromptBase = `You are an AI safety assistant for the Highlander Incident Investigation & Corrective Action System. You help users navigate the app and fill out forms.

IMPORTANT: You have TWO ways to help users take action:

## Method 1: Clickable Markdown URLs (PREFERRED for navigation with pre-filled data)
When the user describes an action that involves navigating to a page (optionally with pre-filled data), generate a clickable markdown URL in your response text. The Flutter app renders these as tappable links.

Format: [Descriptive action text](/route?param=value&param2=value2)

URL-encode special characters in query parameter values: spaces as +, ampersands as %26, etc.

Examples:
- "I need to report a near miss at Houston rail yard" → [Report Near Miss Incident](/incidents/new?type=Near+Miss&location=Houston+Rail+Yard)
- "Show me the CAPA dashboard" → [Open CAPA Dashboard](/capas)
- "I want to create a corrective action for investigation 5" → [Create Corrective Action](/capas/new?investigationId=5&type=Corrective)
- "Search for incidents at Building A" → [Search Building A Incidents](/search?q=Building+A)

## Method 2: JSON Action Blocks (for form filling on the current page)
When the user wants to fill form fields on the page they are already on (without navigation), include a JSON action block wrapped in triple backticks with the json language tag.

Available JSON actions:
1. Fill form fields on the current page:
` + "```json" + `
{"action": "fill", "fields": {"type": "Near Miss", "description": "Worker slipped on wet floor"}}
` + "```" + `

2. Navigate to a page AND fill form fields (complex multi-step):
` + "```json" + `
{"action": "navigate_and_fill", "route": "/incidents/new", "fields": {"type": "Injury", "location": "Building A"}}
` + "```" + `

3. Navigate to a page (simple, no pre-fill):
` + "```json" + `
{"action": "navigate", "route": "/incidents/new"}
` + "```" + `

Valid action types are ONLY: navigate, fill, navigate_and_fill. Do not invent other action types.

Valid incident form fields: type (Injury, Near Miss, Property Damage, Environmental, Vehicle, Fire, Utility Strike), location, division, project, description, immediateActions, severity (Fatality, Lost Time, Medical Treatment, First Aid, Near Miss), potentialSeverity, shift (Day, Night, Swing), weather (Clear, Cloudy, Rain, Snow, Ice, Fog, Wind, Extreme Heat, Extreme Cold)

Valid investigation form fields: leadInvestigator, teamMembers

Valid CAPA form fields: type (Corrective, Preventive), category (Training, Procedure Change, Engineering Control, PPE, Equipment Modification, Policy Change, Other), description, assignedTo, priority (Critical, High, Medium, Low), verificationMethod

Always include a helpful text explanation alongside any URLs or action blocks. If the user just asks a question (not requesting navigation or form filling), respond with text only — no URLs or action blocks needed.`

// buildRouteList returns the list of routes the given role can access,
// formatted for inclusion in the system prompt.
func buildRouteList(role string) string {
	type routeInfo struct {
		path        string
		description string
		queryParams string
	}

	allRoutes := []routeInfo{
		{"/dashboard", "Safety Dashboard", ""},
		{"/dashboard/hours-worked", "Hours Worked Entry", ""},
		{"/incidents", "Incident List", ""},
		{"/incidents/new", "Create New Incident", "?type=...&location=...&division=...&project=...&severity=...&shift=...&weather=..."},
		{"/incidents/map", "Incident Map View", ""},
		{"/incidents/clusters", "Incident Clusters", ""},
		{"/incidents/:id", "Incident Detail (replace :id with number)", ""},
		{"/incidents/:id/edit", "Edit Incident", ""},
		{"/incidents/:id/osha", "OSHA Determination", ""},
		{"/investigations", "Investigation List", ""},
		{"/investigations/new", "Create New Investigation", "?incidentId=N"},
		{"/investigations/:id", "Investigation Detail (replace :id with number)", ""},
		{"/capas", "CAPA Dashboard", ""},
		{"/capas/new", "Create New CAPA", "?investigationId=N&type=...&priority=..."},
		{"/capas/:id", "CAPA Detail (replace :id with number)", ""},
		{"/training", "Training List", ""},
		{"/training/:id", "Training Detail (replace :id with number)", ""},
		{"/admin", "Admin Settings", ""},
		{"/admin/factor-types", "Factor Types Configuration", ""},
		{"/admin/osha-export", "OSHA Log Export", ""},
		{"/audit-log", "Audit Log", ""},
		{"/search", "Global Search", "?q=search+terms"},
		{"/notification-preferences", "Notification Preferences", ""},
		{"/activity", "Activity Feed", ""},
	}

	var sb strings.Builder
	sb.WriteString("Routes available to you:\n")

	for _, r := range allRoutes {
		// Check if this route is role-restricted.
		allowed := true
		for prefix, roles := range roleRouteAccess {
			if strings.HasPrefix(r.path, prefix) {
				if !roles[role] {
					allowed = false
				}
				break
			}
		}
		if !allowed {
			continue
		}

		sb.WriteString(fmt.Sprintf("- %s — %s", r.path, r.description))
		if r.queryParams != "" {
			sb.WriteString(fmt.Sprintf(" (query params: %s)", r.queryParams))
		}
		sb.WriteString("\n")
	}

	return sb.String()
}

// jsonBlockRe matches fenced code blocks with json language tag.
var jsonBlockRe = regexp.MustCompile("(?s)```json\\s*\\n?(.*?)\\n?```")

// ollamaOfflineMessage is the user-visible text returned when Ollama is
// unavailable for any reason. It is shared with the Flutter client constant so
// both sides can recognise system/offline messages.
const ollamaOfflineMessage = "The AI assistant is currently offline. Please try again later."

// writeOfflineResponse writes a graceful HTTP 200 JSON response that the
// Flutter client renders as a system/offline message. Using 200 (not 502)
// ensures the Flutter ChatRepository treats it as a success and displays
// the text in the chat bubble with offline styling rather than an error banner.
func writeOfflineResponse(w http.ResponseWriter) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(ChatResponse{
		Response: ollamaOfflineMessage,
		Actions:  []ChatAction{},
	})
}

// Chat returns an HTTP handler that proxies user prompts to Ollama (Qwen 2.5 7B)
// and parses the response for structured action blocks.
//
// The handler injects a system prompt that teaches Qwen both the JSON action
// dispatch schema and the markdown URL generation format. The prompt is
// role-aware: it only includes routes the user's role can access (TASK-045).
//
// Response format:
//
//	{"response": "I'll help you...", "actions": [{"action": "navigate", "route": "/incidents/new"}]}
//
// If no actions are detected the actions array is empty.
// Markdown URLs in the response text are preserved for the Flutter client to
// detect and render as clickable links.
func Chat(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ollamaURL := os.Getenv("OLLAMA_URL")
		if ollamaURL == "" {
			ollamaURL = "http://localhost:11434"
		}

		var req ChatRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "invalid request body", http.StatusBadRequest)
			return
		}

		// Read the authenticated user's role from JWT context (set by auth middleware).
		userRole := middleware.GetUserRole(r)
		if userRole == "" {
			userRole = "field_reporter" // safe default: lowest privilege
		}

		// Build the system prompt: base instructions + role-specific route list.
		roleRoutes := buildRouteList(userRole)
		systemPrompt := agentSystemPromptBase + "\n\n" +
			fmt.Sprintf("The current user's role is: %s\n\n", userRole) +
			roleRoutes + "\n" +
			"IMPORTANT: Only generate URLs and actions for routes listed above. " +
			"Do NOT generate URLs for routes the user cannot access."

		if req.System != "" {
			systemPrompt = systemPrompt + "\n\n" + req.System
		}

		ollamaReq, _ := json.Marshal(map[string]interface{}{
			"model":  "qwen2.5:7b",
			"prompt": req.Prompt,
			"system": systemPrompt,
			"stream": false,
		})

		chatClient := &http.Client{Timeout: 90 * time.Second}
		resp, err := chatClient.Post(ollamaURL+"/api/generate", "application/json", bytes.NewReader(ollamaReq))
		if err != nil {
			// Edge case #8: never log API key material. Only log the error type.
			log.Printf("[chat] ollama connection failed: %v", err)
			writeOfflineResponse(w)
			return
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			log.Printf("[chat] ollama returned non-200 status: %d", resp.StatusCode)
			writeOfflineResponse(w)
			return
		}

		body, err := io.ReadAll(resp.Body)
		if err != nil {
			log.Printf("[chat] failed to read ollama response body")
			writeOfflineResponse(w)
			return
		}

		if len(bytes.TrimSpace(body)) == 0 {
			log.Printf("[chat] ollama returned empty response body")
			writeOfflineResponse(w)
			return
		}

		// Parse the Ollama response to extract the text.
		var ollamaResp map[string]interface{}
		if err := json.Unmarshal(body, &ollamaResp); err != nil {
			log.Printf("[chat] failed to decode ollama JSON response")
			writeOfflineResponse(w)
			return
		}

		rawText, _ := ollamaResp["response"].(string)
		rawText = strings.TrimSpace(rawText)

		if rawText == "" {
			log.Printf("[chat] ollama returned empty response text")
			writeOfflineResponse(w)
			return
		}

		// Extract JSON action blocks from the response text.
		actions := parseActions(rawText)

		// Strip the JSON code blocks from the text response so the user sees
		// only the natural-language part. Markdown URLs are preserved in the
		// text for the Flutter client to render as clickable links.
		cleanText := jsonBlockRe.ReplaceAllString(rawText, "")
		cleanText = strings.TrimSpace(cleanText)

		// Build the structured response.
		chatResp := ChatResponse{
			Response: cleanText,
			Actions:  actions,
		}

		// Edge case 12: audit log chat requests so agent usage is visible.
		userID := middleware.GetUserID(r)
		_ = userRole // already declared above for route list
		isAgent := middleware.GetIsAgent(r)
		if db != nil {
			// Truncate prompt for audit log (avoid storing large payloads).
			promptSnippet := req.Prompt
			if len(promptSnippet) > 200 {
				promptSnippet = promptSnippet[:200] + "..."
			}
			LogAction(db, userID, userRole, "chat_request", "chat", 0, "",
				toJSON(map[string]interface{}{"promptLength": len(req.Prompt), "actionsCount": len(actions)}),
				promptSnippet, isAgent)
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(chatResp)
	}
}

// parseActions extracts ChatAction objects from fenced ```json blocks in the
// AI response text.  If no fenced blocks are found, it attempts to detect
// bare JSON objects that look like valid actions.
//
// TASK-045 edge case #1: only whitelisted action types are accepted.
// Unknown action types are logged and dropped.
func parseActions(text string) []ChatAction {
	var actions []ChatAction

	// First try: fenced code blocks.
	matches := jsonBlockRe.FindAllStringSubmatch(text, -1)
	for _, match := range matches {
		if len(match) < 2 {
			continue
		}
		raw := strings.TrimSpace(match[1])
		var action ChatAction
		if err := json.Unmarshal([]byte(raw), &action); err == nil && action.Action != "" {
			if validActionTypes[action.Action] {
				actions = append(actions, action)
			} else {
				// Edge case #1: log unknown action types so they can be investigated.
				log.Printf("[chat] unknown action type dropped: %q", action.Action)
			}
		}
	}

	if len(actions) > 0 {
		return actions
	}

	// Fallback: look for bare JSON objects with an "action" key.
	// This handles cases where Qwen forgets the fences.
	idx := 0
	for idx < len(text) {
		start := strings.Index(text[idx:], "{")
		if start == -1 {
			break
		}
		start += idx
		// Find the matching closing brace.
		// Track whether we're inside a JSON string so that braces within
		// string values are not counted toward the depth.
		depth := 0
		end := -1
		inString := false
		for i := start; i < len(text); i++ {
			ch := text[i]
			if ch == '"' && (i == 0 || text[i-1] != '\\') {
				inString = !inString
				continue
			}
			if inString {
				continue
			}
			if ch == '{' {
				depth++
			} else if ch == '}' {
				depth--
				if depth == 0 {
					end = i + 1
					break
				}
			}
		}
		if end <= start {
			break
		}
		candidate := text[start:end]
		var action ChatAction
		if err := json.Unmarshal([]byte(candidate), &action); err == nil && action.Action != "" {
			if validActionTypes[action.Action] {
				actions = append(actions, action)
			} else {
				log.Printf("[chat] unknown action type dropped: %q", action.Action)
			}
		}
		idx = end
	}

	return actions
}
