#!/usr/bin/env bash
# DJI AI Inside — environment setup for mmyolo v0.6.0 and mmseg b040e147
# Usage: bash setup.sh [yolov8|hrnet]  (or set DJI_MODEL env var)
set -euo pipefail

MODEL="${1:-${DJI_MODEL:-yolov8}}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIP="python3 -m pip"

if [[ "$MODEL" != "yolov8" && "$MODEL" != "hrnet" ]]; then
    echo "Usage: bash setup.sh [yolov8|hrnet]" >&2
    exit 1
fi

PYVER=$(python3 -c "import sys; print(f'cp{sys.version_info.major}{sys.version_info.minor}')")
echo "[dji] Setting up $MODEL environment (Python $PYVER)..."

# numpy < 2 must come before torch
$PIP install -q "numpy==1.26.4"

if [[ "$MODEL" == "yolov8" ]]; then
    # torch 2.0.0+cu118 — installed via direct URL because pip index no longer lists <2.2.0
    # wheels exist for cp310 and cp311 only; cp312 is not supported by torch 2.0.0
    if [[ "$PYVER" == "cp312" ]]; then
        echo "[dji] ERROR: torch==2.0.0 has no wheel for Python 3.12. Use Python 3.10 or 3.11." >&2
        exit 1
    fi
    TORCH_BASE="https://download.pytorch.org/whl/cu118"
    $PIP install -q \
        "${TORCH_BASE}/torch-2.0.0%2Bcu118-${PYVER}-${PYVER}-linux_x86_64.whl" \
        "${TORCH_BASE}/torchvision-0.15.0%2Bcu118-${PYVER}-${PYVER}-linux_x86_64.whl"

    # mmcv 2.0.1 — exact version required for torch 2.0.0
    $PIP install -q \
        "https://download.openmmlab.com/mmcv/dist/cu118/torch2.0.0/mmcv-2.0.1-${PYVER}-${PYVER}-manylinux1_x86_64.whl"

    # mmengine + mmdet
    $PIP install -q mmengine "mmdet>=3.0.0,<4.0.0"

    # mmyolo — requires --no-build-isolation (setup.py imports torch at build time)
    $PIP install -q "$HERE/mmyolo_src" --no-build-isolation

    echo ""
    echo "[dji] mmyolo ready."
    echo "[dji] Source: $HERE/mmyolo_src"
    echo "[dji] Train:  cd $HERE/mmyolo_src && DATA_ROOT=/path/to/dataset python tools/train.py configs/yolov8/yolov8_s_syncbn_fast_8xb16-500e_coco.py --work-dir <work_dir>"

elif [[ "$MODEL" == "hrnet" ]]; then
    # torch 2.1.0+cu121 — installed via direct URL for same reason as yolov8
    TORCH_BASE="https://download.pytorch.org/whl/cu121"
    $PIP install -q \
        "${TORCH_BASE}/torch-2.1.0%2Bcu121-${PYVER}-${PYVER}-linux_x86_64.whl" \
        "${TORCH_BASE}/torchvision-0.16.0%2Bcu121-${PYVER}-${PYVER}-linux_x86_64.whl"

    # mmcv 2.2.0 — exact version required for torch 2.1.0
    $PIP install -q \
        "https://download.openmmlab.com/mmcv/dist/cu121/torch2.1.0/mmcv-2.2.0-${PYVER}-${PYVER}-manylinux1_x86_64.whl"

    # mmengine
    $PIP install -q mmengine

    # mmseg — editable install, no --no-build-isolation needed
    $PIP install -q -v -e "$HERE/mmseg_src"

    echo ""
    echo "[dji] mmseg ready."
    echo "[dji] Source: $HERE/mmseg_src"
    echo "[dji] Train:  cd $HERE/mmseg_src && DATA_ROOT=/path/to/dataset python tools/train.py configs/hrnet/fcn_hr18s_4xb2-160k_cityscapes-832x832.py --work-dir <work_dir>"
fi

echo "[dji] Verify: python3 -c \"import mmyolo; print(mmyolo.__version__)\""
echo "[dji] Done."
