# Severity Matrix

## CVSS to Severity Mapping

| CVSS v3 Score | Severity |
|---------------|----------|
| 9.0 - 10.0 | CRITICAL |
| 7.0 - 8.9 | HIGH |
| 4.0 - 6.9 | MEDIUM |
| 0.1 - 3.9 | LOW |
| 0.0 | NONE |

## Update Priority Order

Process vulnerabilities in this order:

1. **CRITICAL** - Actively exploited or trivially exploitable, severe impact
2. **HIGH** - Significant risk, should be addressed promptly
3. **MEDIUM** - Moderate risk, update when convenient
4. **LOW** - Minor risk, lowest priority

## Mode Filtering

| Mode | Severities Processed |
|------|---------------------|
| `update-critical` | CRITICAL, HIGH |
| `update` | CRITICAL, HIGH, MEDIUM, LOW |
| `interactive` | CRITICAL, HIGH, MEDIUM, LOW (with prompts) |

## Prioritization Rules

Within the same severity level:

1. **Prefer packages with direct dependencies** over transitive dependencies
2. **Prefer smaller version jumps** (patch > minor > major) for stability
3. **Group related packages** if they share the same CVE
4. **Skip duplicates** - same package appearing in multiple Results

## Risk Assessment Notes

- Multiple CVEs in same package: Update once to highest fixed version
- No fixed version: Report but cannot update, track for future
- Breaking version (major bump): Warn user in interactive mode
