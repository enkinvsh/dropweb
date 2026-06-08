# Client Fingerprint (uTLS ClientHello)

Client Fingerprint подменяет TLS ClientHello исходящих соединений под отпечаток реального браузера (uTLS), чтобы DPI не отличал трафик клиента по сигнатуре TLS-рукопожатия (JA3/JA4). Применяется только к протоколам, использующим uTLS.

## Значения

| Значение | Отпечаток | Примечание |
|---|---|---|
| `chrome`, `firefox`, `safari`, `ios`, `android`, `edge`, `360`, `qq` | авто (актуальная версия в uTLS) | |
| `chrome120`, `firefox120`, `safari16` | классические, без пост-квантового обмена ключами | |
| `firefox148` | Firefox 148 | пост-квантовый (X25519MLKEM768) |
| `safari26` | Safari 26.3 | пост-квантовый (X25519MLKEM768) |
| `random`, `randomized` | случайный отпечаток | |

`firefox148` и `safari26` — кастомные отпечатки dropweb (актуальные ClientHello), отсутствующие в апстрим-uTLS.

## Как включить

Только по-нодово — глобальный ключ `global-client-fingerprint` в ядре удалён.

В Mihomo YAML на каждой ноде:

```
proxies:
  - name: "..."
    type: vless        # vless / vmess / trojan / ...
    client-fingerprint: firefox148
```

В share-ссылке — параметр `fp`:

```
vless://...?security=tls&fp=firefox148&...
```

## Где работает

VLESS, VMess, Trojan, Reality, ShadowTLS. Протоколы без uTLS параметр игнорируют.

## Кто задаёт

Значение приходит из подписки — задаётся оператором в панели (нода/хост), не пользователем в приложении.

## Совместимость

Независим от TLS Fragment (см. `tls-fragment.md`): fingerprint формирует содержимое ClientHello, fragment режет его на уровне TCP. Можно включать оба одновременно.
