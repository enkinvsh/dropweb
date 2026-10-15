package drophaul

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"strings"
)

// DeriveToken детерминированно вычисляет 64-символьный hex-токен drophaul
// из публичного ключа и short-id Reality-инбаунда ноды. Формула идентична
// drophaul/internal/utils.DeriveHaulToken и шаблону Ansible.
func DeriveToken(publicKey, shortID string) string {
	pk := strings.TrimSpace(publicKey)
	sid := strings.ToLower(strings.TrimSpace(shortID))
	mac := hmac.New(sha256.New, []byte(pk))
	mac.Write([]byte("drophaul-v1:"))
	mac.Write([]byte(sid))
	return hex.EncodeToString(mac.Sum(nil))
}
