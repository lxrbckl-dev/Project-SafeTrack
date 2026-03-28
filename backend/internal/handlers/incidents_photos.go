package handlers

import (
	"encoding/json"
	"net/http"
	"strconv"

	"gorm.io/gorm"

	"github.com/lxRbckl/highlander/backend/internal/middleware"
	"github.com/lxRbckl/highlander/backend/internal/models"
)

// UploadIncidentPhoto handles POST /api/incidents/{id}/photos.
// Expects multipart/form-data with a "file" field.
func UploadIncidentPhoto(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.GetUserID(r)

		id := r.PathValue("id")
		idUint, err := strconv.ParseUint(id, 10, 64)
		if err != nil {
			http.Error(w, "invalid incident id", http.StatusBadRequest)
			return
		}

		// Verify incident exists.
		var incident models.Incident
		if err := db.First(&incident, idUint).Error; err != nil {
			http.Error(w, "incident not found", http.StatusNotFound)
			return
		}

		// Parse multipart -- 32 MB max memory.
		if err := r.ParseMultipartForm(32 << 20); err != nil {
			http.Error(w, "failed to parse multipart form", http.StatusBadRequest)
			return
		}

		file, header, err := r.FormFile("file")
		if err != nil {
			http.Error(w, "missing file field", http.StatusBadRequest)
			return
		}
		defer file.Close()

		// Read entire file into memory.
		buf := make([]byte, header.Size)
		if _, err := file.Read(buf); err != nil {
			http.Error(w, "failed to read file", http.StatusInternalServerError)
			return
		}

		photo := models.IncidentPhoto{
			IncidentID:  uint(idUint),
			FileName:    header.Filename,
			FileData:    buf,
			ContentType: header.Header.Get("Content-Type"),
			UploadedBy:  userID,
		}

		if err := db.Create(&photo).Error; err != nil {
			http.Error(w, "database error", http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(photo)
	}
}
