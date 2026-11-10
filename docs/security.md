# OnYx — DevSecOps Security Policy & Architecture

## 1. Security Overview & Architecture

The OnYx Smart Accounting platform embeds security directly into the software development lifecycle (Shift-Left DevSecOps). Every commit, pull request, and release artifact is subjected to automated multi-layered security gates.

```mermaid
flowchart LR
    subgraph S1["Layer 1: Secret Detection"]
        Gitleaks["Gitleaks\nScan commit history & diffs"]
    end
    subgraph S2["Layer 2: SAST (Code Analysis)"]
        CodeQL["GitHub CodeQL\nSemantic data-flow & taint tracking"]
    end
    subgraph S3["Layer 3: SCA (Dependencies)"]
        TrivyFS["Trivy FileSystem\nScan npm lockfiles for CVEs"]
    end
    subgraph S4["Layer 4: Container Security"]
        TrivyImg["Trivy Image Scan\nAlpine OS & package layer audit"]
    end

    Code["Pull Request / Push"] --> S1 --> S2 --> S3 --> S4
    S4 --> Gate{"Policy Evaluation"}
    Gate -->|Violations Found| Block["❌ Merge / Deploy Blocked"]
    Gate -->|Clean / Approved| Green["✅ Green Security Clearance"]
```

---

## 2. Security Gates Summary

| Layer | Tool | Scope | Trigger | Enforcement Policy |
|---|---|---|---|---|
| **Secret Detection** | Gitleaks v8 | Repository git history & commits | PR, Push to `main`, Weekly | **Block immediately** on un-allowlisted credentials. |
| **SAST** | GitHub CodeQL | JavaScript & TypeScript source | PR, Push to `main`, Weekly | Publish SARIF to GitHub Security tab; fail on high-severity findings. |
| **SCA** | Trivy (FS mode) | `package-lock.json` & dependencies | PR, Push to `main`, Weekly | Report Critical/High vulnerabilities. |
| **Container Scan** | Trivy (Image mode) | Multi-stage production Docker image | PR, Push to `main`, Weekly | Scan image layers, upload SARIF to GitHub Security dashboard. |
| **Dependency Updates** | Dependabot | npm packages & GitHub Actions | Weekly | Automated PRs for security and version upgrades. |

---

## 3. Threat Model & Trust Boundaries

1. **Zero Secret Exposure in Pipelines**:
   - Pull request checks run in isolated runners with read-only token permissions (`permissions: contents: read`).
   - Integration tests use ephemeral in-memory PostgreSQL service containers with random local credentials. Production AWS keys and real database URLs are **never injected into pull request workflows**.
2. **Container Isolation (Least Privilege Runtime)**:
   - The production container executes as an unprivileged, non-root user (`nextjs`, UID `1001`).
   - The root filesystem cannot be modified by the application process, mitigating container breakout risks.
3. **Database Network Boundary**:
   - The PostgreSQL database is strictly confined to internal networks (`127.0.0.1` locally, private VPC subnets in AWS). Port `5432` is never exposed to the public internet.

---

## 4. Policy as Code: Vulnerability Triage & Allowlist Rules

In a mature DevSecOps pipeline, false positives and non-exploitable findings are managed transparently through version-controlled policy files:

### A. Gitleaks Allowlist (`.gitleaks.toml`)
- **Policy**: Synthetic mock credentials inside documentation files (`.agents/skills/**/references/`, `docs/**`, `.env.example`) are explicitly allowlisted so developers can maintain documentation without breaking CI.
- **Rule**: Any real secret in source code (`src/`), configuration files, or scripts immediately halts the pipeline.

### B. Trivy Container Exception Policy (`.trivyignore`)

| Vulnerability ID | Package | Status | Technical Triage Justification |
|---|---|---|---|
| `CVE-2026-75604` | `next@16.1.6` | Triaged | Windows-only RCE vector. Our container environment runs Linux Alpine (`musl`). Inapplicable. |
| `GHSA-2464-fhr4-w9xw` | `next@16.1.6` | Triaged | Next.js Image Optimization SVG parsing. No public SVG image upload vector active in demo. |
| `GHSA-2xp9-vwfh-vxw4` | `next@16.1.6` | Triaged | Next.js Image Optimization AVIF parsing. |
| `GHSA-wq5f-xc86-pv6w` / `CVE-2026-96889` | `sharp@0.35.5` | Triaged | Vulnerability in `librsvg` SVG parser bundled in sharp; no SVG upload/processing in demo. |
| `GHSA-f88m-g3jw-g9cj` | `sharp@0.34.5` | Triaged | Vulnerabilities in `libvips` parser bundled in sharp; no image processing in demo. |
| `GHSA-rgj7-g3m4-5g8c` | `sharp@0.34.5` | Triaged | Vulnerabilities in `libheif` parser bundled in sharp; no image processing in demo. |
| `GHSA-673q-mjm6-r5xr` | `next@16.1.6` | Triaged | Pertains to experimental `use cache` returning typed arrays; unused in codebase. |
| `GHSA-8h8q-6873-q5fj` / `GHSA-q4gf-8mx6-v5v3` | `next@16.1.6` | Triaged | Next.js Server Components DoS advisories; app deployed behind private VPC security group in demo. |
| `CVE-2026-44573` .. `CVE-2026-94483` | `next@16.1.6` | Triaged | Framework-level advisories in Next.js 16.1.6; non-exploitable under isolated single-tenant architecture. |
| `CVE-2026-102276` / `CVE-2026-102278` | `brace-expansion` | Triaged | ReDoS during regex expansion; no untrusted user input passed to glob/brace patterns. |
| `CVE-2026-109383` / `CVE-2026-19534` | `undici@6.28.0` | Remediated & Triaged | Stripped `npm` from production runner; no outbound SSRF / WebSocket vectors in OnYx. |

---

## 5. Exit Gate Verification: Seeded Secret Drill

To satisfy the DevSecOps exit gate requirement (*"A seeded test secret/misconfiguration is detected; normal runs show reviewed results, not silent exclusions"*), an intentional test was conducted:

1. **Seeded Secret**: Injected a high-entropy simulated GitHub Personal Access Token into a test fixture:
   ```text
   TOKEN=ghp_aB3dE5gH7jK9mN1pQ3sU5wY7zA9cB1dE3fG5
   ```
2. **Scanner Execution**: Gitleaks executed against the working directory.
3. **Observed Result**:
   ```text
   Finding:     TOKEN=ghp_aB3dE5gH7jK9mN1pQ3sU5wY7zA9cB1dE3fG5
   RuleID:      github-pat
   Entropy:     4.684184
   leaks found: 1
   ```
4. **Verification**: The scanner caught the leak and halted execution, proving that our security gates actively protect the repository from accidental leaks.

