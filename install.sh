#!/usr/bin/env bash
set -euo pipefail
readonly version='9.6.1-dev'
readonly asset="kenny-launcher-${version}-arch-x86_64.tar.xz"
readonly base='https://github.com/Tuxeodoman/kenny-launcher-arch/releases/download/v9.6.1-dev-arch'
readonly expected='626a2b98bfc61b55ee4262cadb4ae5c02d3f79acba750707c3f3280a47aa1f4b'
die() { printf '%s\n' "$*" >&2; exit 1; }
[[ $(uname -s) == Linux && $(uname -m) == x86_64 ]] || die 'Нужен Arch Linux x86_64 или совместимый дистрибутив.'
[[ $EUID -ne 0 ]] || die 'Запустите bash install.sh без sudo.'
[[ ! -f /etc/NIXOS ]] || die 'Для NixOS есть отдельный пакет: https://github.com/Tuxeodoman/kenny-launcher-nixos'
command -v pacman >/dev/null || die 'Этот установщик рассчитан на Arch Linux и системы на её базе.'
glibc=$(getconf GNU_LIBC_VERSION | awk '{print $2}')
[[ $(printf '%s\n' 2.39 "$glibc" | sort -V | head -n 1) == 2.39 ]] || die 'Нужна актуальная система с glibc 2.39+.'
[[ $# -le 1 ]] || die 'Использование: bash install.sh [путь-к-архиву.tar.xz]'

if [[ $# == 1 ]]; then
    archive=$(realpath -- "$1")
    [[ -f "$archive" ]] || die "Нет архива: $archive"
else
    command -v curl >/dev/null || die 'Сначала установите curl: sudo pacman -S curl'
    cache="${XDG_CACHE_HOME:-$HOME/.cache}/kenny-launcher-arch/$version-$expected"
    mkdir -p -- "$cache"
    archive="$cache/$asset"
    if [[ ! -f "$archive" ]]; then
        curl --fail --location --retry 4 --connect-timeout 30 --continue-at - \
            --output "$archive.partial" "$base/$asset"
        mv -- "$archive.partial" "$archive"
    fi
fi
actual=$(sha256sum -- "$archive")
[[ ${actual%% *} == "$expected" ]] || die "Контрольная сумма не совпала. Скачайте архив заново: $archive"

sudo pacman -S --needed --noconfirm xdg-utils xz gcc-libs openssl mesa libglvnd \
    libx11 libxext libxrandr libxcursor libxi libxkbcommon-x11 xcb-util-cursor \
    libxinerama fontconfig freetype2 dbus libpulse alsa-lib openal xorg-xwayland \
    ttf-dejavu

root="$HOME/.local/opt/kenny-launcher-arch"
mkdir -p -- "$root" "$HOME/.local/bin"
stage=$(mktemp -d "$root/.incoming-XXXXXX")
trap 'printf "При ошибке временная папка остаётся здесь: %s\n" "$stage" >&2' ERR
tar --extract --xz --file "$archive" --directory "$stage" --no-same-owner
[[ -x "$stage/KennyLauncher" && -f "$stage/.KennyLauncher.bin" ]] || die 'В архиве нет лаунчера.'
dest="$root/$version"
if [[ -e "$dest" ]]; then
    mv -- "$dest" "$root/$version.previous-$(date +%s)"
fi
mv -- "$stage" "$dest"
trap - ERR
ln -sfn -- "$dest/KennyLauncher" "$HOME/.local/bin/kenny-launcher-arch"
applications="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
mkdir -p -- "$applications"
desktop_exec=${dest//\\/\\\\}
desktop_exec=${desktop_exec//\"/\\\"}
cat > "$applications/kenny-launcher-arch.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Kenny Launcher Dev
Exec="$desktop_exec/KennyLauncher" %u
Terminal=false
Categories=Game;
MimeType=x-scheme-handler/kenny;
StartupWMClass=KennyLauncher
EOF
printf 'Готово. Откройте Kenny Launcher Dev в меню или выполните:\n%s\n' "$HOME/.local/bin/kenny-launcher-arch"
