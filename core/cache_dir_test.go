package main

// Регрессия 0xdead10cc: на свежей установке iOS нет профиля, Dart шлёт ядру
// приложения `config: {}`, Go дополняет его DefaultRawConfig со
// store-selected: true, и executor.updateProfile открывает cache.db. bbolt
// держит на нём flock до конца процесса, а Runner засыпает с замком на файле в
// общем контейнере App Group — RunningBoard убивает его через секунды.
//
// ядро держит синглтон cachefile, поэтому каждый сценарий идёт в отдельном
// процессе (тот же тестовый бинарь, режим выбирается переменной окружения).

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"testing"

	"github.com/metacubex/mihomo/constant"
)

const (
	cacheHelperMode    = "DROPWEB_CACHE_HELPER_MODE"
	cacheHelperHome    = "DROPWEB_CACHE_HELPER_HOME"
	cacheHelperPrivate = "DROPWEB_CACHE_HELPER_PRIVATE"
)

// Полезная нагрузка setupConfig, как её собирает patchRawConfig без профиля.
const freshInstallSetup = `{"config":{},"selected-map":{},"test-url":"https://www.gstatic.com/generate_204"}`

func TestHelperFreshInstallCore(t *testing.T) {
	mode := os.Getenv(cacheHelperMode)
	if mode == "" {
		t.Skip("запускается из TestFreshInstallCacheLocation")
	}
	home, private := os.Getenv(cacheHelperHome), os.Getenv(cacheHelperPrivate)
	if mode == "app" {
		// Так iOS-сборка (lib_ios.go) выбирает каталог для процесса приложения.
		privateCacheDir = func() string { return private }
	}
	if !handleInitClash(fmt.Sprintf(`{"home-dir":%q,"version":1}`, home)) {
		t.Fatal("init failed")
	}
	if msg := handleSetupConfig([]byte(freshInstallSetup)); msg != "" {
		t.Fatalf("setupConfig: %s", msg)
	}
	t.Logf("cache path: %s", constant.Path.Cache())
}

func TestFreshInstallCacheLocation(t *testing.T) {
	cases := []struct {
		name      string
		mode      string
		inHome    bool
		inPrivate bool
	}{
		// Приложение: cache.db рядом с ядром, но не в общей группе.
		{"приложение", "app", false, true},
		// Расширение: прежнее поведение, кэш остаётся в группе.
		{"расширение", "tunnel", true, false},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			root := t.TempDir()
			home := filepath.Join(root, "group")
			private := filepath.Join(root, "private")
			if err := os.MkdirAll(home, 0o755); err != nil {
				t.Fatal(err)
			}

			cmd := exec.Command(os.Args[0], "-test.run=^TestHelperFreshInstallCore$", "-test.v")
			cmd.Env = append(os.Environ(),
				cacheHelperMode+"="+tc.mode,
				cacheHelperHome+"="+home,
				cacheHelperPrivate+"="+private,
			)
			if out, err := cmd.CombinedOutput(); err != nil {
				t.Fatalf("helper failed: %v\n%s", err, out)
			}

			if got := fileExists(filepath.Join(home, "cache.db")); got != tc.inHome {
				t.Errorf("cache.db в общем каталоге = %v, ждали %v", got, tc.inHome)
			}
			if got := fileExists(filepath.Join(private, "cache.db")); got != tc.inPrivate {
				t.Errorf("cache.db в приватном каталоге = %v, ждали %v", got, tc.inPrivate)
			}
		})
	}
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}
