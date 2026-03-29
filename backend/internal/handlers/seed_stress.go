package handlers

import (
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"time"

	"gorm.io/gorm"

	"github.com/lxRbckl/highlander/backend/internal/crypto"
	"github.com/lxRbckl/highlander/backend/internal/middleware"
	"github.com/lxRbckl/highlander/backend/internal/models"
)

// stressTestMarker is embedded in every stress-test incident description for
// idempotency checks and easy cleanup.
const stressTestMarker = "[STRESS-TEST]"

// SeedStressTest returns a handler that generates bulk stress-test data for
// dashboards, charts, and workflow validation. Admin-only, audit-logged.
func SeedStressTest(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.GetUserID(r)
		userRole := middleware.GetUserRole(r)
		isAgent := middleware.GetIsAgent(r)

		// ------------------------------------------------------------------
		// Idempotency: bail if stress-test data already exists.
		// ------------------------------------------------------------------
		var existing int64
		db.Model(&models.Incident{}).Where("description LIKE ?", "%"+stressTestMarker+"%").Count(&existing)
		if existing > 0 {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusOK)
			json.NewEncoder(w).Encode(map[string]string{
				"message": "Stress test data already exists",
			})
			return
		}

		now := time.Now()
		rng := rand.New(rand.NewSource(now.UnixNano()))

		// ------------------------------------------------------------------
		// Helpers
		// ------------------------------------------------------------------
		pick := func(choices []string) string {
			return choices[rng.Intn(len(choices))]
		}
		pickFloat := func(min, max float64) float64 {
			return min + rng.Float64()*(max-min)
		}
		randInt := func(min, max int) int {
			return min + rng.Intn(max-min+1)
		}
		timePtr := func(t time.Time) *time.Time { return &t }
		boolPtr := func(b bool) *bool { return &b }
		mustEncrypt := func(plain string) string {
			enc, err := crypto.Encrypt(plain)
			if err != nil {
				panic(fmt.Sprintf("stress-test encrypt: %v", err))
			}
			return enc
		}

		// ------------------------------------------------------------------
		// Reference data
		// ------------------------------------------------------------------
		divisions := []string{"Construction", "Rail", "Bridge", "Signals"}
		projects := []string{"Highway 71", "Rail Yard Expansion", "Bridge Retrofit", "Signal Upgrade"}
		severities := []string{"Low", "Medium", "High", "Critical"}
		weatherOpts := []string{"Clear", "Rain", "Overcast", "Wind", "Hot"}
		shiftOpts := []string{"Day", "Night", "Swing"}

		// Weighted type selection: Injury 30%, Near Miss 25%, Property Damage 15%,
		// Environmental 10%, Vehicle 10%, Fire 5%, Utility Strike 5%.
		typeWeights := []struct {
			typ    string
			weight int
		}{
			{"Injury", 30},
			{"Near Miss", 25},
			{"Property Damage", 15},
			{"Environmental", 10},
			{"Vehicle", 10},
			{"Fire", 5},
			{"Utility Strike", 5},
		}
		pickType := func() string {
			roll := rng.Intn(100)
			cum := 0
			for _, tw := range typeWeights {
				cum += tw.weight
				if roll < cum {
					return tw.typ
				}
			}
			return "Near Miss"
		}

		// Status pool with counts (total 50).
		statusPool := []string{}
		for _, sc := range []struct {
			s string
			n int
		}{
			{"Reported", 10},
			{"Under Investigation", 8},
			{"Investigation Complete", 5},
			{"CAPA Assigned", 5},
			{"CAPA In Progress", 7},
			{"Closed", 15},
		} {
			for i := 0; i < sc.n; i++ {
				statusPool = append(statusPool, sc.s)
			}
		}
		// Shuffle the pool so assignments are randomised.
		rng.Shuffle(len(statusPool), func(i, j int) { statusPool[i], statusPool[j] = statusPool[j], statusPool[i] })

		railroads := []string{"BNSF", "UP", "CSX", "NS"}

		locations := []string{
			"I-10 Eastbound Ramp", "Westheimer & Montrose", "Port of Houston Dock 7",
			"Katy Freeway Overpass", "Sam Houston Tollway S", "Memorial Park Trail",
			"Hobby Airport Perimeter Rd", "Galleria Area Lot C", "Buffalo Bayou Trail",
			"Heights Blvd Bridge", "Downtown Transit Center", "Ship Channel Yard",
			"East End Rail Crossing", "Med Center Garage B", "NRG Stadium Lot",
			"Allen Parkway Median", "Gulfton Substation", "Greenspoint Mall Rd",
			"Westchase Utility Easement", "Energy Corridor Blvd",
		}

		descriptions := []string{
			"Worker slipped on wet surface near excavation area",
			"Near miss: excavator swung into traffic lane unexpectedly",
			"Material fell from elevated platform, no injuries reported",
			"Chemical spill contained within secondary containment berm",
			"Delivery truck sideswiped barricade at site entrance",
			"Small brush fire started by welding sparks on dry vegetation",
			"Utility line struck during directional bore operation",
			"Employee reported back strain after lifting heavy equipment",
			"Scaffold plank cracked under load during inspection",
			"Forklift tipped over on uneven ground near loading dock",
			"Crane cable showed signs of fraying during daily inspection",
			"Worker experienced heat exhaustion during afternoon shift",
			"Concrete pump hose burst, spraying area around pour zone",
			"Pedestrian nearly entered active work zone due to missing signage",
			"Gas leak detected at tie-in point, area evacuated",
			"Trenching operation exposed unmarked underground conduit",
			"Employee cut hand on exposed rebar while placing forms",
			"Vehicle rollback on grade, stopped by wheel chock",
			"Noise exposure exceeded 85 dB for four consecutive hours",
			"Fall protection anchor point failed during load test",
		}

		immediateActions := []string{
			"Area cordoned off, first aid administered",
			"Work stopped, toolbox talk conducted",
			"Spill kit deployed, area cleaned",
			"Fire extinguisher used, fire watch posted",
			"Utility company notified, area marked",
			"Employee sent to clinic, duties reassigned",
			"Equipment taken out of service for inspection",
			"Barricades and signage reinforced",
			"Evacuation completed, all personnel accounted for",
			"Supervisor notified, incident documented",
		}

		// Fetch existing user IDs to use as reporters / assignees.
		var users []models.User
		db.Find(&users)
		if len(users) == 0 {
			http.Error(w, "no users in database — seed users first", http.StatusPreconditionFailed)
			return
		}
		userIDs := make([]string, len(users))
		for i, u := range users {
			userIDs[i] = fmt.Sprintf("%d", u.ID)
		}

		// ------------------------------------------------------------------
		// 50 Incidents
		// ------------------------------------------------------------------
		incidents := make([]models.Incident, 50)
		injuryIncidentIndices := []int{} // track which incidents are Injury type

		oshaCount := 0
		dartCount := 0
		rrCount := 0

		for i := 0; i < 50; i++ {
			incType := pickType()
			mo := rng.Intn(12)
			dy := rng.Intn(28)
			hour := randInt(6, 22)
			// Spread across weekdays — pick a random weekday offset.
			date := now.AddDate(0, -mo, -dy)
			date = time.Date(date.Year(), date.Month(), date.Day(), hour, rng.Intn(60), 0, 0, time.UTC)

			status := statusPool[i]

			lat := pickFloat(29.7, 29.8)
			lng := pickFloat(-95.4, -95.3)

			isRR := false
			rrClient := ""
			if rrCount < 10 && (i < 10 || rng.Float64() < 0.25) {
				isRR = true
				rrClient = pick(railroads)
				rrCount++
			}

			isOsha := boolPtr(false)
			isDart := boolPtr(false)
			if incType == "Injury" && oshaCount < 8 {
				isOsha = boolPtr(true)
				oshaCount++
				if dartCount < 5 {
					isDart = boolPtr(true)
					dartCount++
				}
			}

			completion := randInt(50, 100)

			desc := fmt.Sprintf("%s %s", pick(descriptions), stressTestMarker)

			inc := models.Incident{
				Type:               incType,
				Date:               date,
				Location:           pick(locations),
				Latitude:           lat,
				Longitude:          lng,
				Division:           pick(divisions),
				ProjectJobSite:     pick(projects),
				Description:        desc,
				ImmediateActions:   pick(immediateActions),
				Severity:           pick(severities),
				PotentialSeverity:  pick(severities),
				Shift:              pick(shiftOpts),
				Weather:            pick(weatherOpts),
				Status:             status,
				ReporterID:         pick(userIDs),
				IsDraft:            false,
				CompletionPercent:  completion,
				IsOshaRecordable:   isOsha,
				IsDart:             isDart,
				IsRailroadProperty: isRR,
				RailroadClient:     rrClient,
			}

			if isRR {
				inc.RailroadNotified = true
				inc.RailroadNotificationDate = timePtr(date.Add(2 * time.Hour))
				inc.RailroadNotificationMethod = pick([]string{"Phone", "Email", "In Person"})
			}

			incidents[i] = inc
			if incType == "Injury" {
				injuryIncidentIndices = append(injuryIncidentIndices, i)
			}
		}

		if err := db.Create(&incidents).Error; err != nil {
			log.Printf("stress-test: failed to create incidents: %v", err)
			http.Error(w, "failed to create incidents", http.StatusInternalServerError)
			return
		}
		log.Printf("stress-test: created %d incidents", len(incidents))

		// ------------------------------------------------------------------
		// 10 Injured Persons — linked to Injury incidents
		// ------------------------------------------------------------------
		bodyParts := []string{"Head", "Back", "Left Arm", "Right Hand", "Left Leg", "Right Foot", "Torso", "Shoulder", "Knee", "Eye"}
		injuryTypes := []string{"Laceration", "Sprain", "Fracture", "Contusion", "Burn", "Strain"}
		treatmentTypes := []string{"First Aid", "Medical Treatment", "Emergency Room", "Hospitalization"}
		rtwStatuses := []string{"Full Duty", "Restricted Duty", "Lost Time", "Not Yet Returned"}
		sides := []string{"Left", "Right", "N/A", "Bilateral"}
		names := []string{
			"John Martinez", "Sarah Johnson", "Carlos Rivera", "Linda Chen",
			"Ahmed Hassan", "Maria Gonzalez", "David Kim", "Angela White",
			"Raj Patel", "Tanya Brooks",
		}
		jobTitles := []string{
			"Laborer", "Equipment Operator", "Electrician", "Carpenter",
			"Foreman", "Welder", "Pipefitter", "Ironworker", "Painter", "Rigger",
		}

		injuredPersons := make([]models.InjuredPerson, 10)
		for i := 0; i < 10; i++ {
			// Cycle through injury incidents, wrapping if < 10.
			idx := injuryIncidentIndices[i%len(injuryIncidentIndices)]
			injuredPersons[i] = models.InjuredPerson{
				IncidentID:         incidents[idx].ID,
				Name:               names[i],
				JobTitle:           jobTitles[i],
				Division:           incidents[idx].Division,
				InjuryType:         mustEncrypt(injuryTypes[i%len(injuryTypes)]),
				BodyPart:           mustEncrypt(bodyParts[i]),
				BodyPartSide:       sides[i%len(sides)],
				TreatmentType:      mustEncrypt(treatmentTypes[i%len(treatmentTypes)]),
				ReturnToWorkStatus: mustEncrypt(rtwStatuses[i%len(rtwStatuses)]),
			}
		}

		if err := db.Create(&injuredPersons).Error; err != nil {
			log.Printf("stress-test: failed to create injured persons: %v", err)
			http.Error(w, "failed to create injured persons", http.StatusInternalServerError)
			return
		}
		log.Printf("stress-test: created %d injured persons", len(injuredPersons))

		// ------------------------------------------------------------------
		// 15 Investigations — linked to eligible incidents
		// ------------------------------------------------------------------
		// Pick incidents that are beyond "Reported" status.
		eligibleIndices := []int{}
		for i, inc := range incidents {
			if inc.Status != "Reported" {
				eligibleIndices = append(eligibleIndices, i)
			}
		}
		rng.Shuffle(len(eligibleIndices), func(i, j int) {
			eligibleIndices[i], eligibleIndices[j] = eligibleIndices[j], eligibleIndices[i]
		})
		if len(eligibleIndices) > 15 {
			eligibleIndices = eligibleIndices[:15]
		}

		invStatuses := []string{
			"Assigned", "Assigned", "Assigned",
			"In Progress", "In Progress", "In Progress", "In Progress", "In Progress",
			"Under Review", "Under Review", "Under Review",
			"Approved", "Approved", "Approved", "Approved",
		}

		investigations := make([]models.Investigation, len(eligibleIndices))
		for i, idx := range eligibleIndices {
			targetDate := incidents[idx].Date.AddDate(0, 0, randInt(7, 30))
			var actualDate *time.Time
			status := invStatuses[i]
			if status == "Approved" {
				actualDate = timePtr(targetDate.AddDate(0, 0, randInt(-3, 5)))
			}

			isOverdue := false
			escalation := 0
			// 3 overdue at L1/L2/L3
			if i < 3 {
				isOverdue = true
				escalation = i + 1 // 1, 2, 3
				// Make target date in the past so it reads as overdue.
				targetDate = now.AddDate(0, 0, -(escalation*7 + 1))
				actualDate = nil
				if status == "Approved" {
					status = "In Progress"
				}
			}

			inv := models.Investigation{
				IncidentID:             incidents[idx].ID,
				LeadInvestigatorID:     pick(userIDs),
				TeamMembers:            fmt.Sprintf(`["%s","%s"]`, pick(userIDs), pick(userIDs)),
				TargetCompletionDate:   targetDate,
				ActualCompletionDate:   actualDate,
				Status:                 status,
				AssignedBy:             pick(userIDs),
				IsOverdue:              isOverdue,
				OverdueEscalationLevel: escalation,
			}

			if status == "Under Review" || status == "Approved" {
				inv.ReviewedBy = pick(userIDs)
				inv.ReviewComments = "Investigation findings reviewed and accepted."
				inv.ReviewDate = timePtr(targetDate.AddDate(0, 0, randInt(1, 5)))
			}

			investigations[i] = inv
		}

		if err := db.Create(&investigations).Error; err != nil {
			log.Printf("stress-test: failed to create investigations: %v", err)
			http.Error(w, "failed to create investigations", http.StatusInternalServerError)
			return
		}
		log.Printf("stress-test: created %d investigations", len(investigations))

		// ------------------------------------------------------------------
		// FiveWhy chains for first 5 investigations (3-5 levels each)
		// ------------------------------------------------------------------
		fiveWhyQuestions := [][]string{
			{"Why did the incident occur?", "Why was the hazard present?", "Why wasn't it identified?", "Why did the control fail?", "Why was the procedure not followed?"},
			{"Why was the worker injured?", "Why was the area unsafe?", "Why was the inspection missed?"},
			{"Why did the equipment fail?", "Why wasn't maintenance performed?", "Why was the schedule not followed?", "Why was staffing inadequate?"},
			{"Why was the spill not contained?", "Why was the containment breached?", "Why wasn't it inspected?", "Why was the schedule missed?", "Why was training insufficient?"},
			{"Why did the vehicle collide?", "Why was visibility poor?", "Why were barriers missing?"},
		}
		fiveWhyAnswers := [][]string{
			{"Wet surface near excavation", "Recent rain and no drainage", "Pre-task hazard assessment skipped", "Supervisor was covering two crews", "Training did not cover wet conditions"},
			{"Struck by falling material", "Unsecured load on scaffold", "Morning walkaround omitted"},
			{"Hydraulic line ruptured", "PM schedule was 2 weeks overdue", "Parts backordered, no escalation", "Only one mechanic on shift"},
			{"Volume exceeded berm capacity", "Berm had crack from settling", "Quarterly inspection lapsed", "Inspector reassigned to other site", "New hire not trained on inspection protocol"},
			{"Backing without spotter", "Dust from adjacent grading op", "Removed for access, not replaced"},
		}

		var fiveWhys []models.FiveWhy
		for i := 0; i < 5 && i < len(investigations); i++ {
			levels := len(fiveWhyQuestions[i])
			for lvl := 0; lvl < levels; lvl++ {
				fiveWhys = append(fiveWhys, models.FiveWhy{
					InvestigationID: investigations[i].ID,
					Level:           lvl + 1,
					Question:        fiveWhyQuestions[i][lvl],
					Answer:          fiveWhyAnswers[i][lvl],
					SortOrder:       lvl + 1,
				})
			}
		}

		if len(fiveWhys) > 0 {
			if err := db.Create(&fiveWhys).Error; err != nil {
				log.Printf("stress-test: failed to create five-whys: %v", err)
			} else {
				log.Printf("stress-test: created %d five-why entries", len(fiveWhys))
			}
		}

		// ------------------------------------------------------------------
		// Contributing Factors for investigations 5-9 (all 5 categories)
		// ------------------------------------------------------------------
		factorTypes := []string{"Human Factors", "Equipment", "Environmental", "Procedural", "Organizational"}
		factorDescs := map[string][]string{
			"Human Factors":  {"Fatigue from overtime", "Inadequate training on procedure", "Complacency with routine task"},
			"Equipment":      {"Worn brake pads", "Missing guard on grinder", "Outdated PPE"},
			"Environmental":  {"Poor lighting at work area", "Excessive noise masking warning", "Wet ground from overnight rain"},
			"Procedural":     {"JSA not updated for new scope", "Lockout/tagout steps skipped", "Permit not posted at entry"},
			"Organizational": {"Understaffed crew on night shift", "Budget cuts delayed equipment replacement", "No safety stand-down in 6 months"},
		}

		var factors []models.ContributingFactor
		for i := 5; i < 10 && i < len(investigations); i++ {
			for j, ft := range factorTypes {
				descs := factorDescs[ft]
				factors = append(factors, models.ContributingFactor{
					InvestigationID:   investigations[i].ID,
					FactorType:        ft,
					FactorDescription: descs[rng.Intn(len(descs))],
					IsPrimary:         j == 0, // first factor is primary
				})
			}
		}

		if len(factors) > 0 {
			if err := db.Create(&factors).Error; err != nil {
				log.Printf("stress-test: failed to create contributing factors: %v", err)
			} else {
				log.Printf("stress-test: created %d contributing factors", len(factors))
			}
		}

		// ------------------------------------------------------------------
		// 20 CAPAs — linked to investigations
		// ------------------------------------------------------------------
		capaCategories := []string{"Training", "Procedure Change", "Engineering Control", "PPE", "Equipment Modification", "Policy Change", "Other"}
		capaPriorities := []string{
			"Critical", "Critical", "Critical",
			"High", "High", "High", "High", "High",
			"Medium", "Medium", "Medium", "Medium", "Medium", "Medium", "Medium",
			"Low", "Low", "Low", "Low", "Low",
		}
		capaStatuses := []string{
			"Open", "Open", "Open", "Open",
			"In Progress", "In Progress", "In Progress", "In Progress",
			"Completed", "Completed", "Completed",
			"Verification Pending", "Verification Pending", "Verification Pending",
			"Verified Effective", "Verified Effective", "Verified Effective", "Verified Effective", "Verified Effective",
			"Verified Ineffective",
		}
		capaDescriptions := []string{
			"Implement additional fall protection training for all field crews",
			"Update confined space entry procedure to include buddy system",
			"Install proximity sensors on heavy equipment",
			"Procure and distribute cut-resistant gloves for rebar crews",
			"Retrofit guardrails on all elevated platforms above 6 feet",
			"Revise hot work permit to require fire watch for 60 minutes post-work",
			"Conduct root cause analysis refresher for all supervisors",
			"Replace worn wire rope slings fleet-wide",
			"Add pre-shift stretching program to reduce musculoskeletal injuries",
			"Install additional lighting at night work zones",
			"Require daily inspection of all scaffolding before use",
			"Update lockout/tagout energy control procedures",
			"Mandate spotter for all backing operations on site",
			"Create hazard communication board at each site entrance",
			"Procure noise-canceling ear protection for grinding operations",
			"Establish weekly safety stand-down meeting protocol",
			"Upgrade fire extinguisher placement per new site layout",
			"Train all operators on updated excavation safety procedures",
			"Implement buddy system for lone worker tasks",
			"Review and update emergency action plan for chemical spills",
		}
		verificationMethods := []string{
			"Field audit of compliance",
			"Review of updated procedure document",
			"Training completion records",
			"Physical inspection of installed control",
			"Observation of work practice",
		}

		capas := make([]models.CAPA, 20)
		overdueCapaCount := 0
		trainingCapaIndices := []int{}

		for i := 0; i < 20; i++ {
			invIdx := i % len(investigations)
			inv := investigations[invIdx]

			dueDate := now.AddDate(0, 0, randInt(-30, 60))
			status := capaStatuses[i]
			priority := capaPriorities[i]
			category := pick(capaCategories)

			// Ensure we get some Training CAPAs.
			if i < 3 {
				category = "Training"
			}
			if category == "Training" {
				trainingCapaIndices = append(trainingCapaIndices, i)
			}

			capaType := "Corrective"
			if rng.Float64() < 0.4 {
				capaType = "Preventive"
			}

			isOverdue := false
			escalation := 0
			if overdueCapaCount < 3 && (status == "Open" || status == "In Progress") {
				isOverdue = true
				overdueCapaCount++
				escalation = overdueCapaCount
				dueDate = now.AddDate(0, 0, -(escalation*7 + 2))
			}

			var completionDate *time.Time
			var verificationDate *time.Time
			verifiedBy := ""
			completionNotes := ""

			switch status {
			case "Completed", "Verification Pending", "Verified Effective", "Verified Ineffective":
				completionDate = timePtr(dueDate.AddDate(0, 0, randInt(-5, 3)))
				completionNotes = "Action completed as specified."
			}
			switch status {
			case "Verified Effective":
				verificationDate = timePtr(dueDate.AddDate(0, 0, randInt(5, 15)))
				verifiedBy = pick(userIDs)
			case "Verified Ineffective":
				verificationDate = timePtr(dueDate.AddDate(0, 0, randInt(5, 15)))
				verifiedBy = pick(userIDs)
			}

			vDueDate := dueDate.AddDate(0, 0, 14)

			capas[i] = models.CAPA{
				InvestigationID:        inv.ID,
				IncidentID:             inv.IncidentID,
				Type:                   capaType,
				Category:               category,
				Description:            capaDescriptions[i],
				AssignedToUserID:       pick(userIDs),
				AssignedByUserID:       pick(userIDs),
				DueDate:                dueDate,
				Priority:               priority,
				VerificationMethod:     pick(verificationMethods),
				VerificationDueDate:    &vDueDate,
				Status:                 status,
				CompletionNotes:        completionNotes,
				CompletionDate:         completionDate,
				VerifiedByUserID:       verifiedBy,
				VerificationDate:       verificationDate,
				IsOverdue:              isOverdue,
				OverdueEscalationLevel: escalation,
			}
		}

		if err := db.Create(&capas).Error; err != nil {
			log.Printf("stress-test: failed to create CAPAs: %v", err)
			http.Error(w, "failed to create CAPAs", http.StatusInternalServerError)
			return
		}
		log.Printf("stress-test: created %d CAPAs", len(capas))

		// ------------------------------------------------------------------
		// 48 Hours Worked — 12 months x 4 divisions
		// ------------------------------------------------------------------
		hoursWorked := make([]models.HoursWorked, 0, 48)
		for m := 0; m < 12; m++ {
			for _, div := range divisions {
				start := time.Date(now.Year(), now.Month()-time.Month(m), 1, 0, 0, 0, 0, time.UTC)
				end := start.AddDate(0, 1, -1)
				hours := pickFloat(50000, 80000)
				hoursWorked = append(hoursWorked, models.HoursWorked{
					ReportingPeriodStart: start,
					ReportingPeriodEnd:   end,
					TotalHours:           hours,
					Division:             div,
					EnteredByUserID:      pick(userIDs),
				})
			}
		}

		if err := db.Create(&hoursWorked).Error; err != nil {
			log.Printf("stress-test: failed to create hours worked: %v", err)
			http.Error(w, "failed to create hours worked", http.StatusInternalServerError)
			return
		}
		log.Printf("stress-test: created %d hours-worked records", len(hoursWorked))

		// ------------------------------------------------------------------
		// 5 Incident Links — various similarity types
		// ------------------------------------------------------------------
		similarityTypes := []string{"Same Location", "Same Type", "Same Root Cause", "Same Equipment", "Same Person"}
		links := make([]models.IncidentLink, 0, 5)
		usedPairs := map[[2]uint]bool{}
		for i := 0; i < 5; i++ {
			// Pick two distinct incidents, with lower ID first.
			a := rng.Intn(len(incidents))
			b := rng.Intn(len(incidents))
			for b == a {
				b = rng.Intn(len(incidents))
			}
			id1, id2 := incidents[a].ID, incidents[b].ID
			if id1 > id2 {
				id1, id2 = id2, id1
			}
			pair := [2]uint{id1, id2}
			if usedPairs[pair] {
				continue
			}
			usedPairs[pair] = true

			links = append(links, models.IncidentLink{
				IncidentID1:    id1,
				IncidentID2:    id2,
				SimilarityType: similarityTypes[i%len(similarityTypes)],
				Notes:          fmt.Sprintf("Stress-test link: %s between incidents %d and %d", similarityTypes[i%len(similarityTypes)], id1, id2),
				LinkedByUserID: pick(userIDs),
			})
		}

		if len(links) > 0 {
			if err := db.Create(&links).Error; err != nil {
				log.Printf("stress-test: failed to create incident links: %v", err)
			} else {
				log.Printf("stress-test: created %d incident links", len(links))
			}
		}

		// ------------------------------------------------------------------
		// 3 Training Requirements — linked to Training-category CAPAs
		// ------------------------------------------------------------------
		courseNames := []string{
			"Fall Protection Competent Person Refresher",
			"Confined Space Entry & Rescue Update",
			"Excavation Safety Awareness",
		}
		courseDescs := []string{
			"Refresher training on OSHA 1926.502 fall protection standards",
			"Updated training for confined space entry procedures and rescue",
			"Comprehensive training on excavation hazards and protective systems",
		}

		trainingReqs := make([]models.TrainingRequirement, 0, 3)
		for i := 0; i < 3 && i < len(trainingCapaIndices); i++ {
			capa := capas[trainingCapaIndices[i]]
			trainingReqs = append(trainingReqs, models.TrainingRequirement{
				CAPAID:           capa.ID,
				CourseName:       courseNames[i],
				Description:      courseDescs[i],
				AssignedToUserID: capa.AssignedToUserID,
				AssignedByUserID: capa.AssignedByUserID,
				DueDate:          capa.DueDate,
				Status:           pick([]string{"Pending", "Completed"}),
			})
		}

		if len(trainingReqs) > 0 {
			if err := db.Create(&trainingReqs).Error; err != nil {
				log.Printf("stress-test: failed to create training requirements: %v", err)
			} else {
				log.Printf("stress-test: created %d training requirements", len(trainingReqs))
			}
		}

		// ------------------------------------------------------------------
		// Audit log entry
		// ------------------------------------------------------------------
		_ = LogAction(db, userID, userRole, "seed_stress_test", "system", 0, "", "",
			fmt.Sprintf("Generated stress test data: 50 incidents, %d investigations, 20 CAPAs, 48 hours-worked, %d links, %d training reqs",
				len(investigations), len(links), len(trainingReqs)),
			isAgent,
		)

		log.Printf("stress-test: seeding complete")

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(map[string]interface{}{
			"message":        "Stress test data seeded successfully",
			"incidents":      len(incidents),
			"injuredPersons": len(injuredPersons),
			"investigations": len(investigations),
			"capas":          len(capas),
			"hoursWorked":    len(hoursWorked),
			"incidentLinks":  len(links),
			"trainingReqs":   len(trainingReqs),
		})
	}
}

// RegisterSeedStressRoutes registers the stress-test seeding endpoint. Admin only.
func RegisterSeedStressRoutes(api *http.ServeMux, db *gorm.DB) {
	api.HandleFunc("POST /api/seed-stress-test", middleware.RequireRole(SeedStressTest(db), "admin"))
}
