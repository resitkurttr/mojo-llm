#!/usr/bin/env bash
# mojo-llm derleme scripti
# Math kütüphanesi (-lm) link hatası için -Xlinker -lm gereklidir.
set -e

export PATH="/home/pardus/.local/share/uv/tools/max/bin:$PATH"

mojo build -Xlinker -lm main.mojo -o mojo_llm_bin
echo "Derlendi: ./mojo_llm_bin"
