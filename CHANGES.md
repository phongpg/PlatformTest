# Platform Engineering Test - Code Review and Fixes

## Overview

This document summarizes the security vulnerabilities, infrastructure issues, and operational problems identified during the code review of the PlatformTest project, along with the fixes implemented.

---

## Application Code (Program.cs)

### Critical Security Issues Fixed

#### 1. XXE (XML External Entity) Vulnerability - FIXED
**Location:** Lines 48-56 in Program.cs
**Issue:** XML reader enabled DTD processing with `XmlUrlResolver`, allowing external entity attacks. The XML file contained a malicious XXE payload attempting to read system files.
**Impact:** Attackers could read arbitrary files from the server, perform SSRF attacks, or cause denial of service.
**Fix:** Disabled DTD processing and set `XmlResolver` to null:
```csharp
var readerSettings = new XmlReaderSettings()
{
    DtdProcessing = DtdProcessing.Ignore,  // SECURITY FIX
    XmlResolver = null,                    // SECURITY FIX
};
```

#### 2. Loop Bug - FIXED
**Location:** Line 38 in Program.cs
**Issue:** Used `titleResponse.Docs[0]` instead of `book.EditionKeys` in the edition loop, causing incorrect behavior.
**Fix:** Changed to use the correct variable `book.EditionKeys`.

### Additional Security Issues Identified (Not Fixed)

1. **Hardcoded Password** (Line 19): Password "password" is hardcoded in source code. Should use environment variables or Azure Key Vault.

2. **Insecure Encryption (DES)** (Lines 83-101): Uses deprecated DES algorithm instead of AES-256. DES is broken and should never be used.

3. **Weak IV Generation** (Lines 120-128): IV size based on password length instead of proper cryptographic standards (should be 16 bytes for AES).

4. **Unused Encryption Class** (Lines 181-212): The Encryption class doesn't actually encrypt/decrypt - it's a security risk and should be removed.

5. **HttpClient Not Disposed**: Multiple HttpClient instances created without disposal, causing potential memory leaks. Should use HttpClientFactory or static instance.

6. **Missing Input Validation**: No validation of user input (title, author), potential for injection attacks.

---

## Terraform Infrastructure

### Critical Security Issues Fixed

#### 1. Hardcoded Secrets - FIXED
**Location:** main.tf lines 61, 66, 71; variables.tf; tfvars files
**Issue:** Database passwords, API keys, and Datadog keys stored in plaintext in Terraform files.
**Impact:** Secrets exposed in version control, accessible to anyone with repo access.
**Fix:**
- Removed hardcoded secrets from main.tf
- Added variables with `sensitive = true` flag
- Updated tfvars files with placeholder values and comments explaining proper secret management
- Secrets should come from Azure Key Vault or secure pipeline variables

#### 2. Secrets in Outputs - FIXED
**Location:** main.tf lines 110-111; outputs.tf lines 9-10
**Issue:** Admin passwords exposed in Terraform outputs.
**Impact:** Secrets logged to console and state files, accessible to anyone with state access.
**Fix:** Removed sensitive outputs (acr_admin_username, acr_admin_password) from both main.tf and outputs.tf.

#### 3. ACR Admin Enabled - FIXED
**Location:** main.tf line 31
**Issue:** Container Registry admin account enabled.
**Impact:** Provides username/password access to registry, which is a security risk.
**Fix:** Set `admin_enabled = false` and added comment recommending managed identity or RBAC instead.

#### 4. No Environment Separation - FIXED
**Location:** Resource names throughout main.tf
**Issue:** Resources hardcoded with "prod" suffix, no way to deploy to nonprod.
**Impact:** Cannot deploy to multiple environments without modifying code.
**Fix:** Made all resource names dynamic using `${var.app_name}-${var.environment}` pattern.

#### 5. No Remote State - FIXED
**Location:** terraform block in main.tf
**Issue:** No remote state backend configured.
**Impact:** Team collaboration issues, state stored locally, risk of state loss.
**Fix:** Added commented-out Azure Storage backend configuration with proper instructions.

