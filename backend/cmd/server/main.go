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

	mux := http.NewServeMux()

	// Public routes
	mux.HandleFunc("GET /health", handlers.Health)
	mux.HandleFunc("POST /api/login", handlers.Login(db))

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
	api.HandleFunc("POST /api/chat", handlers.Chat())
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

	mux.Handle("/api/", middleware.FirebaseAuth(api))

	handler := middleware.CORS(middleware.Logger(mux))

	log.Printf("Server starting on :%s", port)
	if err := http.ListenAndServe(":"+port, handler); err != nil {
		log.Fatalf("Server failed: %v", err)
	}
}
