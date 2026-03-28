package services

import (
	"fmt"
	"html/template"
	"log"
	"net/smtp"
	"os"
	"strings"
)

// EmailConfig holds SMTP configuration read from environment variables.
type EmailConfig struct {
	Host     string
	Port     string
	User     string
	Password string
	From     string
}

// LoadEmailConfig reads SMTP settings from environment variables.
// Returns nil if SMTP_HOST is not set (graceful degradation for demo).
func LoadEmailConfig() *EmailConfig {
	host := os.Getenv("SMTP_HOST")
	if host == "" {
		return nil
	}
	port := os.Getenv("SMTP_PORT")
	if port == "" {
		port = "587"
	}
	return &EmailConfig{
		Host:     host,
		Port:     port,
		User:     os.Getenv("SMTP_USER"),
		Password: os.Getenv("SMTP_PASS"),
		From:     os.Getenv("SMTP_FROM"),
	}
}

// SendEmail sends an HTML email via SMTP. If SMTP is not configured, it logs
// a warning and returns nil (graceful degradation for demo environments).
func SendEmail(to, subject, body string) error {
	cfg := LoadEmailConfig()
	if cfg == nil {
		log.Printf("[email] SMTP not configured — skipping email to %s: %s", to, subject)
		return nil
	}
	if cfg.From == "" {
		cfg.From = cfg.User
	}

	// Build MIME message
	msg := fmt.Sprintf("From: %s\r\nTo: %s\r\nSubject: %s\r\nMIME-Version: 1.0\r\nContent-Type: text/html; charset=\"UTF-8\"\r\n\r\n%s",
		cfg.From, to, subject, body)

	addr := cfg.Host + ":" + cfg.Port

	var auth smtp.Auth
	if cfg.User != "" {
		auth = smtp.PlainAuth("", cfg.User, cfg.Password, cfg.Host)
	}

	if err := smtp.SendMail(addr, auth, cfg.From, []string{to}, []byte(msg)); err != nil {
		log.Printf("[email] Failed to send email to %s: %v", to, err)
		return fmt.Errorf("smtp send failed: %w", err)
	}

	log.Printf("[email] Sent to %s: %s", to, subject)
	return nil
}

// ---------- HTML email templates ----------

// EmailData holds the template variables for notification emails.
type EmailData struct {
	Title       string
	Message     string
	EntityType  string
	EntityID    uint
	AppURL      string
	ButtonLabel string
	ButtonURL   string
}

// emailTpl is the shared HTML email template for all notification types.
// Uses inline CSS for maximum email-client compatibility.
var emailTpl = template.Must(template.New("notification").Parse(`<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"></head>
<body style="margin:0;padding:0;background-color:#f5f5f5;font-family:Roboto,Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f5f5f5;padding:24px 0;">
    <tr><td align="center">
      <table width="600" cellpadding="0" cellspacing="0" style="background-color:#ffffff;border-radius:4px;overflow:hidden;">
        <!-- Header -->
        <tr><td style="background-color:#000000;padding:16px 24px;">
          <span style="font-family:Oswald,Arial,sans-serif;font-size:18px;font-weight:700;color:#FFD100;letter-spacing:1px;">SAFETRACK</span>
        </td></tr>
        <!-- Gold accent bar -->
        <tr><td style="background-color:#FFD100;height:4px;"></td></tr>
        <!-- Content -->
        <tr><td style="padding:24px;">
          <h2 style="margin:0 0 12px;font-family:Oswald,Arial,sans-serif;font-size:20px;color:#000000;">{{.Title}}</h2>
          <p style="margin:0 0 20px;font-size:14px;line-height:1.6;color:#58595B;">{{.Message}}</p>
          {{if .ButtonURL}}
          <a href="{{.ButtonURL}}" style="display:inline-block;padding:10px 24px;background-color:#1E3A5F;color:#ffffff;text-decoration:none;border-radius:4px;font-size:14px;font-weight:600;">{{.ButtonLabel}}</a>
          {{end}}
        </td></tr>
        <!-- Footer -->
        <tr><td style="padding:16px 24px;background-color:#f5f5f5;font-size:11px;color:#A7A9AC;text-align:center;">
          SafeTrack by Herzog — Safety Incident Management
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`))

