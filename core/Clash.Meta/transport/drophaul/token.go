package drophaul

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"io"
	"strings"
	"time"
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

// MarkKey выводит ключ маркировки ClientHello.Random из токена drophaul:
// серверный ингресс проверяет эту метку на первом TLS-пакете и прозрачно уводит
// немаркированные соединения в nginx, чтобы сторонние сканеры на :443 видели
// только отпечаток обычного nginx, а не стек Go TLS 1.3.
func MarkKey(token string) []byte {
	h := sha256.New()
	h.Write([]byte("drophaul-ch-v1:"))
	h.Write([]byte(token))
	return h.Sum(nil)
}

// NewMarkedRandom привязывает HMAC-метку во второй половине ClientHello.Random
// к минутному окну времени для защиты от replay-повторов перехваченного пакета;
// допуск ±5 минут на сервере компенсирует рассинхрон часов клиента без NTP.
func NewMarkedRandom(key []byte, now time.Time, rnd io.Reader) ([32]byte, error) {
	var out [32]byte
	if _, err := io.ReadFull(rnd, out[:16]); err != nil {
		return out, err
	}
	var winBuf [8]byte
	binary.BigEndian.PutUint64(winBuf[:], uint64(now.Unix()/60))
	mac := hmac.New(sha256.New, key)
	mac.Write(out[:16])
	mac.Write(winBuf[:])
	sum := mac.Sum(nil)
	copy(out[16:], sum[:16])
	return out, nil
}

func ClientRandomForToken(token string) ([]byte, error) {
	rnd, err := NewMarkedRandom(MarkKey(token), time.Now(), rand.Reader)
	if err != nil {
		return nil, err
	}
	return rnd[:], nil
}
