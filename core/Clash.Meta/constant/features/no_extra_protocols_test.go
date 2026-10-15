package features

import (
	"slices"
	"testing"
)

func TestTagsReportNoExtraProtocols(t *testing.T) {
	if got := slices.Contains(Tags(), "no_extra_protocols"); got != NoExtraProtocols {
		t.Fatalf("Tags() reports no_extra_protocols=%v, build has %v", got, NoExtraProtocols)
	}
}
