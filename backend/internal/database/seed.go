// Package database provides the PostgreSQL connection setup and seed data for demo.
package database

import (
	"fmt"
	"log"
	"math/rand"
	"time"

	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"

	"github.com/lxRbckl/highlander/backend/internal/crypto"
	"github.com/lxRbckl/highlander/backend/internal/models"
)

// SeedData populates the database with realistic demo data.
// It is idempotent — if any incidents already exist, it returns immediately.
// Trigger by setting SEED_DATA=true in the environment.
func SeedData(db *gorm.DB) {
	var count int64
	db.Model(&models.Incident{}).Count(&count)
	if count > 0 {
		log.Println("Seed: incidents table is non-empty — skipping seed")
		return
	}

	log.Println("Seed: populating demo data…")

	now := time.Now()
	rng := rand.New(rand.NewSource(now.UnixNano()))

	// -------------------------------------------------------------------------
	// Helpers
	// -------------------------------------------------------------------------
	timePtr := func(t time.Time) *time.Time { return &t }
	boolPtr := func(b bool) *bool { return &b }

	mustEncrypt := func(plain string) string {
		enc, err := crypto.Encrypt(plain)
		if err != nil {
			panic(fmt.Sprintf("seed encrypt: %v", err))
		}
		return enc
	}

	uid := func(id uint) string {
		return fmt.Sprintf("%d", id)
	}

	pick := func(choices []string) string {
		return choices[rng.Intn(len(choices))]
	}

	pickFloat := func(min, max float64) float64 {
		return min + rng.Float64()*(max-min)
	}

	randDate := func(monthsBack int) time.Time {
		mo := rng.Intn(monthsBack)
		dy := rng.Intn(28)
		return now.AddDate(0, -mo, -dy)
	}

	// -------------------------------------------------------------------------
	// Users — seeded first; their IDs are used by all subsequent seed data.
	// All test accounts use password "demo1234".
	// -------------------------------------------------------------------------
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte("demo1234"), bcrypt.DefaultCost)
	if err != nil {
		log.Fatalf("Seed: failed to hash password: %v", err)
	}
	pw := string(hashedPassword)

	reporter := models.User{Email: "reporter@safetrack.demo", PasswordHash: pw, DisplayName: "Maria Santos", Role: "field_reporter", Division: "Construction"}
	coordinator := models.User{Email: "coordinator@safetrack.demo", PasswordHash: pw, DisplayName: "James Chen", Role: "safety_coordinator"}
	manager := models.User{Email: "manager@safetrack.demo", PasswordHash: pw, DisplayName: "Sarah Williams", Role: "safety_manager"}
	pm := models.User{Email: "pm@safetrack.demo", PasswordHash: pw, DisplayName: "Michael Torres", Role: "pm", Project: "Project Alpha"}
	director := models.User{Email: "director@safetrack.demo", PasswordHash: pw, DisplayName: "Lisa Anderson", Role: "division_manager", Division: "Construction"}
	executive := models.User{Email: "executive@safetrack.demo", PasswordHash: pw, DisplayName: "Robert Kim", Role: "executive"}
	admin := models.User{Email: "admin@safetrack.demo", PasswordHash: pw, DisplayName: "Alex Thompson", Role: "admin"}
	reporter2 := models.User{Email: "reporter2@safetrack.demo", PasswordHash: pw, DisplayName: "Carlos Ruiz", Role: "field_reporter", Division: "Maintenance"}
	reporter3 := models.User{Email: "reporter3@safetrack.demo", PasswordHash: pw, DisplayName: "Aisha Patel", Role: "field_reporter", Division: "Operations"}
	coordinator2 := models.User{Email: "coordinator2@safetrack.demo", PasswordHash: pw, DisplayName: "Nina Volkov", Role: "safety_coordinator"}
	manager2 := models.User{Email: "manager2@safetrack.demo", PasswordHash: pw, DisplayName: "David Park", Role: "safety_manager"}
	pm2 := models.User{Email: "pm2@safetrack.demo", PasswordHash: pw, DisplayName: "Rachel Nguyen", Role: "pm", Project: "Project Beta"}

	users := []*models.User{
		&reporter, &coordinator, &manager, &pm, &director, &executive, &admin,
		&reporter2, &reporter3, &coordinator2, &manager2, &pm2,
	}

	for _, u := range users {
		if err := db.Create(u).Error; err != nil {
			log.Printf("Seed: failed to create user %s: %v", u.Email, err)
		}
	}
	log.Printf("Seed: created %d users", len(users))

	reporters := []string{uid(reporter.ID), uid(reporter2.ID), uid(reporter3.ID)}
	coordinators := []string{uid(coordinator.ID), uid(coordinator2.ID)}
	managers := []string{uid(manager.ID), uid(manager2.ID)}
	assignees := []string{uid(coordinator.ID), uid(coordinator2.ID), uid(pm.ID), uid(pm2.ID), uid(director.ID)}

	// -------------------------------------------------------------------------
	// Admin Settings — skip if already seeded
	// -------------------------------------------------------------------------
	var settingCount int64
	db.Model(&models.Setting{}).Count(&settingCount)
	if settingCount == 0 {
		settings := []models.Setting{
			{Category: "safety", Key: "trir_benchmark", Value: "3.0", UpdatedBy: uid(admin.ID)},
			{Category: "safety", Key: "factor_types_list", Value: `["People","Equipment","Environmental","Procedural","Management/Organizational"]`, UpdatedBy: uid(admin.ID)},
			{Category: "notifications", Key: "escalation_days", Value: `[3,7,14]`, UpdatedBy: uid(admin.ID)},
		}
		db.Create(&settings)
	}

	// -------------------------------------------------------------------------
	// Hours Worked — 12 months of data (150k-250k/month across 6 divisions)
	// -------------------------------------------------------------------------
	allDivisions := []string{"Construction", "Maintenance", "Operations", "Rail Services", "Energy", "Environmental Services"}
	for monthOffset := 11; monthOffset >= 0; monthOffset-- {
		periodStart := now.AddDate(0, -monthOffset-1, 0)
		periodStart = time.Date(periodStart.Year(), periodStart.Month(), 1, 0, 0, 0, 0, time.UTC)
		periodEnd := periodStart.AddDate(0, 1, 0).Add(-time.Second)

		// Total hours for this month: 150k-250k spread across divisions
		totalMonthHours := 150000.0 + rng.Float64()*100000.0
		for _, div := range allDivisions {
			// Weighted distribution: Construction and Operations get more
			weight := 1.0
			switch div {
			case "Construction":
				weight = 1.5
			case "Operations":
				weight = 1.3
			case "Rail Services":
				weight = 1.2
			}
			divHours := totalMonthHours * weight / 7.0 // ~7 total weight units
			db.Create(&models.HoursWorked{
				ReportingPeriodStart: periodStart,
				ReportingPeriodEnd:   periodEnd,
				TotalHours:           divHours,
				Division:             div,
				EnteredByUserID:      uid(manager.ID),
			})
		}
	}

	// -------------------------------------------------------------------------
	// String pools for realistic incident generation
	// -------------------------------------------------------------------------
	incidentTypes := []string{"Injury", "Near Miss", "Property Damage", "Environmental", "Vehicle", "Fire", "Utility Strike"}
	typeWeights := []int{25, 30, 15, 10, 10, 5, 5} // percentage weights

	severities := []string{"Fatality", "Lost Time", "Medical Treatment", "First Aid", "Near Miss"}
	sevWeights := []int{1, 10, 20, 30, 35} // cumulative approximate

	divisions := []string{"Construction", "Maintenance", "Operations", "Rail Services", "Energy", "Environmental Services"}
	projects := []string{"Project Alpha", "Project Beta", "Project Gamma", "Highway 71", "Railyard Expansion", "Substation Upgrade"}

	statuses := []string{"Reported", "Under Investigation", "Investigation Complete", "CAPA Assigned", "CAPA In Progress", "Closed", "Reopened"}

	shifts := []string{"Day", "Evening", "Night"}
	weathers := []string{"Clear", "Cloudy", "Overcast", "Rain", "Windy", "Fog", "Snow", "Partly Cloudy", "Indoor"}

	locations := []string{
		"Main Yard Track 3", "North Bridge Construction Zone", "Highway 71 Overpass",
		"Railyard 7 Staging Area", "South Yard Fuel Storage Area", "BNSF Subdivision MP 214",
		"UP Mainline near MP 87", "Equipment Yard Bay 4", "Concrete Washout Station",
		"Elevated Work Platform Zone C", "Welding Station B Shop Building",
		"Generator Room Site Office", "Signage Installation Area Bridge Deck",
		"NS Branch Line MP 52 Culvert Work", "East Corridor Trench Segment 4",
		"Material Receiving Dock", "Stockpile Area Lot 7", "Site Access Road Gate 2",
		"Highway 30 Offsite Transit", "Track Tamping Operation Zone A",
		"Substation 12 Transformer Pad", "Railyard 3 Switch Area",
		"Bridge Pier 7 Foundation", "Tunnel Portal East Approach",
		"Creek Crossing Culvert 14", "Equipment Wash Bay 2",
		"Ballast Staging Area North", "Signal House MP 118",
		"Overhead Line Section 4A", "Fuel Farm Dispensing Island 3",
		"Laydown Yard C Row 12", "Parking Structure Level 2",
		"Office Trailer Complex", "Crane Pad Area 5",
		"Pipe Storage Rack Section B", "Road Widening Zone Mile 3",
		"Drainage Basin Outfall 7", "Retaining Wall Segment 9",
		"Temporary Bridge Deck Span 2", "Compressor Station Inlet",
	}

	railroads := []string{"BNSF", "UP", "CSX", "NS"}
	notifMethods := []string{"Phone", "Email", "In Person", "Phone and Email"}

	// Descriptions by incident type
	injuryDescs := []string{
		"Worker sustained a laceration to the left hand while operating a cutting tool without proper PPE. Blade guard had been removed prior to the cut.",
		"Employee slipped on wet surface near the washdown area and struck their head on a concrete barrier. Worker was conscious but disoriented.",
		"Scaffold worker fell approximately 8 feet from an elevated platform when guardrail section was missing. Sustained fracture to right wrist.",
		"Worker caught right hand between two pipe sections during manual alignment. Crush injury to index and middle fingers required medical treatment.",
		"Employee reported lower back strain after lifting a 75-pound box without mechanical assist. Worker was placed on restricted duty.",
		"Welder sustained flash burns to forearms when arc welding without proper sleeve protection. Second-degree burns on both arms.",
		"Worker struck in the shoulder by a swinging chain that detached from a load during rigging operations. Bruising and limited range of motion.",
		"Employee suffered electrical shock when contacting an energized panel that was not properly locked out. Burns on right hand.",
		"Equipment operator sustained a knee injury when jumping from a piece of equipment instead of using the three-point dismount. Torn meniscus confirmed.",
		"Worker experienced chemical splash to eyes when transferring cleaning solvent without splash goggles. Flushed immediately per SDS.",
		"Employee reported hearing loss after four hours of tamping machine operation without hearing protection. Referred to occupational health.",
		"Worker tripped over unsecured air hose on the walking surface and fell, fracturing left elbow. Area had poor housekeeping conditions.",
		"Employee strained right shoulder while pulling cable through conduit. Repetitive motion task without ergonomic assessment.",
		"Worker stepped on a protruding nail while walking through a construction area without steel-toed boots. Puncture wound to right foot.",
		"Laboror suffered heat exhaustion after working four hours in direct sunlight without adequate hydration breaks. Core temperature elevated.",
	}
	nearMissDescs := []string{
		"Worker nearly struck by swinging crane load that was improperly secured. Load came within 2 feet of personnel in the work zone.",
		"Forklift came within 2 feet of pedestrian zone boundary without sounding horn signal. Pedestrian did not see approaching equipment.",
		"Worker nearly dropped a 20-pound sign panel from 15-foot elevation. Safety tether caught the panel before it reached ground level.",
		"Unsecured tool fell from scaffolding platform, landing 3 feet from a worker below. No injuries. Drop zone was not established.",
		"Backhoe bucket swung within inches of a gas meter during excavation. Operator did not see the meter from the cab position.",
		"Worker stepped onto an unsecured manhole cover that shifted under weight. Worker caught themselves on nearby railing.",
		"Crane boom nearly contacted overhead power line during lift. Minimum approach distance was violated by approximately 4 feet.",
		"Material stack collapsed in laydown yard when wind gust exceeded 40 mph. No personnel in immediate area at the time.",
		"Vehicle nearly struck pedestrian in a blind corner of the site access road. No mirrors or warning signs were posted.",
		"Compressed gas cylinder fell from upright position when securing chain failed. Cylinder did not breach. No personnel within 10 feet.",
		"Worker almost walked into an open excavation that lacked barricades at the south end. Excavation was 6 feet deep.",
		"Overhead crane load shifted during transport, nearly contacting a structural column. Rigging configuration was inadequate for load shape.",
		"Loose gravel caused worker to slide toward an unprotected edge at 12-foot elevation. Worker grabbed a railing to stop the slide.",
		"Flash from arc welding operation temporarily blinded a passerby who did not have welding-rated eye protection. No permanent injury.",
		"Pressurized hydraulic line burst on excavator, spraying fluid within 5 feet of an operator. Fluid temperature was approximately 180 degrees F.",
	}
	propDamageDescs := []string{
		"Excavator bucket contacted buried fiber-optic conduit, damaging approximately 30 feet of cable. Signal disruption reported.",
		"Company pickup truck backed into a parked equipment trailer. Trailer hitch and bumper damaged beyond field repair.",
		"Overhead crane cable snapped, dropping a 500-pound beam onto an empty flatbed trailer. Trailer deck punctured.",
		"Vibration from compaction equipment cracked a signal house foundation. Structural integrity assessment required.",
		"Loader bucket struck a fire hydrant during site grading. Water service disrupted for approximately 2 hours.",
		"Haul truck backed into a temporary retaining wall, causing a 10-foot section to collapse. No personnel in area.",
		"Drill rig contacted and damaged an underground communication conduit at 3-foot depth. Conduit was not marked.",
		"Concrete pump boom struck an overhead utility line support during setup. Pole cracked at the base.",
		"Equipment trailer rolled forward when parking brake failed, striking a tool container and denting the side wall.",
		"Forklift fork punctured a 250-gallon diesel tote during stacking operations. Approximately 15 gallons spilled before containment.",
	}
	envDescs := []string{
		"Approximately 5 gallons of diesel fuel spilled during refueling operations. Fuel reached the storm drain before containment.",
		"Concrete washwater overflowed containment berm and reached unpaved soil. Estimated 200 gallons of alkaline water released.",
		"Hydraulic fluid leak from an excavator dripped onto bare soil for approximately 2 hours before detection. Area approximately 10 square feet.",
		"Dust suppression system failed during demolition, releasing visible dust cloud beyond the site boundary. Adjacent businesses complained.",
		"Sediment from dewatering operations discharged into a drainage channel. Turbidity exceeded permitted levels downstream.",
		"Used oil drum was inadvertently punctured by a forklift, releasing approximately 8 gallons onto an impervious surface.",
		"Coolant from a generator leaked overnight, pooling near a catch basin. Approximately 3 gallons recovered.",
		"Paint overspray from bridge coating operations drifted beyond containment curtains onto a public sidewalk and two parked vehicles.",
	}
	vehicleDescs := []string{
		"Company van rear-ended at a red light during material transport. Driver reported minor neck stiffness. Other vehicle minor damage.",
		"Dump truck side-swiped a concrete barrier while navigating a tight curve. Mirror and side panel damaged.",
		"Pickup truck slid off an unpaved access road during rain. Vehicle came to rest in a shallow ditch. No injuries.",
		"Water truck driver failed to yield at a T-intersection, resulting in a low-speed collision with a delivery van. Both vehicles driveable.",
		"Haul truck tire blew out on Highway 71, forcing the driver onto the shoulder. Debris scattered across the travel lane.",
		"Utility vehicle rolled backward on a grade when the parking brake was not set. Vehicle struck a concrete barrier at low speed.",
		"Driver backed a flatbed truck into a gate post at the site entrance. Gate post bent and required replacement.",
		"Crew cab truck struck a deer on the access road at dusk. Front bumper and headlight damaged. No occupant injuries.",
	}
	fireDescs := []string{
		"Welding spark ignited cardboard debris near the workstation. Fire extinguished with a CO2 extinguisher within 2 minutes.",
		"Electrical fire started in a generator wiring harness. Smoke detector activated. Extinguished before fire department arrived.",
		"Overheated hydraulic fitting caused a small fire on an excavator engine compartment. Operator evacuated. Onboard suppression activated.",
		"Space heater in a field office ignited paper materials stored too close. Smoke alarm alerted occupants. Fire contained to one desk.",
		"Arc flash event during switchgear maintenance caused a brief fire inside the panel. Worker was outside the arc flash boundary.",
	}
	utilityDescs := []string{
		"Trenching crew struck an unmarked gas line at 4-foot depth. No ignition occurred. Gas company called immediately and area evacuated.",
		"Drill bit struck an unmarked water main at 6-foot depth. No injuries. Minor water service disruption to adjacent building for 4 hours.",
		"Excavator bucket severed a 2-inch telecommunications conduit during trench excavation. Service provider notified and conduit repaired same day.",
		"Horizontal directional drill contacted a power cable at 8-foot depth. Circuit breaker tripped. No injuries. Utility located 3 feet from plans.",
		"Vacuum excavation exposed and nicked a natural gas distribution line. Low-pressure leak detected by instrument. Area secured and gas company repaired.",
	}

	descsByType := map[string][]string{
		"Injury":          injuryDescs,
		"Near Miss":       nearMissDescs,
		"Property Damage": propDamageDescs,
		"Environmental":   envDescs,
		"Vehicle":         vehicleDescs,
		"Fire":            fireDescs,
		"Utility Strike":  utilityDescs,
	}

	immediateActionsByType := map[string][]string{
		"Injury": {
			"First aid applied on-site. Worker transported to urgent care. Area secured and supervisor notified.",
			"911 called. Worker transported to hospital. Work halted in area. Incident scene preserved.",
			"First aid kit used to treat wound. Worker escorted to company nurse. Supervisor completed initial report.",
			"Cold compress applied. Worker evaluated by on-site EMT. Returned to light duty pending medical follow-up.",
			"Area evacuated. Worker decontaminated per SDS. Eye wash station used for 15 minutes. Transported to ER.",
		},
		"Near Miss": {
			"Operations halted. Supervisor notified. Crew briefed on hazard. Work resumed after corrective measures.",
			"Work stopped. Hazard identified and communicated. Barrier installed before operations resumed.",
			"Equipment shut down. Spotter assigned. Pre-task briefing conducted before restart.",
			"Personnel cleared from area. Safety stand-down conducted. Additional controls implemented.",
			"Operations paused. Toolbox talk conducted addressing the near miss. Additional signage posted.",
		},
		"Property Damage": {
			"Area cordoned off. Damage photographed. Supervisor and safety coordinator notified.",
			"Equipment shut down. Damage assessed. Repair crew dispatched. Incident documented.",
			"Vehicles moved. Damage photographed and documented. Supervisor completed initial report.",
			"Area secured. Owner notified within 2 hours. Temporary repairs initiated.",
			"Operations halted. Third-party property owner contacted. Insurance claim initiated.",
		},
		"Environmental": {
			"Spill contained with absorbent booms. Environmental team notified. Drain plugged and area secured.",
			"Flow stopped. Soil scraped and bagged for disposal. Environmental coordinator notified of release.",
			"Leak source isolated. Absorbent pads deployed. Contaminated material collected in approved containers.",
			"Dust suppression reactivated. Adjacent property owners notified. Air monitoring initiated.",
			"Discharge stopped. Downstream sampling conducted. Regulatory agency notified per permit requirements.",
		},
		"Vehicle": {
			"Police notified. Drug test administered. Vehicle towed for inspection. Driver evaluated by medic.",
			"Vehicles pulled to shoulder. Hazard lights activated. Photos taken. Supervisor notified.",
			"Driver checked for injuries. Vehicle secured. Tow truck called. Incident report filed.",
			"Area traffic controlled. Vehicles moved to safe location. Drug and alcohol testing conducted.",
		},
		"Fire": {
			"Fire extinguished with CO2 extinguisher. Area evacuated briefly. Hot work permit reviewed.",
			"Power cut to affected area. Extinguished with dry chemical extinguisher. Fire department notified.",
			"Operator evacuated cab. Onboard suppression system activated. Fire department responded as precaution.",
			"Building evacuated per fire plan. Fire department arrived within 8 minutes. Area secured.",
		},
		"Utility Strike": {
			"Excavation halted. Area evacuated. Utility company and landowner notified. Line marked and secured.",
			"Drill stopped. Area cleared. Utility provider contacted for emergency repair. One-call ticket reviewed.",
			"Work stopped. Gas detector readings monitored. Gas company responded within 30 minutes. Area cordoned.",
			"Operations ceased. Circuit confirmed de-energized by utility. Repair scheduled. Area barricaded.",
		},
	}

	potentialSeverities := []string{"Low", "Medium", "High", "Critical", "Catastrophic"}

	// Injured person data pools
	personNames := []string{
		"Marcus Webb", "Diana Reyes", "Trevor Holt", "Geraldine Park", "Frank Espinoza",
		"Latasha Brown", "Kevin O'Brien", "Yuki Tanaka", "Ahmed Hassan", "Rosa Jimenez",
		"Derek Washington", "Mei-Lin Chang", "Patrick Sullivan", "Anita Desai", "Jorge Castillo",
		"Samantha Reed", "Victor Petrov", "Nkechi Okafor", "Bryan Mitchell", "Lucia Fernandez",
		"Robert Kowalski", "Priya Sharma", "Thomas Bergman", "Fatima Al-Rashid", "Chris Nakamura",
	}
	jobTitles := []string{
		"Equipment Operator", "Scaffold Worker", "Electrician", "Laborer", "Foreman",
		"Track Maintenance Worker", "Welder", "Pipe Fitter", "Crane Operator", "Signal Technician",
		"Heavy Equipment Mechanic", "Carpenter", "Iron Worker", "Safety Technician", "Truck Driver",
	}
	injuryTypes := []string{
		"Laceration", "Fracture", "Sprain/Strain", "Contusion/Bruise", "Burns",
		"Puncture Wound", "Crush Injury", "Electrical Shock", "Chemical Exposure",
		"Noise-Induced Hearing Loss", "Heat Exhaustion", "Eye Injury", "Dislocation",
	}
	bodyParts := []string{
		"Hand", "Wrist", "Ankle", "Knee", "Shoulder", "Back", "Head", "Foot",
		"Elbow", "Finger", "Arm", "Leg", "Eye", "Ear", "Neck", "Rib",
	}
	bodyPartSides := []string{"Left", "Right", "Both", "N/A"}
	treatmentTypes := []string{
		"First Aid", "Medical Treatment", "Hospitalization", "Observation Only",
	}
	returnStatuses := []string{
		"Returned Full Duty", "Returned Light Duty", "Returned Modified Duty",
		"On Medical Leave", "Pending Evaluation",
	}

	// Contributing factor data pools
	factorTypes := []string{"People", "Equipment", "Environmental", "Procedural", "Management/Organizational"}
	factorDescs := map[string][]string{
		"People": {
			"Worker did not follow established safety procedure for the task.",
			"Inadequate training on hazard recognition for the specific work activity.",
			"Fatigue from extended shift contributed to lapse in attention.",
			"Worker removed safety device without authorization or risk assessment.",
			"Insufficient situational awareness in a high-hazard area.",
			"Complacency from performing repetitive tasks led to shortcut-taking.",
		},
		"Equipment": {
			"Safety guard was removed or bypassed on the equipment.",
			"Equipment maintenance was overdue per the PM schedule.",
			"No in-cab documentation available to operator for utility locations.",
			"Exclusion zone signage not installed around sensitive structures.",
			"Warning device on equipment was non-functional at time of incident.",
			"Tool or equipment was not rated for the task being performed.",
		},
		"Environmental": {
			"Wet or icy surface conditions contributed to the slip/trip hazard.",
			"Poor lighting in the work area reduced visibility of hazards.",
			"Wind conditions exceeded safe limits for the elevated work.",
			"Excessive noise levels masked warning signals from equipment.",
			"Aged utility infrastructure was not reflected in available records.",
			"Extreme heat conditions contributed to worker fatigue.",
		},
		"Procedural": {
			"Work procedure did not address the specific hazard encountered.",
			"Pre-task briefing did not cover the changed site conditions.",
			"Lockout/tagout procedure was not followed for the energy source.",
			"Ground disturbance permit process lacked comprehensive utility verification.",
			"Backing procedure allowed single-person reversal without a spotter.",
			"Scaffold inspection checklist was out of date and missing key items.",
			"Hot work permit did not verify combustible material clearance distance.",
		},
		"Management/Organizational": {
			"No formal change communication protocol for active operations.",
			"Staffing levels were insufficient for the scope of work.",
			"Sub-contractor safety standards were not verified against company requirements.",
			"Production pressure contributed to shortcuts in safety procedures.",
			"Safety training records were not verified before task assignment.",
			"Incident investigation findings were not communicated to similar work crews.",
		},
	}

	// Witness data pools
	witnessNames := []string{
		"Larry Gomez", "Priya Nair", "Ben Hartley", "Rosa Delgado", "Steve Martinez",
		"Karen Thompson", "Wayne Jeffries", "Linda Chow", "Mike Brennan", "Sandra Osei",
		"Tony Russo", "Angela Wright", "Chris Johansson", "Maria Gutierrez", "David Chen",
		"Patricia Miller", "Robert Jackson", "Jennifer Lee", "Thomas Wilson", "Nancy Davis",
	}
	witnessTitles := []string{
		"General Foreman", "Safety Technician", "Track Supervisor", "Safety Observer",
		"Equipment Operator", "Crew Leader", "Superintendent", "Field Engineer",
		"Quality Inspector", "Environmental Specialist",
	}
	witnessEmployers := []string{
		"Herzog Technologies Inc.", "Apex Scaffold LLC", "BNSF Railway", "Union Pacific",
		"Metro Construction Corp", "Eagle Environmental Services", "National Signal Co.",
	}

	// Five Why data pools (question/answer templates per incident type category)
	type fiveWhyTemplate struct {
		question string
		answer   string
		evidence string
	}
	fiveWhyTemplates := map[string][]fiveWhyTemplate{
		"Injury": {
			{"Why did the worker sustain an injury?", "The worker was exposed to the hazard without adequate protection.", "Incident report; witness statements."},
			{"Why was the worker exposed to the hazard?", "Existing controls were insufficient or bypassed.", "Site inspection findings; control assessment."},
			{"Why were the controls insufficient?", "The hazard was not fully identified in the pre-task planning.", "Job Hazard Analysis review; pre-task briefing records."},
			{"Why was the hazard not identified?", "The JHA had not been updated for current site conditions.", "JHA revision history; site change log."},
			{"Why was the JHA not updated?", "No process exists to trigger JHA review when site conditions change.", "Procedure document review; management interviews."},
		},
		"Near Miss": {
			{"Why did the near miss occur?", "Personnel or equipment entered a hazard zone unexpectedly.", "Site layout; witness accounts."},
			{"Why did personnel enter the hazard zone?", "Barriers or warning systems were not in place or not effective.", "Site inspection photos; barricade records."},
			{"Why were barriers not effective?", "The work plan did not account for the interaction between tasks.", "Work plan review; scheduling records."},
			{"Why was the interaction not planned for?", "The planning process does not require concurrent activity risk assessment.", "Planning SOP review; project schedule."},
			{"Why is there no concurrent activity assessment?", "The SOP was written for single-trade operations only.", "SOP revision history; management interviews."},
		},
		"Property Damage": {
			{"Why was the property damaged?", "Equipment operated outside the defined work limits.", "Survey records; equipment GPS data."},
			{"Why did equipment exceed work limits?", "The operator did not have current as-built drawings showing the obstruction.", "Operator interview; drawing transmittal log."},
			{"Why were drawings not current?", "The last survey update did not capture the as-built condition.", "Survey date records; change order log."},
			{"Why was the survey not updated?", "No requirement exists to update surveys before each work phase.", "Permit SOP review; project controls records."},
			{"Why is there no update requirement?", "The ground disturbance procedure was last revised before this project type was common.", "Procedure revision history."},
		},
		"Environmental": {
			{"Why did the release occur?", "Containment capacity was exceeded or breached.", "Containment inspection records; volume calculations."},
			{"Why was containment exceeded?", "The volume of material handled was greater than containment was designed for.", "Design specifications; operational logs."},
			{"Why was containment undersized?", "Original design was based on outdated operational assumptions.", "Design basis documents; current throughput data."},
			{"Why were assumptions not updated?", "No periodic review of containment adequacy is required.", "Environmental management plan review."},
			{"Why is there no periodic review?", "The environmental management plan lacks a scheduled reassessment trigger.", "Plan revision history; management interviews."},
		},
		"Vehicle": {
			{"Why did the vehicle incident occur?", "The driver did not see the obstacle or other vehicle in time.", "Driver interview; dash cam footage."},
			{"Why was the obstacle not seen?", "Blind spots and lack of spotter contributed to limited visibility.", "Vehicle specification; mirror configuration."},
			{"Why was no spotter used?", "The driving procedure did not require a spotter for this maneuver.", "Driving SOP review."},
			{"Why does the procedure not require a spotter?", "The procedure was written for open-area operations, not confined site conditions.", "Procedure scope analysis."},
		},
		"Fire": {
			{"Why did the fire start?", "An ignition source contacted combustible material.", "Fire investigation report; scene photos."},
			{"Why was combustible material near the ignition source?", "Housekeeping standards were not enforced in the work area.", "Area inspection records; housekeeping checklist."},
			{"Why were housekeeping standards not enforced?", "Pre-work inspection did not verify combustible clearance.", "Hot work permit checklist review."},
			{"Why was clearance not verified?", "The hot work permit checklist did not include a combustible material sweep requirement.", "Permit template review; procedure document."},
		},
		"Utility Strike": {
			{"Why was the utility struck?", "The utility was not marked or was inaccurately located on site plans.", "Locate ticket records; as-built drawings."},
			{"Why was the utility not accurately located?", "The one-call response did not identify all utilities in the work zone.", "One-call response records; utility owner records."},
			{"Why was the one-call response incomplete?", "Some utilities were installed after the most recent survey or mapping update.", "Survey dates; utility installation records."},
			{"Why were post-survey installations not captured?", "No requirement to verify locate completeness against multiple data sources.", "Ground disturbance permit SOP review."},
			{"Why is there no verification requirement?", "The permit process relies solely on one-call as the utility identification method.", "Permit procedure review; industry best practice comparison."},
		},
	}

	// CAPA data pools
	capaCategories := []string{"Training", "Procedure Change", "Engineering Control", "PPE", "Equipment Modification", "Policy Change", "Other"}
	capaPriorities := []string{"Critical", "High", "Medium", "Low"}
	capaDescs := map[string][]string{
		"Training": {
			"Mandatory refresher training on hazard recognition and PPE requirements for all workers in the affected division.",
			"Conduct toolbox talk series on the specific hazard type for all field crews over the next 30 days.",
			"Require competent person training for all supervisors overseeing the affected work activity.",
			"Implement equipment-specific operator qualification program with annual recertification.",
			"Develop and deliver a safety stand-down training addressing the root cause findings.",
		},
		"Procedure Change": {
			"Revise the work procedure to include a mandatory verification step before commencing the task.",
			"Update the pre-task briefing template to require explicit discussion of the identified hazard.",
			"Implement a formal change notification protocol requiring all permit holders to acknowledge changes within 2 hours.",
			"Revise the ground disturbance permit to require 100% utility locate verification before issuance.",
			"Update the backing procedure to require a spotter for all reversing maneuvers on site.",
			"Add a mandatory concurrent activity risk assessment to the daily planning process.",
		},
		"Engineering Control": {
			"Install physical barricades separating equipment operating zones from pedestrian routes.",
			"Install vibration monitoring at all sensitive structures within 50 feet of compaction operations.",
			"Replace soil berm with poured concrete containment wall minimum 18 inches tall.",
			"Install proximity detection system on mobile equipment operating near personnel.",
			"Upgrade lighting in the work area to a minimum of 50 foot-candles at task level.",
			"Install secondary containment around all fuel and chemical storage areas.",
		},
		"PPE": {
			"Require tethering systems for all tools and materials handled above 10-foot elevation.",
			"Mandate cut-resistant gloves for all cutting tool operations.",
			"Require face shields in addition to safety glasses for all chemical transfer tasks.",
			"Upgrade hearing protection requirements from optional to mandatory in all high-noise areas.",
			"Issue arc-flash rated PPE to all workers performing electrical maintenance tasks.",
		},
		"Equipment Modification": {
			"Install backup cameras and audible alarms on all vehicles used on site.",
			"Retrofit all cutting tools with integrated blade guards that cannot be removed without a tool.",
			"Install flow limiters on all fuel dispensing nozzles to prevent overfill.",
			"Add guardrail attachment points to all scaffold frames per OSHA 1926.451.",
			"Install automatic shut-off valves on all hydraulic quick-connect fittings.",
		},
		"Policy Change": {
			"Require as-built drawing updates every 2 years and before ground disturbance permits on projects over 6 months.",
			"Implement mandatory drug and alcohol testing within 2 hours of all vehicle incidents.",
			"Establish a sub-contractor safety pre-qualification program with annual re-evaluation.",
			"Create a formal stop-work authority policy empowering all workers to halt unsafe conditions.",
			"Require management of change review for all site layout modifications affecting active work permits.",
		},
		"Other": {
			"Establish a cross-functional safety committee to review similar incidents quarterly.",
			"Commission an independent third-party audit of the affected work process.",
			"Implement a near-miss reporting incentive program to improve early hazard identification.",
		},
	}
	capaVerificationMethods := []string{
		"Field observation audit over 30-day period.",
		"Procedure document review and compliance check.",
		"Training attendance records and post-assessment results.",
		"Physical inspection of installed engineering control.",
		"Review of 10 consecutive permits for compliance.",
		"Spot audits of work operations over 60-day period.",
		"Management walk-through and worker interviews.",
	}

	// -------------------------------------------------------------------------
	// Weighted random selection helper
	// -------------------------------------------------------------------------
	weightedPick := func(items []string, weights []int) string {
		total := 0
		for _, w := range weights {
			total += w
		}
		r := rng.Intn(total)
		cumulative := 0
		for i, w := range weights {
			cumulative += w
			if r < cumulative {
				return items[i]
			}
		}
		return items[len(items)-1]
	}

	// Map severity labels to incident severity field values
	sevToSeverity := map[string]string{
		"Fatality":          "Critical",
		"Lost Time":         "Critical",
		"Medical Treatment": "High",
		"First Aid":         "Medium",
		"Near Miss":         "Low",
	}

	// -------------------------------------------------------------------------
	// Generate 110 incidents
	// -------------------------------------------------------------------------
	numIncidents := 110
	incidents := make([]*models.Incident, 0, numIncidents)
	intendedDraft := make(map[uint]bool) // saves intended IsDraft before GORM mutates it

	for i := 0; i < numIncidents; i++ {
		incType := weightedPick(incidentTypes, typeWeights)
		sevLabel := weightedPick(severities, sevWeights)
		sev := sevToSeverity[sevLabel]
		div := pick(divisions)
		proj := pick(projects)
		loc := pick(locations)
		date := randDate(12)
		shift := pick(shifts)
		weather := pick(weathers)
		reporterID := pick(reporters)

		// Status distribution
		status := pick(statuses)
		isDraft := false
		completion := 40 + rng.Intn(61) // 40-100

		// ~15% drafts
		if rng.Float64() < 0.15 {
			isDraft = true
			status = "Draft"
			completion = 20 + rng.Intn(40) // 20-59
		}

		// OSHA/DART: ~20% OSHA recordable, ~10% DART (only for non-near-miss)
		var isOsha, isDart *bool
		if !isDraft && incType != "Near Miss" {
			oshaVal := rng.Float64() < 0.20
			isOsha = boolPtr(oshaVal)
			if oshaVal {
				dartVal := rng.Float64() < 0.50 // 50% of OSHA = ~10% overall
				isDart = boolPtr(dartVal)
			} else {
				isDart = boolPtr(false)
			}
		}
		if incType == "Near Miss" {
			isOsha = boolPtr(false)
			isDart = boolPtr(false)
		}

		// Closed incidents get 100%
		if status == "Closed" {
			completion = 100
		}

		// Railroad property: ~12% of incidents
		isRailroad := rng.Float64() < 0.12
		var rrClient string
		var rrNotified bool
		var rrNotifDate *time.Time
		var rrNotifMethod string
		var rrNotifOverdue bool

		if isRailroad {
			rrClient = pick(railroads)
			if rng.Float64() < 0.7 { // 70% notified
				rrNotified = true
				rrNotifDate = timePtr(date.Add(time.Duration(30+rng.Intn(120)) * time.Minute))
				rrNotifMethod = pick(notifMethods)
				rrNotifOverdue = false
			} else {
				rrNotified = false
				rrNotifOverdue = true
			}
		}

		// Description and immediate actions
		descs := descsByType[incType]
		desc := descs[rng.Intn(len(descs))]
		actions := immediateActionsByType[incType]
		action := actions[rng.Intn(len(actions))]

		potSev := pick(potentialSeverities)
		lat := pickFloat(41.860, 41.930)
		lon := pickFloat(-87.730, -87.610)

		inc := &models.Incident{
			Type:                        incType,
			Date:                        date,
			Location:                    loc,
			Latitude:                    lat,
			Longitude:                   lon,
			Division:                    div,
			ProjectJobSite:              proj,
			Description:                 desc,
			ImmediateActions:            action,
			Severity:                    sev,
			PotentialSeverity:           potSev,
			Shift:                       shift,
			Weather:                     weather,
			Status:                      status,
			ReporterID:                  reporterID,
			IsDraft:                     isDraft,
			CompletionPercent:           completion,
			IsOshaRecordable:            isOsha,
			IsDart:                      isDart,
			IsRailroadProperty:          isRailroad,
			RailroadClient:              rrClient,
			RailroadNotified:            rrNotified,
			RailroadNotificationDate:    rrNotifDate,
			RailroadNotificationMethod:  rrNotifMethod,
			RailroadNotificationOverdue: rrNotifOverdue,
		}
		incidents = append(incidents, inc)
	}

	for _, inc := range incidents {
		wantDraft := inc.IsDraft // save before GORM mutates it
		if err := db.Create(inc).Error; err != nil {
			log.Printf("Seed: failed to create incident: %v", err)
		}
		intendedDraft[inc.ID] = wantDraft
	}
	log.Printf("Seed: created %d incidents", len(incidents))

	// Bulk fix: GORM ignores false bool on INSERT when column has default:true,
	// AND mutates the struct so IsDraft becomes true after Create. Use the
	// saved intendedDraft map to determine which should be false.
	var nonDraftIDs []uint
	for _, inc := range incidents {
		if intended, ok := intendedDraft[inc.ID]; ok && !intended {
			nonDraftIDs = append(nonDraftIDs, inc.ID)
		}
	}
	if len(nonDraftIDs) > 0 {
		if err := db.Exec("UPDATE incidents SET is_draft = false WHERE id IN ?", nonDraftIDs).Error; err != nil {
			log.Printf("Seed: failed to bulk-fix is_draft: %v", err)
		} else {
			log.Printf("Seed: fixed is_draft=false for %d incidents", len(nonDraftIDs))
		}
	}

	// -------------------------------------------------------------------------
	// Injured Persons — for Injury-type incidents that are not drafts
	// -------------------------------------------------------------------------
	injuredCount := 0
	for _, inc := range incidents {
		if inc.Type != "Injury" || intendedDraft[inc.ID] {
			continue
		}
		numPersons := 1 + rng.Intn(2) // 1-2 injured per incident
		for j := 0; j < numPersons; j++ {
			ip := models.InjuredPerson{
				IncidentID:         inc.ID,
				Name:               pick(personNames),
				JobTitle:           pick(jobTitles),
				Division:           inc.Division,
				InjuryType:         mustEncrypt(pick(injuryTypes)),
				BodyPart:           mustEncrypt(pick(bodyParts)),
				BodyPartSide:       pick(bodyPartSides),
				TreatmentType:      mustEncrypt(pick(treatmentTypes)),
				ReturnToWorkStatus: mustEncrypt(pick(returnStatuses)),
			}
			db.Create(&ip)
			injuredCount++
		}
	}
	log.Printf("Seed: created %d injured persons", injuredCount)

	// -------------------------------------------------------------------------
	// Investigations (45) — linked to non-draft, non-Reported incidents
	// -------------------------------------------------------------------------
	eligibleForInvestigation := make([]*models.Incident, 0)
	for _, inc := range incidents {
		wasDraft := intendedDraft[inc.ID]
		if !wasDraft && inc.Status != "Reported" && inc.Status != "Draft" {
			eligibleForInvestigation = append(eligibleForInvestigation, inc)
		}
	}

	// Shuffle and pick up to 45
	rng.Shuffle(len(eligibleForInvestigation), func(i, j int) {
		eligibleForInvestigation[i], eligibleForInvestigation[j] = eligibleForInvestigation[j], eligibleForInvestigation[i]
	})
	numInvestigations := 45
	if numInvestigations > len(eligibleForInvestigation) {
		numInvestigations = len(eligibleForInvestigation)
	}

	invStatuses := []string{"In Progress", "Completed", "Approved", "Returned"}
	investigations := make([]*models.Investigation, 0, numInvestigations)

	for i := 0; i < numInvestigations; i++ {
		inc := eligibleForInvestigation[i]
		invStatus := pick(invStatuses)
		leadInv := pick(coordinators)
		assignedBy := pick(managers)

		targetDate := inc.Date.AddDate(0, 0, 14+rng.Intn(21)) // 14-34 days after incident
		var actualDate *time.Time
		var reviewedBy string
		var reviewComments string
		var reviewDate *time.Time
		isOverdue := false
		escalation := 0

		// ~30% overdue
		if rng.Float64() < 0.30 {
			isOverdue = true
			targetDate = now.AddDate(0, 0, -(7 + rng.Intn(60))) // target in the past
			daysPast := int(now.Sub(targetDate).Hours() / 24)
			if daysPast < 7 {
				escalation = 1
			} else if daysPast < 14 {
				escalation = 2
			} else {
				escalation = 3
			}
			invStatus = "In Progress" // overdue investigations are still in progress
		}

		if invStatus == "Approved" || invStatus == "Completed" {
			ad := targetDate.AddDate(0, 0, -rng.Intn(7))
			actualDate = &ad
			reviewedBy = pick(managers)
			reviewComments = "Investigation findings are thorough. Root cause analysis is well supported by evidence."
			rd := ad.AddDate(0, 0, 1+rng.Intn(3))
			reviewDate = &rd
			isOverdue = false
			escalation = 0
		}
		if invStatus == "Returned" {
			reviewedBy = pick(managers)
			reviewComments = "Additional witness statements needed. Please expand the contributing factors analysis."
			rd := now.AddDate(0, 0, -(3 + rng.Intn(10)))
			reviewDate = &rd
		}

		// Team members: 1-3 users
		numTeam := 1 + rng.Intn(3)
		teamIDs := make([]string, 0, numTeam)
		available := make([]string, len(assignees))
		copy(available, assignees)
		for t := 0; t < numTeam && len(available) > 0; t++ {
			idx := rng.Intn(len(available))
			teamIDs = append(teamIDs, available[idx])
			available = append(available[:idx], available[idx+1:]...)
		}
		teamJSON := "["
		for ti, tid := range teamIDs {
			if ti > 0 {
				teamJSON += ","
			}
			teamJSON += fmt.Sprintf(`"%s"`, tid)
		}
		teamJSON += "]"

		inv := &models.Investigation{
			IncidentID:             inc.ID,
			LeadInvestigatorID:     leadInv,
			TeamMembers:            teamJSON,
			TargetCompletionDate:   targetDate,
			ActualCompletionDate:   actualDate,
			Status:                 invStatus,
			AssignedBy:             assignedBy,
			ReviewedBy:             reviewedBy,
			ReviewComments:         reviewComments,
			ReviewDate:             reviewDate,
			IsOverdue:              isOverdue,
			OverdueEscalationLevel: escalation,
		}
		investigations = append(investigations, inv)
	}

	for _, inv := range investigations {
		if err := db.Create(inv).Error; err != nil {
			log.Printf("Seed: failed to create investigation: %v", err)
		}
	}
	log.Printf("Seed: created %d investigations", len(investigations))

	// -------------------------------------------------------------------------
	// Five Whys — 3-5 per investigation
	// -------------------------------------------------------------------------
	fiveWhyCount := 0
	for _, inv := range investigations {
		// Find incident type for this investigation
		var incType string
		for _, inc := range incidents {
			if inc.ID == inv.IncidentID {
				incType = inc.Type
				break
			}
		}
		templates, ok := fiveWhyTemplates[incType]
		if !ok {
			templates = fiveWhyTemplates["Near Miss"] // fallback
		}

		numWhys := 3 + rng.Intn(3) // 3-5
		if numWhys > len(templates) {
			numWhys = len(templates)
		}

		for w := 0; w < numWhys; w++ {
			fw := models.FiveWhy{
				InvestigationID: inv.ID,
				Level:           w + 1,
				Question:        templates[w].question,
				Answer:          templates[w].answer,
				Evidence:        templates[w].evidence,
				SortOrder:       w + 1,
			}
			db.Create(&fw)
			fiveWhyCount++
		}
	}
	log.Printf("Seed: created %d five-why entries", fiveWhyCount)

	// -------------------------------------------------------------------------
	// Contributing Factors — 1 primary + 1-2 additional per investigation
	// -------------------------------------------------------------------------
	cfCount := 0
	for _, inv := range investigations {
		numFactors := 2 + rng.Intn(2) // 2-3 factors
		usedTypes := make(map[string]bool)

		for f := 0; f < numFactors; f++ {
			ft := pick(factorTypes)
			// Avoid duplicate factor types
			for usedTypes[ft] && f < 10 {
				ft = pick(factorTypes)
			}
			usedTypes[ft] = true

			descs := factorDescs[ft]
			cf := models.ContributingFactor{
				InvestigationID:   inv.ID,
				FactorType:        ft,
				FactorDescription: descs[rng.Intn(len(descs))],
				IsPrimary:         f == 0, // first one is primary
			}
			db.Create(&cf)
			cfCount++
		}
	}
	log.Printf("Seed: created %d contributing factors", cfCount)

	// -------------------------------------------------------------------------
	// Witness Statements — 2-3 per investigation
	// -------------------------------------------------------------------------
	wsCount := 0
	for _, inv := range investigations {
		numWitnesses := 2 + rng.Intn(2) // 2-3
		usedNames := make(map[string]bool)

		for w := 0; w < numWitnesses; w++ {
			wn := pick(witnessNames)
			for usedNames[wn] {
				wn = pick(witnessNames)
			}
			usedNames[wn] = true

			// Find the incident for date context
			var incDate time.Time
			for _, inc := range incidents {
				if inc.ID == inv.IncidentID {
					incDate = inc.Date
					break
				}
			}

			ws := models.WitnessStatement{
				InvestigationID: inv.ID,
				WitnessName:     wn,
				WitnessTitle:    pick(witnessTitles),
				WitnessEmployer: pick(witnessEmployers),
				WitnessPhone:    fmt.Sprintf("312-555-%04d", 100+rng.Intn(9900)),
				StatementText:   fmt.Sprintf("I was in the area when the incident occurred. I observed the conditions described in the report. The response was appropriate and timely. I have no additional information beyond what has been documented."),
				CollectionDate:  incDate.AddDate(0, 0, 1+rng.Intn(5)),
				CollectorName:   pick([]string{"J. Martinez", "S. Patel", "R. Chen", "K. Williams", "T. Rodriguez"}),
			}
			db.Create(&ws)
			wsCount++
		}
	}
	log.Printf("Seed: created %d witness statements", wsCount)

	// -------------------------------------------------------------------------
	// CAPAs (70 total) — linked to investigations
	// -------------------------------------------------------------------------
	capaStatuses := []string{"Open", "In Progress", "Completed", "Verification Pending", "Verified Effective", "Verified Ineffective"}
	capas := make([]*models.CAPA, 0, 70)

	// Generate 1-2 CAPAs per investigation, plus some direct CAPAs from incidents
	for _, inv := range investigations {
		numCapas := 1 + rng.Intn(2) // 1-2 per investigation
		for c := 0; c < numCapas; c++ {
			capaType := "Corrective"
			if rng.Float64() < 0.40 {
				capaType = "Preventive"
			}
			cat := pick(capaCategories)
			descs := capaDescs[cat]
			desc := descs[rng.Intn(len(descs))]
			pri := pick(capaPriorities)
			status := pick(capaStatuses)

			// Find the incident ID
			var incID uint
			for _, inc := range incidents {
				if inc.ID == inv.IncidentID {
					incID = inc.ID
					break
				}
			}

			dueDate := inv.TargetCompletionDate.AddDate(0, 0, 14+rng.Intn(30))
			assignedTo := pick(assignees)
			assignedBy := pick(managers)

			var completionDate *time.Time
			var completionNotes, completionEvidence string
			var verificationDueDate *time.Time
			var verifiedBy string
			var verificationDate *time.Time
			var verificationNotes, verificationMethod string
			isOverdue := false
			escalation := 0

			// ~25% overdue
			if rng.Float64() < 0.25 && status != "Verified Effective" && status != "Verified Ineffective" && status != "Completed" {
				isOverdue = true
				dueDate = now.AddDate(0, 0, -(5 + rng.Intn(45)))
				daysPast := int(now.Sub(dueDate).Hours() / 24)
				if daysPast < 7 {
					escalation = 1
				} else if daysPast < 14 {
					escalation = 2
				} else {
					escalation = 3
				}
				if status == "Verified Effective" || status == "Verified Ineffective" {
					status = "In Progress"
				}
			}

			verificationMethod = pick(capaVerificationMethods)

			if status == "Completed" || status == "Verification Pending" || status == "Verified Effective" || status == "Verified Ineffective" {
				cd := dueDate.AddDate(0, 0, -rng.Intn(10))
				completionDate = &cd
				completionNotes = "Action completed as described. Documentation updated and distributed to affected personnel."
				completionEvidence = "Updated procedure document; training records; field inspection photos"
				vd := cd.AddDate(0, 1, rng.Intn(30))
				verificationDueDate = &vd
				isOverdue = false
				escalation = 0
			}

			if status == "Verified Effective" || status == "Verified Ineffective" {
				verifiedBy = pick(managers)
				vd := completionDate.AddDate(0, 0, 30+rng.Intn(30))
				verificationDate = &vd
				if status == "Verified Effective" {
					verificationNotes = "Verification confirmed the corrective action is effective. No recurrence observed during the monitoring period."
				} else {
					verificationNotes = "Verification determined the action was not fully effective. Additional measures required."
				}
			}

			capa := &models.CAPA{
				InvestigationID:        inv.ID,
				IncidentID:             incID,
				Type:                   capaType,
				Category:               cat,
				Description:            desc,
				AssignedToUserID:       assignedTo,
				AssignedByUserID:       assignedBy,
				DueDate:                dueDate,
				Priority:               pri,
				VerificationMethod:     verificationMethod,
				VerificationDueDate:    verificationDueDate,
				Status:                 status,
				CompletionNotes:        completionNotes,
				CompletionEvidence:     completionEvidence,
				CompletionDate:         completionDate,
				VerifiedByUserID:       verifiedBy,
				VerificationDate:       verificationDate,
				VerificationNotes:      verificationNotes,
				IsOverdue:              isOverdue,
				OverdueEscalationLevel: escalation,
			}
			capas = append(capas, capa)
		}
	}

	for _, c := range capas {
		if err := db.Create(c).Error; err != nil {
			log.Printf("Seed: failed to create CAPA: %v", err)
		}
	}
	log.Printf("Seed: created %d CAPAs", len(capas))

	// -------------------------------------------------------------------------
	// Incident Links — 4-5 clusters of 3-4 incidents each
	// -------------------------------------------------------------------------
	similarityTypes := []string{"Same Location", "Same Type", "Same Root Cause", "Same Equipment", "Same Person"}
	linkNotes := []string{
		"These incidents share a common contributing factor related to inadequate pre-task planning.",
		"Both incidents occurred in the same work area under similar conditions.",
		"Root cause analysis reveals the same procedural gap in both incidents.",
		"Equipment involved in both incidents had similar maintenance deficiencies.",
		"The same worker was involved in both incidents, suggesting a training need.",
		"Similar environmental conditions contributed to both incidents.",
		"Both incidents involved the same sub-contractor crew.",
	}

	linkCount := 0
	// Create 5 clusters, each linking 3 incidents
	nonDraftIncidents := make([]*models.Incident, 0)
	for _, inc := range incidents {
		if !intendedDraft[inc.ID] {
			nonDraftIncidents = append(nonDraftIncidents, inc)
		}
	}

	rng.Shuffle(len(nonDraftIncidents), func(i, j int) {
		nonDraftIncidents[i], nonDraftIncidents[j] = nonDraftIncidents[j], nonDraftIncidents[i]
	})

	// 5 clusters of 3 incidents = 15 links (3 pairs per cluster)
	clusterSize := 3
	numClusters := 5
	for cl := 0; cl < numClusters && cl*clusterSize+clusterSize <= len(nonDraftIncidents); cl++ {
		clusterStart := cl * clusterSize
		for i := 0; i < clusterSize; i++ {
			for j := i + 1; j < clusterSize; j++ {
				id1 := nonDraftIncidents[clusterStart+i].ID
				id2 := nonDraftIncidents[clusterStart+j].ID
				if id1 > id2 {
					id1, id2 = id2, id1
				}
				link := models.IncidentLink{
					IncidentID1:    id1,
					IncidentID2:    id2,
					SimilarityType: pick(similarityTypes),
					Notes:          pick(linkNotes),
					LinkedByUserID: pick(coordinators),
				}
				db.Create(&link)
				linkCount++
			}
		}
	}
	log.Printf("Seed: created %d incident links", linkCount)

	// -------------------------------------------------------------------------
	// Notifications — for overdue items and review requests
	// -------------------------------------------------------------------------
	notifCount := 0

	// Overdue investigation notifications
	for _, inv := range investigations {
		if inv.IsOverdue {
			n := models.Notification{
				UserID:          pick(managers),
				Title:           fmt.Sprintf("Investigation Overdue (Incident #%d)", inv.IncidentID),
				Message:         fmt.Sprintf("Investigation for incident #%d has passed its target completion date. Escalation level: %d.", inv.IncidentID, inv.OverdueEscalationLevel),
				Type:            "overdue_investigation",
				EntityType:      "investigation",
				EntityID:        inv.ID,
				EscalationLevel: inv.OverdueEscalationLevel,
				IsRead:          rng.Float64() < 0.3,
			}
			db.Create(&n)
			notifCount++
		}
	}

	// Overdue CAPA notifications
	for _, c := range capas {
		if c.IsOverdue {
			n := models.Notification{
				UserID:          c.AssignedToUserID,
				Title:           fmt.Sprintf("CAPA Overdue: %s (Incident #%d)", c.Category, c.IncidentID),
				Message:         fmt.Sprintf("CAPA for incident #%d is past due. Priority: %s. Please update status or request extension.", c.IncidentID, c.Priority),
				Type:            "overdue_capa",
				EntityType:      "capa",
				EntityID:        c.ID,
				EscalationLevel: c.OverdueEscalationLevel,
				IsRead:          rng.Float64() < 0.2,
			}
			db.Create(&n)
			notifCount++
		}
	}

	// Railroad notification overdue
	for _, inc := range incidents {
		if inc.IsRailroadProperty && inc.RailroadNotificationOverdue {
			n := models.Notification{
				UserID:          pick(managers),
				Title:           fmt.Sprintf("Railroad Notification Overdue: %s (Incident #%d)", inc.RailroadClient, inc.ID),
				Message:         fmt.Sprintf("Incident on %s railroad property has not been reported within the required timeframe.", inc.RailroadClient),
				Type:            "railroad_notification",
				EntityType:      "incident",
				EntityID:        inc.ID,
				EscalationLevel: 1,
				IsRead:          false,
			}
			db.Create(&n)
			notifCount++
		}
	}

	// Review request notifications for Under Review investigations
	for _, inv := range investigations {
		if inv.Status == "Completed" || inv.Status == "Approved" {
			n := models.Notification{
				UserID:          pick(managers),
				Title:           fmt.Sprintf("Investigation Ready for Review (Incident #%d)", inv.IncidentID),
				Message:         "Investigation has been submitted for review by the lead investigator.",
				Type:            "review_request",
				EntityType:      "investigation",
				EntityID:        inv.ID,
				EscalationLevel: 0,
				IsRead:          true,
			}
			db.Create(&n)
			notifCount++
		}
	}
	log.Printf("Seed: created %d notifications", notifCount)

	// -------------------------------------------------------------------------
	// Audit Log Entries — representative history
	// -------------------------------------------------------------------------
	auditActions := []string{"create", "update", "status_change", "approve", "reject", "assign", "verify"}
	auditLogs := make([]models.AuditLog, 0, 200)

	// Incident creation entries
	for _, inc := range incidents {
		auditLogs = append(auditLogs, models.AuditLog{
			Timestamp:  inc.Date,
			UserID:     inc.ReporterID,
			UserRole:   "field_reporter",
			Action:     "create",
			EntityType: "incident",
			EntityID:   inc.ID,
			Before:     "",
			After:      fmt.Sprintf(`{"type":"%s","status":"%s","division":"%s"}`, inc.Type, inc.Status, inc.Division),
			Notes:      "Incident reported",
		})
	}

	// Investigation assignment entries
	for _, inv := range investigations {
		auditLogs = append(auditLogs, models.AuditLog{
			Timestamp:  inv.CreatedAt,
			UserID:     inv.AssignedBy,
			UserRole:   "safety_manager",
			Action:     "assign",
			EntityType: "investigation",
			EntityID:   inv.ID,
			Before:     "",
			After:      fmt.Sprintf(`{"status":"%s","leadInvestigatorId":"%s"}`, inv.Status, inv.LeadInvestigatorID),
			Notes:      "Investigation assigned",
		})
	}

	// CAPA lifecycle entries
	for _, c := range capas {
		auditLogs = append(auditLogs, models.AuditLog{
			Timestamp:  c.CreatedAt,
			UserID:     c.AssignedByUserID,
			UserRole:   "safety_manager",
			Action:     "create",
			EntityType: "capa",
			EntityID:   c.ID,
			Before:     "",
			After:      fmt.Sprintf(`{"type":"%s","priority":"%s","status":"%s"}`, c.Type, c.Priority, c.Status),
			Notes:      "CAPA created",
		})
		if c.Status == "Verified Effective" || c.Status == "Verified Ineffective" {
			auditLogs = append(auditLogs, models.AuditLog{
				Timestamp:  *c.VerificationDate,
				UserID:     c.VerifiedByUserID,
				UserRole:   "safety_manager",
				Action:     "verify",
				EntityType: "capa",
				EntityID:   c.ID,
				Before:     `{"status":"Verification Pending"}`,
				After:      fmt.Sprintf(`{"status":"%s"}`, c.Status),
				Notes:      c.VerificationNotes,
			})
		}
	}

	// A few status change and settings audit entries
	auditLogs = append(auditLogs, models.AuditLog{
		Timestamp:  now.AddDate(0, -2, 0),
		UserID:     uid(admin.ID),
		UserRole:   "admin",
		Action:     "update",
		EntityType: "setting",
		EntityID:   1,
		Before:     `{"key":"trir_benchmark","value":"3.5"}`,
		After:      `{"key":"trir_benchmark","value":"3.0"}`,
		Notes:      "Benchmark adjusted to industry average",
	})

	// Suppress unused variable warning for auditActions
	_ = auditActions

	db.Create(&auditLogs)
	log.Printf("Seed: created %d audit log entries", len(auditLogs))

	log.Println("Seed: demo data populated successfully")
	log.Printf("Seed: Summary — %d incidents, %d injured persons, %d investigations, %d five-whys, %d contributing factors, %d witness statements, %d CAPAs, %d links, %d notifications, %d audit logs",
		len(incidents), injuredCount, len(investigations), fiveWhyCount, cfCount, wsCount, len(capas), linkCount, notifCount, len(auditLogs))

	// -------------------------------------------------------------------------
	// Verification — query actual DB counts to confirm data is visible (#188)
	// -------------------------------------------------------------------------
	var dbIncidents, dbVisible, dbDrafts, dbInjured, dbInvestigations, dbCapas, dbFiveWhys, dbFactors, dbWitnesses, dbHours int64
	db.Model(&models.Incident{}).Count(&dbIncidents)
	db.Model(&models.Incident{}).Where("is_draft = false").Count(&dbVisible)
	db.Model(&models.Incident{}).Where("is_draft = true").Count(&dbDrafts)
	db.Model(&models.InjuredPerson{}).Count(&dbInjured)
	db.Model(&models.Investigation{}).Count(&dbInvestigations)
	db.Model(&models.CAPA{}).Count(&dbCapas)
	db.Model(&models.FiveWhy{}).Count(&dbFiveWhys)
	db.Model(&models.ContributingFactor{}).Count(&dbFactors)
	db.Model(&models.WitnessStatement{}).Count(&dbWitnesses)
	db.Model(&models.HoursWorked{}).Count(&dbHours)
	log.Printf("Seed: DB verification — %d incidents (%d visible, %d drafts), %d injured persons, %d investigations, %d CAPAs, %d five-whys, %d contributing factors, %d witness statements, %d hours-worked entries",
		dbIncidents, dbVisible, dbDrafts, dbInjured, dbInvestigations, dbCapas, dbFiveWhys, dbFactors, dbWitnesses, dbHours)
}
