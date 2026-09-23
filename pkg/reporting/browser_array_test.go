package reporting

import "testing"

func TestParseReportsBrowserArray(t *testing.T) {
	body := `[{
		"type": "csp-violation",
		"url": "https://dast.b-fine.be/connect/login",
		"body": {
			"documentURL": "https://dast.b-fine.be/connect/login",
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
	if got[0].CSP.Body.DocumentURI != "https://dast.b-fine.be/connect/login" {
		t.Errorf("DocumentURI = %q, want camelCase documentURL mapped", got[0].CSP.Body.DocumentURI)
	}
	if got[0].CSP.Body.BlockedURI != "inline" {
		t.Errorf("BlockedURI = %q, want inline", got[0].CSP.Body.BlockedURI)
	}
	if got[0].CSP.Body.EffectiveDirective != "script-src-elem" {
		t.Errorf("EffectiveDirective = %q", got[0].CSP.Body.EffectiveDirective)
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
