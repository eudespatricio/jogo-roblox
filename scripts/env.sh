#!/usr/bin/env bash
# Coloca as ferramentas do projeto no PATH. Uso: source scripts/env.sh
# (scripts e CI devem usar este arquivo; shell nao-login nao le .bashrc)
export PATH="$HOME/.rokit/bin:$HOME/.local/bin:$PATH"