// RenderNotificationEmail renders the HTML body for a notification email.
func RenderNotificationEmail(data EmailData) string {
	var buf strings.Builder
	if err := emailTpl.Execute(&buf, data); err != nil {
		log.Printf("[email] Template render error: %v", err)
		// Fallback to plain text
		return fmt.Sprintf("<html><body><h2>%s</h2><p>%s</p></body></html>", data.Title, data.Message)
	}
	return buf.String()
}

// ---------- Convenience senders for each notification type ----------

// SendOverdueInvestigationEmail sends an email about an overdue investigation.
func SendOverdueInvestigationEmail(to string, investigationID uint, overdueDays int, targetDate string) error {
	data := EmailData{
		Title:       "Overdue Investigation",
		Message:     fmt.Sprintf("Investigation #%d is %d days past its target completion date of %s. Please take action to resolve the investigation.", investigationID, overdueDays, targetDate),
		EntityType:  "investigation",
		EntityID:    investigationID,
		ButtonLabel: "View Investigation",
		ButtonURL:   fmt.Sprintf("%s/investigations/%d", appBaseURL(), investigationID),
	}
	return SendEmail(to, data.Title, RenderNotificationEmail(data))
}

// SendOverdueCAPAEmail sends an email about an overdue CAPA.
func SendOverdueCAPAEmail(to string, capaID uint, priority string, overdueDays int, dueDate string) error {
	data := EmailData{
		Title:       "Overdue CAPA",
		Message:     fmt.Sprintf("CAPA #%d (%s priority) is %d days past its due date of %s. Please complete the corrective action.", capaID, priority, overdueDays, dueDate),
		EntityType:  "capa",
		EntityID:    capaID,
		ButtonLabel: "View CAPA",
		ButtonURL:   fmt.Sprintf("%s/capas/%d", appBaseURL(), capaID),
	}
	return SendEmail(to, data.Title, RenderNotificationEmail(data))
}

// SendRailroadDeadlineEmail sends an email about a railroad notification deadline.
func SendRailroadDeadlineEmail(to string, incidentID uint, railroadClient, incidentType string) error {
	data := EmailData{
		Title:       "Railroad Notification Overdue",
		Message:     fmt.Sprintf("Incident #%d on %s railroad property requires client notification (%s) that is now overdue. Please contact the railroad client immediately.", incidentID, railroadClient, incidentType),
		EntityType:  "incident",
		EntityID:    incidentID,
		ButtonLabel: "View Incident",
		ButtonURL:   fmt.Sprintf("%s/incidents/%d", appBaseURL(), incidentID),
	}
	return SendEmail(to, data.Title, RenderNotificationEmail(data))
}

// SendReviewRequestEmail sends an email requesting a review of an investigation.
func SendReviewRequestEmail(to string, investigationID uint) error {
	data := EmailData{
		Title:       "Investigation Review Request",
		Message:     fmt.Sprintf("Investigation #%d has been submitted for your review. Please review and approve or return the investigation.", investigationID),
		EntityType:  "investigation",
		EntityID:    investigationID,
		ButtonLabel: "Review Investigation",
		ButtonURL:   fmt.Sprintf("%s/investigations/%d", appBaseURL(), investigationID),
	}
	return SendEmail(to, data.Title, RenderNotificationEmail(data))
}

// appBaseURL returns the base URL for the web application, used in email links.
// Defaults to localhost:3000 for development.
func appBaseURL() string {
	if url := os.Getenv("APP_BASE_URL"); url != "" {
		return url
	}
	return "http://localhost:3000"
}