#### 6. Log Retention Too Short - FIXED
**Location:** main.tf line 23
**Issue:** Log retention set to 7 days.
**Impact:** Insufficient logs for compliance and debugging of issues beyond a week.
**Fix:** Increased retention to 30 days.

### Additional Improvements

- Added provider version pinning for stability
- Made environment variable required (no default)
- Added proper variable descriptions
- Changed Container App to use secrets block instead of plaintext env vars
- Added comments explaining security decisions

---

## CI/CD Pipeline

### Critical Security Issues Fixed

#### 1. Hardcoded Secrets - FIXED
**Location:** azure-pipelines.yml lines 10-11, 16-17
**Issue:** ACR password, SQL password, and Datadog key in pipeline variables.
**Impact:** Secrets exposed in pipeline configuration, accessible to anyone with pipeline access.
**Fix:** Removed hardcoded secrets and added comments explaining they should come from Azure DevOps secret variables or Key Vault.

#### 2. Auto-apply to Production - FIXED
**Location:** azure-pipelines.yml line 84
**Issue:** `terraform apply -auto-approve` used for production without manual approval.
**Impact:** Accidental deployments to production without human review.
**Fix:**
- Removed `-auto-approve` flag
- Added manual approval gate using Azure DevOps environments
- Added condition to only deploy from main branch

#### 3. Insecure ACR Authentication - FIXED
**Location:** azure-pipelines.yml line 33
**Issue:** Using username/password for ACR login.
**Impact:** Credentials exposed in pipeline, potential for credential theft.
**Fix:** Changed to use `az acr login` which uses Azure CLI authentication (more secure).

#### 4. No Proper Environment Gates - FIXED
**Location:** DeployProd stage
**Issue:** Direct promotion from nonprod to prod without approval.
**Impact:** Risk of bad deployments reaching production.
**Fix:** Added environment gate with manual approval requirement.

### Additional Improvements

- Changed image tag from "latest" to build ID for immutable deployments
- Improved health check with proper error handling
- Added secret variable passing to Terraform
- Added condition to only deploy from main branch
- Changed production stage to use deployment job for better environment tracking

---

## Monitoring (Datadog)

### Critical Security Issues Fixed

#### 1. Hardcoded API Keys - FIXED
**Location:** datadog-monitors.tf lines 10-11
**Issue:** Datadog API and App keys in plaintext.
**Impact:** Credentials exposed in version control.
**Fix:** Moved to variables with `sensitive = true` flag, added comments explaining they should come from environment variables.

### Operational Issues Fixed

#### 1. Overly Sensitive CPU Alert - FIXED
**Location:** datadog-monitors.tf line 20
**Issue:** CPU threshold at 50% with 1m window causes alert fatigue.
**Impact:** Too many false positives, team ignores alerts.
**Fix:** Increased threshold to 80% (critical) and 70% (warning), added 5m evaluation window and evaluation delay.

#### 2. Overly Sensitive Response Time Alert - FIXED
**Location:** datadog-monitors.tf line 32
**Issue:** Response time threshold at 0.5s with 1m window.
**Impact:** Alerts on normal variance, noise.
**Fix:** Increased threshold to 1.0s (critical) and 0.5s (warning), added 5m evaluation window.

#### 3. Overly Sensitive Error Log Alert - FIXED
**Location:** datadog-monitors.tf line 44
**Issue:** Alert threshold of > 0 errors.
**Impact:** Alerts on single errors, excessive noise.
**Fix:** Changed to > 10 errors (critical) and > 5 (warning), added proper service filtering.

#### 4. Missing Critical Monitors - FIXED
**Location:** datadog-monitors.tf
**Issue:** No memory monitoring, no HTTP 5xx error rate monitoring.
**Impact:** Memory leaks and server errors go undetected.
**Fix:** Added two new monitors:
- Memory usage monitor (critical at 3.5GB of 4GB)
- HTTP 5xx error rate monitor (critical at > 10 errors/min)

### Additional Improvements

