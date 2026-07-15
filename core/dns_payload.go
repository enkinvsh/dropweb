package main

import "strings"

// parseDNSPayload parses the comma-separated system-DNS payload from the
// platform layer into a clean address slice.
//
// Deliberately untagged (no android build constraint) so it is testable on
// the host: `cd core && go test .`.
//
// Semantics required by the bearer-change DNS pipeline:
//   - "" becomes []string{}, not []string{""} — an empty payload is the
//     meaningful clear-system-DNS command and must never reach
//     dns.UpdateSystemDNS as a garbage one-element slice;
//   - whitespace-only entries are dropped;
//   - duplicates are removed while preserving first-occurrence order;
//   - bracketed IPv6 socket text ("[::1]:53") passes through unchanged.
func parseDNSPayload(value string) []string {
	parts := strings.Split(value, ",")
	result := make([]string, 0, len(parts))
	seen := make(map[string]struct{}, len(parts))

	for _, part := range parts {
		address := strings.TrimSpace(part)
		if address == "" {
			continue
		}
		if _, exists := seen[address]; exists {
			continue
		}
		seen[address] = struct{}{}
		result = append(result, address)
	}

	return result
}
