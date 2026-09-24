package reporting

import "testing"

func TestParseReportsBrowserArray(t *testing.T) {
	body := `[{
		"type": "csp-violation",
		"url": "https://example.com/connect/login",
		"body": {
			"documentURL": "https://example.com/connect/login",
			"blockedURL": "inline",
			"effectiveDirective": "script-src-elem",
			"violatedDirective": "script-src-elem",
			"originalPolicy": "default-src 'self'",
			"disposition": "report",
			"statusCode": 200
		}
	}]`
	got, err := ParseReports(body, "dast")
	if err != nil {
		t.Fatalf("ParseReports() error = %v", err)
	}
	if len(got) != 1 {
		t.Fatalf("len = %d, want 1", len(got))
	}
	if got[0].CSP == nil {
		t.Fatal("expected CSP report")
	}
	if got[0].CSP.Body.DocumentURI != "https://example.com/connect/login" {
		t.Errorf("DocumentURI = %q, want camelCase documentURL mapped", got[0].CSP.Body.DocumentURI)
	}
	if got[0].CSP.Body.BlockedURI != "inline" {
		t.Errorf("BlockedURI = %q, want inline", got[0].CSP.Body.BlockedURI)
	}
	if got[0].CSP.Body.EffectiveDirective != "script-src-elem" {
		t.Errorf("EffectiveDirective = %q", got[0].CSP.Body.EffectiveDirective)
	}
}

// Safari posts application/csp-report with a Reporting API body, so the
// format must be detected from the payload instead of the Content-Type.
func TestIsLegacyCSPReport(t *testing.T) {
	for _, tt := range []struct {
		name string
		body string
		want bool
	}{
		{"legacy wrapper", `{"csp-report":{"document-uri":"https://example.com/"}}`, true},
		{"safari reporting api body", `{"type":"csp-violation","url":"https://example.com/","body":{"documentURL":"https://example.com/"}}`, false},
		{"reporting api array", `[{"type":"csp-violation","body":{}}]`, false},
		{"garbage", "not json", false},
	} {
		t.Run(tt.name, func(t *testing.T) {
			if got := IsLegacyCSPReport(tt.body); got != tt.want {
				t.Errorf("IsLegacyCSPReport() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestParseReportsSingleObjectStillWorks(t *testing.T) {
	body := `{"type":"csp-violation","url":"https://example.com/","body":{"document_uri":"https://example.com/","blocked_uri":"https://evil.com/"}}`
	got, err := ParseReports(body, "svc")
	if err != nil {
		t.Fatalf("ParseReports() error = %v", err)
	}
	if len(got) != 1 {
		t.Fatalf("len = %d, want 1", len(got))
	}
	if got[0].CSP.Body.DocumentURI != "https://example.com/" {
		t.Errorf("DocumentURI = %q", got[0].CSP.Body.DocumentURI)
	}
}
