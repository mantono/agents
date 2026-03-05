# Trivy Usage Guide

## Filesystem Scanning

Scan the current directory for vulnerabilities:

```bash
trivy fs . --format json --scanners vuln
```

Options:
- `fs .` - Filesystem scan of current directory
- `--format json` - JSON output for parsing
- `--scanners vuln` - Only vulnerability scanning (skip misconfig, secret, license)
- `--severity CRITICAL,HIGH` - Filter by severity (optional)
- `--ignore-unfixed` - Only show vulnerabilities with fixes (optional)

## JSON Output Structure

```json
{
  "Results": [
    {
      "Target": "package-lock.json",
      "Class": "lang-pkgs",
      "Type": "npm",
      "Vulnerabilities": [
        {
          "VulnerabilityID": "CVE-2023-XXXXX",
          "PkgName": "lodash",
          "InstalledVersion": "4.17.20",
          "FixedVersion": "4.17.21",
          "Severity": "CRITICAL",
          "Title": "Prototype Pollution",
          "Description": "...",
          "References": ["https://..."],
          "CVSS": {
            "nvd": {
              "V3Score": 9.8
            }
          }
        }
      ]
    }
  ]
}
```

## Key Fields

| Field | Description |
|-------|-------------|
| `Results[].Target` | File where vulnerability was found |
| `Results[].Type` | Package ecosystem (npm, pip, cargo, etc.) |
| `Vulnerabilities[].VulnerabilityID` | CVE identifier |
| `Vulnerabilities[].PkgName` | Package name |
| `Vulnerabilities[].InstalledVersion` | Current version |
| `Vulnerabilities[].FixedVersion` | Version with fix (empty if no fix) |
| `Vulnerabilities[].Severity` | CRITICAL, HIGH, MEDIUM, LOW, UNKNOWN |
| `Vulnerabilities[].Title` | Brief description |
| `Vulnerabilities[].CVSS.nvd.V3Score` | CVSS v3 score (0-10) |

## Docker Image Scanning

Scan a Docker image for vulnerabilities:

```bash
trivy image <image-name> --format json --scanners vuln
```

Examples:
```bash
# Scan local image
trivy image myapp:latest --format json --scanners vuln

# Scan image from registry
trivy image nginx:1.21 --format json --scanners vuln

# Build and scan in one go
docker build -t temp:scan . && trivy image temp:scan --format json --scanners vuln
```

Options:
- `image <name>` - Docker image to scan (local or remote)
- `--format json` - JSON output for parsing
- `--scanners vuln` - Only vulnerability scanning
- `--severity CRITICAL,HIGH` - Filter by severity (optional)
- `--ignore-unfixed` - Only show vulnerabilities with fixes (optional)

**Note:** Docker image scans detect vulnerabilities in:
- OS packages (apt, yum, apk, etc.)
- Language-specific packages embedded in the image
- Application dependencies

The JSON output structure is identical to filesystem scanning.

## Checking for Scannable Content

Check if filesystem scan found any results:

```bash
trivy fs . --format json --scanners vuln | jq -r '.Results // [] | length'
```

If the output is `0`, no supported files were found.

## Parsing with jq

Extract actionable vulnerabilities (those with fixes):

```bash
trivy fs . --format json --scanners vuln | jq -r '
  .Results[]?.Vulnerabilities[]?
  | select(.FixedVersion != null and .FixedVersion != "")
  | [.PkgName, .InstalledVersion, .FixedVersion, .VulnerabilityID, .Severity]
  | @tsv
'
```

Count by severity:

```bash
trivy fs . --format json --scanners vuln | jq '
  [.Results[]?.Vulnerabilities[]?]
  | group_by(.Severity)
  | map({severity: .[0].Severity, count: length})
'
```
