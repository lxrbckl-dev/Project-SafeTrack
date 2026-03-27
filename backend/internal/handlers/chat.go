package handlers

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"os"
)

type ChatRequest struct {
	Prompt string `json:"prompt"`
	System string `json:"system,omitempty"`
}

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

		ollamaReq, _ := json.Marshal(map[string]interface{}{
			"model":  "qwen2.5:7b",
			"prompt": req.Prompt,
			"system": req.System,
			"stream": false,
		})

		resp, err := http.Post(ollamaURL+"/api/generate", "application/json", bytes.NewReader(ollamaReq))
		if err != nil {
			http.Error(w, "ollama unavailable", http.StatusBadGateway)
			return
		}
		defer resp.Body.Close()

		w.Header().Set("Content-Type", "application/json")
		io.Copy(w, resp.Body)
	}
}
