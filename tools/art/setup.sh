#!/usr/bin/env bash
# Installs the free, local AI tools used by tools/art/extract-ui-art.py into
# ~/.cache/comet-raiders-art (outside the repo, nothing global):
#   - rembg (isnet-anime model) for background removal
#   - Real-ESRGAN ncnn-vulkan (realesrgan-x4plus-anime) for 4x upscaling
# Needs `uv` (brew install uv). Re-running is safe.
set -euo pipefail
ART="${COMET_ART_TOOLS:-$HOME/.cache/comet-raiders-art}"
mkdir -p "$ART"
cd "$ART"
if [ ! -x venv/bin/python ]; then
	uv venv -q venv --python 3.11
fi
uv pip install -q --python venv/bin/python "rembg[cpu]" pillow numpy scipy
if [ ! -x esrgan/realesrgan-ncnn-vulkan ]; then
	curl -sSL -o esrgan.zip \
		https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesrgan-ncnn-vulkan-20220424-macos.zip
	mkdir -p esrgan
	unzip -q -o esrgan.zip -d esrgan
	chmod +x esrgan/realesrgan-ncnn-vulkan
	rm -f esrgan.zip
fi
echo "art tools ready in $ART"
