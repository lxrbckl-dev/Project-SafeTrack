package handlers

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"os"
	"regexp"
	"strings"
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

// agentSystemPrompt tells Qwen it can return JSON action blocks for in-app
// navigation and form filling.  The prompt is prepended to any user-supplied
// system prompt.
const agentSystemPrompt = `You are an AI safety assistant for the Highlander Incident Investigation & Corrective Action System. You help users navigate the app and fill out forms.

When the user asks you to navigate somewhere or fill a form, you MUST include a JSON action block in your response. The JSON block must be wrapped in triple backticks with the json language tag.

Available actions:
1. Navigate to a page:
` + "```json" + `
{"action": "navigate", "route": "/incidents/new"}
` + "```" + `

2. Fill form fields on the current page:
` + "```json" + `
{"action": "fill", "fields": {"type": "Near Miss", "description": "Worker slipped on wet floor"}}
` + "```" + `

3. Navigate to a page AND fill form fields:
` + "```json" + `
{"action": "navigate_and_fill", "route": "/incidents/new", "fields": {"type": "Injury", "location": "Building A"}}
` + "```" + `

Valid routes:
- /dashboard — Safety Dashboard
- /incidents — Incident list
- /incidents/new — Create new incident
- /investigations — Investigation list
- /investigations/new — Create new investigation (add ?incidentId=N)
- /capas — CAPA dashboard
- /capas/new — Create new CAPA (add ?investigationId=N)
- /admin — Admin settings
- /audit-log — Audit log

Valid incident form fields: type (Injury, Near Miss, Property Damage, Environmental, Vehicle, Fire, Utility Strike), location, division, project, description, immediateActions, severity (Fatality, Lost Time, Medical Treatment, First Aid, Near Miss), potentialSeverity, shift (Day, Night, Swing), weather (Clear, Cloudy, Rain, Snow, Ice, Fog, Wind, Extreme Heat, Extreme Cold)

Valid investigation form fields: leadInvestigator, teamMembers

Valid CAPA form fields: type (Corrective, Preventive), category (Training, Procedure Change, Engineering Control, PPE, Equipment Modification, Policy Change, Other), description, assignedTo, priority (Critical, High, Medium, Low), verificationMethod

Always include a helpful text explanation alongside any action blocks. If the user just asks a question (not requesting navigation or form filling), respond with text only — no action blocks needed.`

// jsonBlockRe matches fenced code blocks with json language tag.
var jsonBlockRe = regexp.MustCompile("(?s)```json\\s*\\n?(.*?)\\n?```")

// Chat returns an HTTP handler that proxies user prompts to Ollama (Qwen 2.5 7B)
// and parses the response for structured action blocks.
//
// The handler injects a system prompt that teaches Qwen the JSON action dispatch
// schema so it can return navigation and form-fill instructions alongside its
// text response.
//
// Response format:
//
//	{"response": "I'll help you...", "actions": [{"action": "navigate", "route": "/incidents/new"}]}
//
// If no actions are detected the actions array is empty.
func Chat() http.HandlerFunc {
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

		// Build the system prompt: agent instructions + any user-supplied system text.
		systemPrompt := agentSystemPrompt
		if req.System != "" {
			systemPrompt = agentSystemPrompt + "\n\n" + req.System
		}

		ollamaReq, _ := json.Marshal(map[string]interface{}{
			"model":  "qwen2.5:7b",
			"prompt": req.Prompt,
			"system": systemPrompt,
			"stream": false,
		})

		resp, err := http.Post(ollamaURL+"/api/generate", "application/json", bytes.NewReader(ollamaReq))
		if err != nil {
			http.Error(w, "ollama unavailable", http.StatusBadGateway)
			return
		}
		defer resp.Body.Close()

		body, err := io.ReadAll(resp.Body)
		if err != nil {
			http.Error(w, "failed to read ollama response", http.StatusBadGateway)
			return
		}

		// Parse the Ollama response to extract the text.
		var ollamaResp map[string]interface{}
		if err := json.Unmarshal(body, &ollamaResp); err != nil {
			// If we can't parse, return the raw body as-is for graceful degradation.
			w.Header().Set("Content-Type", "application/json")
			w.Write(body)
			return
		}

		rawText, _ := ollamaResp["response"].(string)
		rawText = strings.TrimSpace(rawText)

		// Extract JSON action blocks from the response text.
		actions := parseActions(rawText)

		// Strip the JSON code blocks from the text response so the user sees
		// only the natural-language part.
		cleanText := jsonBlockRe.ReplaceAllString(rawText, "")
		cleanText = strings.TrimSpace(cleanText)

		// Build the structured response.
		chatResp := ChatResponse{
			Response: cleanText,
			Actions:  actions,
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(chatResp)
	}
}

// parseActions extracts ChatAction objects from fenced ```json blocks in the
// AI response text.  If no fenced blocks are found, it attempts to detect
// bare JSON objects that look like valid actions.
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
			actions = append(actions, action)
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
			actions = append(actions, action)
		}
		idx = end
	}

	return actions
}
