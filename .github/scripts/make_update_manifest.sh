#!/usr/bin/env bash
# Собирает update.json для встроенного обновления (Android/десктоп). Манифест
# публикуется в двух местах, у каждого свои ссылки на файлы:
#   github — ассеты этого GitHub-релиза: не зависит от Yandex Cloud;
#   yc     — бакет dropweb-downloads/latest: быстрее в РФ без VPN.
# Приложение опрашивает все зеркала и берёт самый свежий манифест, поэтому
# релиз доходит до юзеров, даже если одно из хранилищ не обновилось.
# Вызов (из корня репозитория, после шагов переименования и sha256):
#   make_update_manifest.sh <github|yc> <tag> <out.json>
set -euo pipefail

host="$1"
tag="$2"
out="$3"
# Хост проверяется здесь: exit внутри $(url ...) завершил бы только подоболочку.
case "$host" in
  github | yc) ;;
  *)
    echo "unknown host: $host (github|yc)" >&2
    exit 64
    ;;
esac
version="${tag#v}"
build=$(grep '^version:' pubspec.yaml | sed -E 's/.*\+([0-9]+).*/\1/')

# Ссылка на файл платформы по имени ассета в ./dist; короткое имя — как файл
# лежит в бакете latest/. Файла нет в сборке — пустая ссылка: приложение такую
# платформу пропускает, а не качает 404 или чужую версию.
url() {
  local name="$1" short="$2"
  if [ ! -f "./dist/$name" ]; then
    echo ""
    return
  fi
  case "$host" in
    github) echo "https://github.com/${GITHUB_REPOSITORY}/releases/download/$tag/$name" ;;
    yc) echo "https://storage.yandexcloud.net/dropweb-downloads/latest/$short" ;;
  esac
}

# sha256 для проверки целостности скачанного файла (настоящая защита —
# пин сертификата подписи APK в приложении). Нет файла — пустая строка.
sha() {
  if [ -f "./dist/$1.sha256" ]; then cut -d' ' -f1 "./dist/$1.sha256"; else echo ""; fi
}

notes_json=$(VERSION="$tag" python3 .github/scripts/notify_telegram.py --print-manifest-notes)
if [ "$(jq 'length' <<<"$notes_json")" -eq 0 ]; then
  notes_raw=$(grep '^- ' release.md | head -3 | sed 's/^- //' || true)
  [ -z "$notes_raw" ] && notes_raw="Релиз $version"
  notes_json=$(printf '%s\n' "$notes_raw" | jq -R . | jq -s .)
fi

apk="dropweb-$version-android-arm64-v8a.apk"
universal="dropweb-$version-android-universal.apk"
exe="dropweb-$version-windows-amd64-setup.exe"
dmg="dropweb-$version-macos-arm64.dmg"
dmg_amd="dropweb-$version-macos-amd64.dmg"
appimage="dropweb-$version-linux-amd64.AppImage"

jq -n \
  --arg version "$version" \
  --argjson build "${build:-0}" \
  --arg pubDate "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson notes "$notes_json" \
  --argjson mirrors "$(jq -c . .github/update-mirrors.json)" \
  --arg apk "$(url "$apk" dropweb-arm64-v8a.apk)" --arg apkSha "$(sha "$apk")" \
  --arg universal "$(url "$universal" dropweb-universal.apk)" --arg universalSha "$(sha "$universal")" \
  --arg exe "$(url "$exe" dropweb-amd64-setup.exe)" --arg exeSha "$(sha "$exe")" \
  --arg dmg "$(url "$dmg" dropweb-arm64.dmg)" --arg dmgSha "$(sha "$dmg")" \
  --arg dmgAmd "$(url "$dmg_amd" dropweb-amd64.dmg)" --arg dmgAmdSha "$(sha "$dmg_amd")" \
  --arg appimage "$(url "$appimage" dropweb-amd64.AppImage)" --arg appimageSha "$(sha "$appimage")" \
  '{version:$version,build:$build,mandatory:false,minSupported:"0.7.0",pubDate:$pubDate,notes:$notes,mirrors:$mirrors,platforms:{"android-arm64":{url:$apk,sha256:$apkSha},"android-universal":{url:$universal,sha256:$universalSha},"windows-amd64":{url:$exe,sha256:$exeSha},"windows-arm64":{url:"",sha256:""},"linux-amd64":{url:$appimage,sha256:$appimageSha},"linux-arm64":{url:"",sha256:""},"macos":{url:$dmg,sha256:$dmgSha},"macos-amd64":{url:$dmgAmd,sha256:$dmgAmdSha},"ios":{url:"",sha256:""}}}' \
  >"$out"
