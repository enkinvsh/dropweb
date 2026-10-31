package main

import (
	"os"

	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/log"
)

// privateCacheDir возвращает каталог для cache.db процесса, который система
// может усыпить с открытой БД, либо "" — тогда cache.db остаётся в homeDir.
// bbolt держит эксклюзивный flock на файле всё время жизни процесса, а iOS
// убивает приложение (0xdead10cc), уснувшее с замком на файле в общем
// контейнере App Group. Платформы переопределяют переменную в init().
var privateCacheDir = func() string { return "" }

// applyCacheDir вызывается из handleInitClash сразу после SetHomeDir, до
// первого обращения к cachefile.Cache(): БД открывается один раз за процесс.
func applyCacheDir() {
	dir := privateCacheDir()
	constant.SetCacheDir(dir)
	if dir == "" {
		return
	}
	// bbolt сам каталог не создаёт; при неудаче Cache() получит nil-БД, и все
	// обращения к кэшу станут no-op — это лучше замка в общем контейнере.
	if err := os.MkdirAll(dir, 0o755); err != nil {
		log.Warnln("[CacheFile] can't create private cache dir %s: %s", dir, err.Error())
	}
}