- Added app_name variable for dynamic naming
- Added warning thresholds for graduated alerting
- Added evaluation_delay to prevent transient spikes
- Added notify_no_data configuration
- Improved monitor messages with context
- Added error rate widget to dashboard
- Made dashboard dynamic with app_name variable
- Added provider version pinning

---

## Additional Issues Identified (Not Fixed)

### Application Code
- Need to migrate from .NET Framework 4.8 to .NET 6/8 for better security and performance
- Remove unused Encryption class entirely
- Implement proper secret management (Azure Key Vault or environment variables)
- Add input validation and sanitization
- Implement proper error handling and logging
- Add unit tests and integration tests
- Replace DES with AES-256 encryption
- Use HttpClientFactory or static HttpClient instance

### Terraform
- Implement managed identity for ACR pull instead of admin credentials
- Add Azure Key Vault resources and reference secrets from there
- Add network security groups and VNET integration
- Implement proper tagging strategy
- Add Terraform state encryption
- Add resource locks for critical resources
- Implement module structure for reusability

### Pipeline
- Add build stage with unit tests
- Add security scanning (SAST, dependency scanning)
- Add container image scanning
- Add manual approval for nonprod to prod promotion
- Implement blue-green or canary deployment strategy
- Add rollback capability
- Add notification on deployment failures

### Monitoring
- Add latency percentiles (p95, p99) monitoring
- Add database connection pool monitoring
- Add custom business metrics
- Add alert notification routing (on-call, Slack, etc.)
- Implement SLO/SLI monitoring
- Add synthetic checks for uptime monitoring
- Add cost monitoring for Azure resources

---

## Summary of Changes

### Files Modified:
1. **Program.cs** - Fixed XXE vulnerability and loop bug
2. **terraform/main.tf** - Fixed secrets, environment separation, ACR admin, added remote state template
3. **terraform/variables.tf** - Added sensitive variables, proper descriptions
4. **terraform/outputs.tf** - Removed sensitive outputs
5. **terraform/configuration/nonprod.tfvars** - Removed hardcoded secrets
6. **terraform/configuration/prod.tfvars** - Removed hardcoded secrets
7. **pipeline/azure-pipelines.yml** - Fixed secrets, added approval gates, improved authentication
8. **monitoring/datadog-monitors.tf** - Fixed secrets, improved thresholds, added critical monitors

### Key Security Improvements:
- XXE vulnerability eliminated
- All hardcoded secrets removed or marked for proper management
- Admin access disabled where possible
- Manual approval gates added for production
- Proper secret management approach documented

### Key Operational Improvements:
- Environment separation implemented
- Monitoring thresholds adjusted to reduce alert fatigue
- Critical missing monitors added (memory, 5xx errors)
- Log retention increased
- Immutable deployments with build ID tags
- Health checks improved

---

## Next Steps (If Given More Time)

1. **Implement Azure Key Vault** integration for all secrets
2. **Add managed identity** for ACR authentication
3. **Migrate to .NET 6/8** from .NET Framework 4.8
4. **Replace DES with AES-256** encryption
5. **Add comprehensive testing** (unit, integration, E2E)
6. **Implement network security** (VNET, NSGs, private endpoints)
7. **Add security scanning** to CI/CD pipeline
8. **Implement blue-green deployments** with rollback capability
9. **Add SLO/SLI monitoring** and dashboards
10. **Add infrastructure as code validation** (terraform fmt, validate, tflint)
11. **Implement tagging strategy** for cost management
12. **Add documentation** for runbooks and incident response

---

## Notes for Junior Engineer

This review was conducted as if teaching a junior engineer. The key lessons are:

1. **Never hardcode secrets** - Always use secret management systems (Azure Key Vault, AWS Secrets Manager, etc.)
2. **Security first** - Always consider security implications of code changes (XXE, injection, encryption)
3. **Operational awareness** - Don't create alerts that will be ignored due to noise
4. **Infrastructure as code best practices** - Use variables, separate environments, proper state management
5. **Deployment safety** - Never auto-apply to production, always require human approval
6. **Defense in depth** - Multiple layers of security (network, identity, secrets, code)

The fixes implemented demonstrate how to address the most critical issues while documenting the reasoning for future reference.
