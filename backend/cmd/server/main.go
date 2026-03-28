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
		dbURL = "postgres://highlander:marchpass@localhost:5432/highlander?sslmode=disable"
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

	// Edge case 13: warn if ENCRYPTION_KEY is not set — medical data will
	// be encrypted with a hardcoded dev key that is publicly known.
	if os.Getenv("ENCRYPTION_KEY") == "" {
		log.Println("WARNING: ENCRYPTION_KEY is not set. Medical data will use the hardcoded dev key. Set this in production!")
	}

	// Start WebSocket hub for real-time event broadcasting.
	hub := handlers.NewHub()
	go hub.Run()
	handlers.SetWSHub(hub)

	mux := http.NewServeMux()

	// Public routes
	mux.HandleFunc("GET /health", handlers.Health)
	mux.HandleFunc("POST /api/login", handlers.Login(db))

	// Edge case 3: /api/agent/auth is a PUBLIC route — agents authenticate
	// with an API key to obtain a JWT, so it cannot sit behind JWT middleware.
	mux.HandleFunc("POST /api/agent/auth", handlers.AgentAuth(db))

	// WebSocket endpoint — auth via query param, not middleware.
	mux.HandleFunc("GET /api/ws", handlers.WebSocketHandler(hub))

	// Seed default settings on startup (no-op if rows already exist)
	handlers.SeedDefaultSettings(db)
	// Ensure settings added after initial seed exist on pre-existing databases
	handlers.SeedMissingSettings(db)

	// Populate demo data when SEED_DATA=true (idempotent — skipped if DB non-empty)
	if os.Getenv("SEED_DATA") == "true" {
		database.SeedData(db)
	}

	// Authenticated routes
	api := http.NewServeMux()
	api.HandleFunc("POST /api/sync", handlers.Sync(db))
	api.HandleFunc("GET /api/data", handlers.GetData(db))
	api.HandleFunc("GET /api/audit-logs", handlers.GetAuditLogs(db)) // RBAC enforced at handler level: Admin + Safety Manager only
	api.HandleFunc("POST /api/chat", handlers.Chat(db))
	handlers.RegisterSettingsRoutes(api, db)

	// Incident domain routes (CRUD, OSHA, railroad, photos, status)
	handlers.RegisterIncidentRoutes(api, db)

	// Investigation domain routes (CRUD, five-whys, factors, witnesses, workflow)
	handlers.RegisterInvestigationRoutes(api, db)

	// CAPA domain routes (CRUD, complete, verify, dashboard)
	handlers.RegisterCAPARoutes(api, db)

	// Dashboard & hours-worked routes (TRIR, DART, charts)
	handlers.RegisterDashboardRoutes(api, db)

	// Incident link routes (manual recurrence linking, clusters)
	handlers.RegisterIncidentLinkRoutes(api, db)

	// Notification routes (escalation notifications, bell badge)
	handlers.RegisterNotificationRoutes(api, db)

	// Recurrence detection routes (automated similarity scanning, dismiss suggestions)
	handlers.RegisterRecurrenceRoutes(api, db)

	// Advanced analytics routes (body map, time heatmap, division radar)
	handlers.RegisterAnalyticsRoutes(api, db)

	// OSHA log export routes (Form 300, 300A, 301) — Safety Manager + Admin only
	handlers.RegisterOSHARoutes(api, db)

	// Training requirement routes (linked to Training-category CAPAs)
	handlers.RegisterTrainingRoutes(api, db)

	// Global search routes (cross-entity search with RBAC scoping)
	handlers.RegisterSearchRoutes(api, db)

	// Incident lifecycle timeline route (cross-entity chronological view)
	handlers.RegisterIncidentTimelineRoutes(api, db)

	// Live activity feed (RBAC-scoped, human-readable audit log entries)
	handlers.RegisterActivityRoutes(api, db)

	// Agent API key management routes (create, list, revoke — authenticated)
	handlers.RegisterAgentRoutes(api, db)

	mux.Handle("/api/", middleware.FirebaseAuth(api))

	handler := middleware.CORS(middleware.Logger(mux))

	log.Printf("Server starting on :%s", port)
	if err := http.ListenAndServe(":"+port, handler); err != nil {
		log.Fatalf("Server failed: %v", err)
	}
}
