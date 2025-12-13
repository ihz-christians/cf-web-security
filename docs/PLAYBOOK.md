# Security Playbook: Cloudflare & SPA Deep Dive

**Target Profile:** Cloudflare Pages (Static/SPA) + Cloudflare Workers (API)
**Context:** High-Intensity "Insider" Assessment
**Objective:** Uncover misconfigurations, leaks, and logic flaws beyond standard scanning.

---

## 1. The Arsenal

| Tool | Role | Focus |
| :--- | :--- | :--- |
| **Subfinder + DNSx** | Reconnaissance | Finding origin servers and forgotten subdomains. |
| **Httpx** | Probing | Tech stack fingerprinting, status checks. |
| **Nuclei** | Vulnerability Scanner | CVEs, Misconfigurations, Cloudflare specifics. |
| **Feroxbuster** | Content Discovery | Recursive crawling, finding hidden admin panels/files. |
| **Ffuf** | Fuzzing | Parameter fuzzing, API endpoint guessing. |
| **Kiterunner** | API Scanning | Specialized API route discovery. |
| **H2csmuggler** | Protocol Attacks | HTTP/2 Request Smuggling on Edge nodes. |
| **Testssl.sh** | Transport Security | TLS/SSL compliance. |
| **jwt_tool** | Auth Fuzzing | JWT forging, key confusion, tampering. |
| **Semgrep** | SAST | Scanning leaked source code for secrets/bugs. |
| **Gau** | History | Fetching URLs from Wayback Machine/AlienVault. |
| **Dalfox** | XSS | Intelligent, parameter-aware XSS scanning. |
| **Gf** | Filtering | Grepping for vulnerability patterns (SSRF, XSS). |

---

## 2. Phase 1: Infrastructure & Cloudflare Evasion

**Goal:** Find "Shadow IT" or direct-to-origin leaks bypassing Cloudflare protection.

### 2.1 Deep Subdomain Enumeration
Combine passive sources with active brute-forcing to find `dev`, `stage`, or `origin` subdomains.

```bash
# 1. Passive Collection
subfinder -d example.com -all -recursive -o subs_passive.txt

# 2. Active DNS Brute-Forcing (Crucial for finding hidden dev environments)
dnsx -d example.com -w /work/pentest/wordlists/SecLists/Discovery/DNS/subdomains-top1million-110000.txt -o subs_active.txt

# 3. Merge & Clean
cat subs_passive.txt subs_active.txt | sort -u | dnsx -a -cname -cdn -o $SCAN_RESULTS_DIR/recon/resolved_hosts.txt
```

### 2.2 Cloudflare Specific Checks
Detect if any subdomains are NOT proxied (Orange Cloud off), exposing the real hosting provider IP.

```bash
# Filter for non-Cloudflare IPs (Real IPs)
cat $SCAN_RESULTS_DIR/recon/resolved_hosts.txt | grep -v "cloudflare" > $SCAN_RESULTS_DIR/recon/origin_candidates.txt
```

---

## 3. Phase 2: Content Discovery (SPA & Files)

**Goal:** Map the application structure. Cloudflare Pages often leak source maps or config files.

### 3.1 Recursive Crawling (Smart Mode)
Using `feroxbuster` to crawl aggressively. We target specific extensions relevant to SPAs and backups.

```bash
# Deep crawl looking for backups, configs, and source code
feroxbuster -u https://example.com \
  -w /work/pentest/wordlists/SecLists/Discovery/Web-Content/raft-medium-directories.txt \
  -x js,json,map,txt,bak,old,zip,env \
  -d 2 --time-limit 20m \
  -o $SCAN_RESULTS_DIR/recon/ferox_content.txt
```

### 3.2 JavaScript & Source Map Analysis
If source maps (`.map`) are found, we can reconstruct the TS/JS source code to find API keys or logic.

```bash
# Find JS files
httpx -l $SCAN_RESULTS_DIR/recon/resolved_hosts.txt -path "/assets/" -match-string ".js"

# Extract URLs from specific files (e.g., if you downloaded source code)
# This regex pulls http/https links from any text file in the results dir
rg -o --no-filename -I "https?://[^\s\"'<>]+" $SCAN_RESULTS_DIR/ | sort -u \
  > $SCAN_RESULTS_DIR/recon/urls-extracted.txt
```

### 3.3 Static Code Analysis (Semgrep)
If you found source code (e.g., via source maps or exposed `.git`), scan it for hardcoded secrets and logic flaws.

```bash
# Scan a directory of downloaded source files
semgrep scan --config=auto $SCAN_RESULTS_DIR/recon/source_code/
```

---

## 4. Phase 3: API & Worker Logic Deep Dive

**Goal:** Break the logic running on Cloudflare Workers/Functions.

