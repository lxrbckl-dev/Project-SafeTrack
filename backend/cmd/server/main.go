package main

import (
	"log"
	"net/http"
	"os"

	"github.com/lxRbckl/highlander/backend/internal/database"
	"github.com/lxRbckl/highlander/backend/internal/handlers"
	"github.com/lxRbckl/highlander/backend/internal/middleware"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8000"
	}

	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		dbURL = "postgres://marchuser:marchpass@localhost:5432/marchproject?sslmode=disable"
	}

	db, err := database.Connect(dbURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	sqlDB, err := db.DB()
	if err != nil {
		log.Fatalf("Failed to get underlying DB: %v", err)
	}
	defer sqlDB.Close()

	mux := http.NewServeMux()

	mux.HandleFunc("GET /health", handlers.Health)
	mux.HandleFunc("POST /api/sync", handlers.Sync(db))
	mux.HandleFunc("GET /api/data", handlers.GetData(db))
	mux.HandleFunc("POST /api/chat", handlers.Chat())

	handler := middleware.CORS(middleware.Logger(mux))

	log.Printf("Server starting on :%s", port)
	if err := http.ListenAndServe(":"+port, handler); err != nil {
		log.Fatalf("Server failed: %v", err)
	}
}
