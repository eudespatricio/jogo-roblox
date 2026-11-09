#!/usr/bin/env bash
# Instala as ferramentas CLI que nao vem pelo Rokit, sem sudo, em ~/.local/bin.
# Uso: bash scripts/install-tools.sh
# Idempotente: baixa e sobrescreve a versao fixada abaixo.
set -euo pipefail

BIN="$HOME/.local/bin"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$BIN"

fetch() {
	local url="$1" out="$2"
	echo "baixando $(basename "$out")..."
	curl -fL --retry 3 --connect-timeout 20 "$url" -o "$out"
}

install_zip_bin() {
	local url="$1" name="$2"
	local zip="$TMP/$name.zip" dir="$TMP/$name"
	fetch "$url" "$zip"
	python3 -m zipfile -e "$zip" "$dir"
	local bin
	bin="$(find "$dir" -type f -name "$name" | head -1)"
	[ -n "$bin" ] || { echo "binario $name nao encontrado"; exit 1; }
	install -m755 "$bin" "$BIN/$name"
}

install_tar_bin() {
	local url="$1" name="$2"
	local tar="$TMP/$name.tar.gz" dir="$TMP/$name"
	fetch "$url" "$tar"
	mkdir -p "$dir"
	tar -xzf "$tar" -C "$dir"
	local bin
	bin="$(find "$dir" -type f -name "$name" | head -1)"
	[ -n "$bin" ] || { echo "binario $name nao encontrado"; exit 1; }
	install -m755 "$bin" "$BIN/$name"
}

echo "== git-lfs 3.8.1 =="
fetch "https://github.com/git-lfs/git-lfs/releases/download/v3.8.1/git-lfs-linux-amd64-v3.8.1.tar.gz" "$TMP/lfs.tar.gz"
mkdir -p "$TMP/lfs"
tar -xzf "$TMP/lfs.tar.gz" -C "$TMP/lfs"
install -m755 "$(find "$TMP/lfs" -type f -name git-lfs | head -1)" "$BIN/git-lfs"

echo "== luau-lsp 1.70.1 =="
install_zip_bin "https://github.com/JohnnyMorganz/luau-lsp/releases/download/1.70.1/luau-lsp-linux-x86_64.zip" "luau-lsp"

echo "== Lune 0.11.1 =="
install_zip_bin "https://github.com/lune-org/lune/releases/download/v0.11.1/lune-0.11.1-linux-x86_64.zip" "lune"

echo "== Pesde 0.7.4 =="
install_zip_bin "https://github.com/pesde-pkg/pesde/releases/download/v0.7.4%2Bregistry.0.2.3/pesde-0.7.4-linux-x86_64.zip" "pesde"

echo "== rbxcloud 0.17.0 =="
install_zip_bin "https://github.com/Sleitnick/rbxcloud/releases/download/v0.17.0/rbxcloud-0.17.0-linux.zip" "rbxcloud"

echo "== oxipng 10.2.1 =="
install_tar_bin "https://github.com/oxipng/oxipng/releases/download/v10.2.1/oxipng-10.2.1-x86_64-unknown-linux-gnu.tar.gz" "oxipng"

echo "== LFS global =="
"$BIN/git-lfs" install --skip-repo >/dev/null 2>&1 || true

echo "OK: ferramentas CLI em $BIN"