### 4.1 API Route Discovery
Standard crawlers miss API routes. `kiterunner` is built for this.

```bash
# Scan for common API paths
kr scan https://example.com -w /work/pentest/wordlists/SecLists/Discovery/Web-Content/common.txt -o $SCAN_RESULTS_DIR/findings/api_routes.json
```

### 4.2 Parameter Fuzzing (The "Insider" Test)
If you find an endpoint like `/api/contact`, fuzz it for hidden parameters (e.g., `debug=true`, `admin=1`).

```bash
# Fuzz GET parameters
ffuf -u https://example.com/api/target?FUZZ=1 \
  -w /work/pentest/wordlists/SecLists/Discovery/Web-Content/burp-parameter-names.txt \
  -fs 404

### 4.3 Hidden Parameter Discovery (Arjun)
Arjun is specialized for finding hidden query parameters (e.g., `?debug=true`, `?admin=1`) that control backend logic.

```bash
arjun -u https://example.com \
  -oT $SCAN_RESULTS_DIR/findings/arjun.txt
```

### 4.4 JWT Manipulation (jwt_tool)
If you find a Bearer token, test for algorithm confusion (None algorithm, key confusion) and claim tampering.

```bash
# Interactive mode (best for manual tampering)
jwt_tool <JWT_TOKEN_HERE>

# Automated Attack Mode
jwt_tool <JWT_TOKEN_HERE> -T -S -M at -t https://example.com/api/protected -rh "Authorization: Bearer <JWT_TOKEN_HERE>"
```
```

---

## 5. Phase 4: Vulnerability Scanning (The Heavy Artillery)

**Goal:** Automated detection of CVEs and specific Cloudflare misconfigurations.

### 5.1 Nuclei: The "Kitchen Sink" Scan
Run specific templates relevant to the stack.

```bash
# 1. Technologies & Cloudflare Misconfigs
nuclei -u https://example.com \
  -t technoligies \
  -t misconfiguration/cloudflare \
  -t exposures \
  -o $SCAN_RESULTS_DIR/findings/nuclei_config.txt

# 2. Token & Secret Scanning (Critical for SPAs)
nuclei -u https://example.com \
  -t exposure/tokens \
  -t exposure/keys \
  -o $SCAN_RESULTS_DIR/findings/nuclei_tokens.txt
```

### 5.2 HTTP/2 Smuggling (Advanced)
Cloudflare Edge supports HTTP/2. Test if the backend (even if it's Pages functions) desynchronizes.

```bash
# Requires setting up a specific target in h2csmuggler
# Usually run interactively
h2csmuggler -u https://example.com --test-all
```

---

## 6. Phase 5: Client-Side Supply Chain

**Goal:** Identify vulnerable JavaScript dependencies (very common in modern web apps).

```bash
# Requires fetching the page source first or pointing to a JS file
curl -s https://example.com | retire --js --outputformat text
```

---

## 7. Phase 6: Historical Recon & XSS (The Time Machine)

**Goal:** Find forgotten endpoints from the past that are still active and vulnerable.

### 7.1 Archive Mining (gau)
Fetch URLs from Wayback Machine, AlienVault, etc. often reveals old API versions.

```bash
gau example.com --threads 5 | sort -u > $SCAN_RESULTS_DIR/recon/archive_urls.txt
```

### 7.2 Intelligent XSS Scanning (dalfox)
Filter for XSS-prone parameters and scan them efficiently.

```bash
# Filter for parameters
cat $SCAN_RESULTS_DIR/recon/archive_urls.txt | gf xss | sort -u > $SCAN_RESULTS_DIR/findings/xss_candidates.txt

# Scan
dalfox file $SCAN_RESULTS_DIR/findings/xss_candidates.txt -o $SCAN_RESULTS_DIR/findings/dalfox_xss.txt
```

---

## 8. The "Combo-Breaker" (One-Liner)

**Scenario:** You want to map the entire attack surface and check for live HTTP servers in one go.

```bash
subfinder -d example.com -silent | \
dnsx -silent -a -cname | \
httpx -silent -title -tech-detect -status-code -ip -o $SCAN_RESULTS_DIR/recon/master_view.txt
```

---

## 9. Manual Review Checklist (Interactive Mode)

Open an interactive session (`make interactive`) and verify:

1.  **Security Headers:**
    *   `curl -I https://example.com`
    *   Missing `Content-Security-Policy`?
    *   Missing `Strict-Transport-Security`?
2.  **Redirect Chains:**
    *   Does `http://` redirect to `https://` properly?
    *   Do `www` and non-`www` resolve to the same canonical origin?
3.  **403/401 Bypass:**
    *   If you hit a 403 Forbidden on `/admin`, try headers:
        *   `X-Custom-IP-Authorization: 127.0.0.1`
        *   `X-Originating-IP: 127.0.0.1`
