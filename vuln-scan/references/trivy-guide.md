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
