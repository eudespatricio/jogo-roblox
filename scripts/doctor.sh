#!/usr/bin/env bash
# Audita a estacao de trabalho: ferramentas, configs, Studio, LFS, GPU e disco.
# Uso: bash scripts/doctor.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1
# shellcheck disable=SC1091
source scripts/env.sh

fail=0
optional_missing=0

check() {
	local name="$1" bin="$2" required="$3"
	if command -v "$bin" >/dev/null 2>&1; then
		printf "ok    %-12s %s\n" "$name" "$(command -v "$bin")"
	elif [ "$required" = "required" ]; then
		printf "FALHA %-12s ausente\n" "$name"
		fail=$((fail + 1))
	else
		printf " --    %-12s ausente (opcional)\n" "$name"
		optional_missing=$((optional_missing + 1))
	fi
}

file_check() {
	local label="$1" path="$2" required="$3"
	if [ -e "$path" ]; then
		printf "ok    %-12s %s\n" "$label" "$path"
	elif [ "$required" = "required" ]; then
		printf "FALHA %-12s %s\n" "$label" "$path"
		fail=$((fail + 1))
	else
		printf " --    %-12s %s\n" "$label" "$path"
	fi
}

echo "== nucleo =="
check git git required
check git-lfs git-lfs required
check python3 python3 required
check rojo rojo required
check stylua stylua required
check selene selene required
check luau luau required
check luau-lsp luau-lsp required
check asphalt asphalt required
check lune lune optional
check pesde pesde optional
check rbxcloud rbxcloud optional

echo
echo "== arte/audio =="
check blender4.5 blender4.5 required
check blender blender optional
check ffmpeg ffmpeg required
check oxipng oxipng optional
check krita krita optional
check inkscape inkscape optional
check audacity audacity optional
check magick magick optional
check pngquant pngquant optional
check optipng optipng optional
check obs obs optional

echo
echo "== configs do repo =="
file_check .luaurc .luaurc required
file_check stylua.toml stylua.toml required
file_check check.sh scripts/check.sh required
file_check env.sh scripts/env.sh required
file_check check-versions scripts/check-versions.py required
file_check versoes docs/versoes.md required
file_check asphalt.toml asphalt.toml required
file_check CREDITS.md CREDITS.md required
file_check globalTypes .tools/globalTypes.d.luau required
file_check vscode .vscode/settings.json optional
if grep -q "filter=lfs" .gitattributes 2>/dev/null; then
	printf "ok    %-12s %s\n" "lfs attrs" ".gitattributes tem filter=lfs"
else
	printf "FALHA %-12s %s\n" "lfs attrs" ".gitattributes sem filter=lfs"
	fail=$((fail + 1))
fi

echo
echo "== Studio (Windows) =="
studio=$(find /mnt/c/Users/Eudes/AppData/Local/Roblox/Versions -maxdepth 2 -name RobloxStudioBeta.exe 2>/dev/null | head -1)
if [ -n "$studio" ]; then
	printf "ok    %-12s %s\n" "Studio" "$studio"
else
	printf "FALHA %-12s %s\n" "Studio" "RobloxStudioBeta.exe nao encontrado"
	fail=$((fail + 1))
fi
plugin="/mnt/c/Users/Eudes/AppData/Local/Roblox/Plugins/Rojo.rbxm"
if [ -f "$plugin" ]; then
	printf "ok    %-12s %s\n" "Rojo plugin" "$plugin"
else
	printf " --    %-12s %s\n" "Rojo plugin" "ausente (instale no Studio)"
	optional_missing=$((optional_missing + 1))
fi

echo
echo "== ambiente =="
printf "ok    %-12s %s\n" "git remote" "$(git remote get-url origin 2>/dev/null || echo '(sem remote)')"
printf "ok    %-12s %s\n" "branch" "$(git branch --show-current 2>/dev/null || echo '(detached)')"
if git diff --quiet && git diff --cached --quiet; then
	printf "ok    %-12s %s\n" "worktree" "limpo"
else
	printf " --    %-12s %s\n" "worktree" "com alteracoes locais"
fi
printf "ok    %-12s %s\n" "disco livre" "$(df -h "$ROOT" | awk 'NR==2 {print $4}')"
if command -v nvidia-smi >/dev/null 2>&1; then
	printf "ok    %-12s %s\n" "GPU" "$(nvidia-smi -L 2>/dev/null | head -1)"
else
	printf " --    %-12s %s\n" "GPU" "nvidia-smi ausente"
fi

echo
echo "== versoes =="
printf "%-12s %s\n" "rojo" "$(rojo --version 2>/dev/null | head -1)"
printf "%-12s %s\n" "stylua" "$(stylua --version 2>/dev/null)"
printf "%-12s %s\n" "selene" "$(selene --version 2>/dev/null | head -1)"
printf "%-12s %s\n" "luau-lsp" "$(luau-lsp --version 2>/dev/null | head -1)"
printf "%-12s %s\n" "asphalt" "$(asphalt --version 2>/dev/null | head -1)"
printf "%-12s %s\n" "git-lfs" "$(git-lfs version 2>/dev/null)"
printf "%-12s %s\n" "ffmpeg" "$(ffmpeg -version 2>/dev/null | head -1 | cut -d' ' -f1-3)"
printf "%-12s %s\n" "blender4.5" "$(blender4.5 --version 2>/dev/null | head -1)"
if command -v blender >/dev/null 2>&1; then
	printf "%-12s %s\n" "blender" "$(blender --version 2>/dev/null | head -1)"
fi

echo
if [ "$fail" -eq 0 ]; then
	echo "OK: estacao completa ($optional_missing opcionais ausentes)"
	exit 0
fi
echo "FALHA: $fail item(ns) obrigatorio(s) ausente(s)"
exit 1
