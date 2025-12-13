# Compliance Protocol: Cloudflare Penetration Testing

## 1. Introduction

This document outlines the technical and operational measures implemented within this security toolkit to ensure full compliance with Cloudflare's published policies regarding penetration testing and security scans.

The primary objective is to conduct effective security assessments while maintaining the stability, performance, and integrity of the target infrastructure hosted on Cloudflare. All testing activities are designed to be non-disruptive and respectful of the shared infrastructure model.

**Reference:** [Cloudflare - Scans and Penetration Testing](https://developers.cloudflare.com/fundamentals/reference/scans-penetration/)

## 2. Core Compliance Principles

Our testing methodology is guided by the following principles:

-   **Authorization First:** All testing activities are conducted only after receiving explicit, written permission from the owner of the target assets.
-   **Non-Disruption:** Tools and techniques are configured to avoid any impact on service availability or performance. We explicitly forbid Denial-of-Service (DoS) or other high-volume, flood-style tests.
-   **Controlled Scope:** Scans are strictly limited to the targets defined in the `pentest/targets/` directory, which serves as the authoritative source of truth for the authorized scope.
-   **Transparency and Auditability:** All actions, tool outputs, and generated data are logged and stored in immutable, timestamped directories (`pentest/runs/`) to provide a complete audit trail.

## 3. Technical Compliance Measures

To enforce these principles, the toolkit employs several technical controls:

### 3.1. Traffic and Rate Limiting

Scanning tools are configured with conservative settings to prevent traffic patterns that could be mistaken for malicious activity or a DoS attack.

-   **`httpx`:** Default settings are used for probing, which are not overly aggressive. Rate limiting (`-rl`) can be enforced in custom configurations if required.
-   **`ffuf`:** The default configuration avoids high thread counts. Rate limiting (`-rate`) is mandated for any large-scale content discovery to ensure a low and slow approach.
-   **`nuclei`:** Bulk request templates and those known to generate high traffic volumes are excluded from the default scan policies. Rate limiting (`-rl`) is applied globally.

### 3.2. Avoidance of Destructive Payloads

The toolkit is engineered to identify potential vulnerabilities, not to actively exploit them in a way that could compromise system integrity.

-   **`nuclei` Templates:** The selected templates focus on detection and information gathering. Templates designed for active exploitation or those with a high potential for service disruption are not included in the standard CI/CD test runs.
-   **No Automated Exploitation:** The framework does not include tools for automated remote code execution, SQL injection exploitation, or similar high-risk activities. Manual validation is required for all findings.

### 3.3. Scope Enforcement

The operational scripts (`podman-run.sh`) and CI workflows are designed to read their target configuration exclusively from the `pentest/targets/` directory. This mechanism programmatically prevents "scope creep" and ensures that only authorized assets are scanned.

## 4. Tool-Specific Considerations

-   **Reconnaissance Tools (`subfinder`, `amass`, `dnsx`):** These tools are used in passive or non-intrusive modes to gather publicly available information. They do not send malicious requests or perform aggressive probing.
-   **TLS/SSL Testing (`testssl.sh`):** This tool performs a series of standards-compliant checks against TLS configurations. It is a diagnostic tool and does not engage in disruptive behavior.
-   **API Discovery (`kiterunner`):** Used with curated wordlists and conservative request rates to identify unlinked or undocumented API endpoints without overwhelming the target.

## 5. Conclusion

This toolkit has been architected with Cloudflare's policies as a core design constraint. By combining technical rate-limiting, strict scope enforcement, non-disruptive testing techniques, and a commitment to operational transparency, we ensure that all security assessments are conducted responsibly and in full compliance with provider guidelines.
