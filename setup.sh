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

if [[ "$MODEL" == "yolov8" ]]; then
    # torch 2.2.0+cu118 — oldest version with cp312 support
    TORCH_BASE="https://download.pytorch.org/whl/cu118"
    $PIP install -q \
        "${TORCH_BASE}/torch-2.2.0%2Bcu118-${PYVER}-${PYVER}-linux_x86_64.whl" \
        "${TORCH_BASE}/torchvision-0.17.0%2Bcu118-${PYVER}-${PYVER}-linux_x86_64.whl"

    # mmcv 2.2.0 — matches torch 2.2.0; mmyolo version check patched to allow <2.3.0
    $PIP install -q \
        "https://download.openmmlab.com/mmcv/dist/cu118/torch2.2.0/mmcv-2.2.0-${PYVER}-${PYVER}-manylinux1_x86_64.whl"

    # mmengine + mmdet
    $PIP install -q mmengine "mmdet>=3.0.0,<4.0.0"

    # Patch mmdet: it hard-checks mmcv < 2.2.0, but 2.2.0 is the only wheel available for cu118/torch2.2.
    # Use find_spec (does not execute the module) — importing mmdet directly triggers the assert we're fixing.
    MMDET_INIT=$(python3 -c "import importlib.util; s = importlib.util.find_spec('mmdet'); print(s.origin)")
    sed -i "s/mmcv_maximum_version = '2.2.0'/mmcv_maximum_version = '2.3.0'/" "$MMDET_INIT"
    echo "[dji] patched mmdet: mmcv_maximum_version -> 2.3.0"

    # Patch mmdet.evaluation.metrics: crowdhuman_metric.py imports scipy which breaks on numpy 2.0.x
    # (scipy requires numpy>=2.1 but torch 2.2+cu118 ships with numpy 2.0.x). CrowdHumanMetric is
    # not used in YOLOv8 training or inference.
    # Derive path from mmdet package dir — find_spec('mmdet.evaluation.metrics') would trigger the
    # broken scipy import chain before we can patch it.
    MMDET_DIR=$(python3 -c "import importlib.util, os; s = importlib.util.find_spec('mmdet'); print(os.path.dirname(s.origin))")
    MMDET_METRICS="$MMDET_DIR/evaluation/metrics/__init__.py"
    sed -i "s/from .crowdhuman_metric import CrowdHumanMetric/# from .crowdhuman_metric import CrowdHumanMetric  # disabled: scipy\/numpy conflict/" "$MMDET_METRICS"
    echo "[dji] patched mmdet.evaluation.metrics: disabled CrowdHumanMetric"

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
