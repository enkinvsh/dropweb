//go:build no_extra_protocols

package listener

import (
	"fmt"

	"github.com/metacubex/mihomo/common/structure"
	C "github.com/metacubex/mihomo/constant"
)

func parseExtraListener(proxyType string, mapping map[string]any, decoder *structure.Decoder) (C.InboundListener, error) {
	return nil, fmt.Errorf("unsupport proxy type: %s (not included in this build)", proxyType)
}
