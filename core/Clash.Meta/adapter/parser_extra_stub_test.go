//go:build no_extra_protocols

package adapter

import (
	"context"
	"testing"

	C "github.com/metacubex/mihomo/constant"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestSlimBuildKeepsLeftOutProxiesAsUnavailable(t *testing.T) {
	proxy, err := ParseProxy(map[string]any{
		"name":     "tuic-node",
		"type":     "tuic",
		"server":   "example.com",
		"port":     443,
		"uuid":     "00000000-0000-0000-0000-000000000000",
		"password": "secret",
	})
	require.NoError(t, err)
	assert.Equal(t, "tuic-node", proxy.Name())
	assert.Equal(t, C.Tuic, proxy.Type())

	_, err = proxy.DialContext(context.Background(), &C.Metadata{})
	assert.ErrorContains(t, err, "not included in this build")
}

func TestSlimBuildRejectsUnknownProxyTypes(t *testing.T) {
	_, err := ParseProxy(map[string]any{"name": "x", "type": "no-such-protocol"})
	assert.ErrorContains(t, err, "unsupport proxy type: no-such-protocol")
}
