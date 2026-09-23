#!/bin/bash
# Debug probe: verify DAST nginx reporting headers -> reportd
set -euo pipefail
LOG="/Users/jacek/Documents/Regnology/repos/others/reportd/.cursor/debug-a5526c.log"
SESSION="a5526c"
TS() { /usr/bin/python3 -c 'import time; print(int(time.time()*1000))'; }
log() {
  local hid="$1" loc="$2" msg="$3" data="$4"
  /usr/bin/printf '%s\n' "{\"sessionId\":\"$SESSION\",\"runId\":\"post-nginx\",\"hypothesisId\":\"$hid\",\"location\":\"$loc\",\"message\":\"$msg\",\"data\":$data,\"timestamp\":$(TS)}" >> "$LOG"
}

# H-A: Reporting-Endpoints / Report-To now include /reporting|report/{service}
HDRS=$(/usr/bin/curl -sSI 'https://dast.b-fine.be/connect/login' 2>/dev/null || true)
RE=$(/usr/bin/printf '%s' "$HDRS" | /usr/bin/grep -i '^reporting-endpoints:' | /usr/bin/tr -d '\r' || true)
RT=$(/usr/bin/printf '%s' "$HDRS" | /usr/bin/grep -i '^report-to:' | /usr/bin/tr -d '\r' || true)
CSPRO=$(/usr/bin/printf '%s' "$HDRS" | /usr/bin/grep -i '^content-security-policy-report-only:' | /usr/bin/tr -d '\r' || true)
log A "probe:headers" "dast response reporting headers" \
  "$(/usr/bin/python3 -c "import json; print(json.dumps({'reporting_endpoints':'''$RE''','report_to':'''$RT''','csp_ro':'''$CSPRO'''}))")"

# Parse whether path looks correct
HAS_REPORTING_PATH=0
HAS_REPORT_PATH=0
/usr/bin/printf '%s' "$RE$RT$CSPRO" | /usr/bin/grep -qE '/reporting/[A-Za-z0-9_-]+' && HAS_REPORTING_PATH=1 || true
/usr/bin/printf '%s' "$RE$RT$CSPRO" | /usr/bin/grep -qE '/report/[A-Za-z0-9_-]+' && HAS_REPORT_PATH=1 || true
BARE_ROOT=0
/usr/bin/printf '%s' "$RE" | /usr/bin/grep -qiE 'default="https://report\.b-fine\.be"' && BARE_ROOT=1 || true
log A "probe:path-check" "endpoint path shape" \
  "{\"has_reporting_path\":$HAS_REPORTING_PATH,\"has_report_path\":$HAS_REPORT_PATH,\"reporting_endpoints_bare_root\":$BARE_ROOT}"

# H-B: reportd still healthy
HZ=$(/usr/bin/curl -sS -o /tmp/hz.txt -w '%{http_code}' 'https://report.b-fine.be/healthz' || echo 000)
HZB=$(/usr/bin/cat /tmp/hz.txt 2>/dev/null || true)
log B "probe:healthz" "reportd healthz" "{\"status\":$HZ,\"body\":\"$HZB\"}"

# H-C: POST to configured endpoint(s) if we can extract URL; also probe common paths
# Extract first https URL from Reporting-Endpoints
EP=$(/usr/bin/printf '%s' "$RE" | /usr/bin/sed -n 's/.*default=\"\([^\"]*\)\".*/\1/p' | /usr/bin/head -1)
log C "probe:extracted-ep" "extracted Reporting-Endpoints default URL" "{\"url\":\"$EP\"}"

if [ -n "$EP" ]; then
  # OPTIONS/HEAD style: try GET then OPTIONS (no fabricated CSP body unless path has service)
  CODE=$(/usr/bin/curl -sS -o /tmp/ep_get.txt -w '%{http_code}' "$EP" || echo 000)
  log C "probe:ep-get" "GET extracted endpoint" "{\"url\":\"$EP\",\"status\":$CODE,\"body_snip\":\"$(/usr/bin/head -c 80 /tmp/ep_get.txt | /usr/bin/tr '\n' ' ')\"}"
fi

# H-D: service name — check api for likely services after reading headers
for svc in dast DAST bfine release reportinghub; do
  API=$(/usr/bin/curl -sS "https://report.b-fine.be/api/reports/$svc" 2>/dev/null || echo '{}')
  log D "probe:api/$svc" "api reports snapshot" \
    "$(/usr/bin/python3 -c "import json,sys; d=json.loads(sys.argv[1] if sys.argv[1] else '{}'); print(json.dumps({'service':sys.argv[2],'counts':d.get('counts',[]),'recent':len(d.get('recent_reports') or []),'report_to':len(d.get('recent_report_to') or [])}))" "$API" "$svc")"
done

# H-E: POST to bare root still 405?
ROOT=$(/usr/bin/curl -sS -o /dev/null -w '%{http_code}' -X POST 'https://report.b-fine.be/' -H 'Content-Type: application/csp-report' -d '{}' || echo 000)
log E "probe:post-root" "POST bare reportd root" "{\"status\":$ROOT}"

echo "probe done -> $LOG"
