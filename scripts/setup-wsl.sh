#!/usr/bin/env bash
# setup-wsl.sh — prepara o repo jogo-roblox para rodar dentro do WSL/Linux.
# Uso:  bash scripts/setup-wsl.sh [--no-verify]
# Idempotente: pode rodar quantas vezes quiser.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m  ok\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  !!\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31merro\033[0m %s\n' "$*" >&2; exit 1; }

NO_VERIFY=0
[[ "${1:-}" == "--no-verify" ]] && NO_VERIFY=1

# ---------------------------------------------------------------- sanidade
[[ "$(uname -s)" == "Linux" ]] || fail "este script é para Linux/WSL (detectado: $(uname -s))"
if grep -qi microsoft /proc/version 2>/dev/null; then
	ok "WSL detectado"
else
	warn "não parece WSL; seguindo como Linux nativo"
fi

case "$REPO_ROOT" in
	/mnt/*) warn "repo está no NTFS ($REPO_ROOT). O ideal é copiar para o ext4 (~/jogo-roblox)" ;;
esac

[[ -d .git ]] || fail "sem .git neste diretório — copie o repo com o histórico (cp -a .../jogo-roblox/. .)"
ok "git presente: $(git rev-parse --short HEAD 2>/dev/null || echo 'sem commit')"

# ---------------------------------------------------------------- git no Linux
git config core.filemode false
ok "git: core.filemode=false (evita diff falso de permissão)"

# ---------------------------------------------------------------- rokit
install_rokit_manual() {
	# Fallback sem sudo e sem unzip: baixa o zip oficial e extrai com python3.
	local arch
	case "$(uname -m)" in
		x86_64) arch=x86_64 ;;
		aarch64 | arm64) arch=aarch64 ;;
		*) fail "arquitetura não suportada pelo Rokit: $(uname -m)" ;;
	esac

	local api="https://api.github.com/repos/rojo-rbx/rokit/releases/latest"
	local url
	url="$(curl -fsSL "$api" | python3 -c "
import json, sys
arch = '$arch'
data = json.load(sys.stdin)
for a in data['assets']:
    if a['name'].endswith('linux-' + arch + '.zip'):
        print(a['browser_download_url'])
        break
")"
	[[ -n "$url" ]] || fail "não achei asset linux-$arch do Rokit"

	local tmp
	tmp="$(mktemp -d)"
	info "baixando $(basename "$url")..."
	curl -fsSL "$url" -o "$tmp/rokit.zip"
	python3 -m zipfile -e "$tmp/rokit.zip" "$tmp/x"
	local bin
	bin="$(find "$tmp/x" -type f -name rokit | head -1)"
	[[ -n "$bin" ]] || fail "binário rokit não encontrado no zip"
	mkdir -p "$HOME/.rokit/bin"
	install -m 755 "$bin" "$HOME/.rokit/bin/rokit"
	rm -rf "$tmp"
	export PATH="$HOME/.rokit/bin:$PATH"
	grep -q '.rokit/bin' "$HOME/.bashrc" 2>/dev/null ||
		echo 'export PATH="$HOME/.rokit/bin:$PATH"' >>"$HOME/.bashrc"
}

if ! command -v rokit >/dev/null 2>&1; then
	if command -v unzip >/dev/null 2>&1; then
		info "instalando Rokit (instalador oficial)..."
		curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash
		export PATH="$HOME/.rokit/bin:$PATH"
	else
		warn "unzip ausente; instalando Rokit manualmente (sem sudo)"
		install_rokit_manual
	fi
fi
command -v rokit >/dev/null 2>&1 || fail "rokit não está no PATH; abra um shell novo e rode de novo"
ok "rokit: $(rokit --version 2>/dev/null | head -1)"

# ---------------------------------------------------------------- ferramentas
info "instalando ferramentas fixadas em rokit.toml..."
warn "trust automático apenas das 4 versões fixadas (rojo/stylua/selene/luau)"
rokit install --no-trust-check
for tool in rojo stylua selene luau; do
	command -v "$tool" >/dev/null 2>&1 || fail "$tool não encontrado após rokit install"
done
ok "rojo $(rojo --version 2>/dev/null | head -1) · luau $(luau --version 2>/dev/null | head -1)"

# ---------------------------------------------------------------- verificação
if [[ "$NO_VERIFY" -eq 0 ]]; then
	info "oráculo do motor (10 invariantes)..."
	luau sim/invariants.luau
	info "tetos do contexto residente..."
	command -v python3 >/dev/null 2>&1 || fail "python3 ausente (necessário para o scanner)"
	python3 skills/context-recovery/scan_repo.py --root . --check
fi

# ---------------------------------------------------------------- rede
WSL_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
cat <<EOF

$(printf '\033[1;32m============================================================\033[0m')
Pronto para desenvolver.

Roblox Studio (Windows) falando com o Rojo (WSL):
  1) aqui:        rojo serve --address 0.0.0.0
  2) no Windows (uma vez, como admin):
     New-NetFirewallRule -DisplayName "WSL Rojo 34872" -Direction Inbound \`
       -Action Allow -Protocol TCP -LocalPort 34872 \`
       -RemoteAddress 172.30.0.0/16
  3) no plugin Rojo do Studio: ${WSL_IP:-<ip-do-wsl>}:34872

O IP do WSL muda ao reiniciar: rode este script de novo para ver o atual.
Sem admin? Alternativa: Rojo no Windows lendo o projeto via \\\\wsl.localhost\\Ubuntu\\home\\eudespatricio\\jogo-roblox
(o build funciona; o sync ao vivo precisa ser testado).
$(printf '\033[1;32m============================================================\033[0m')
EOF
