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

    # Apply all mmdet patches via a single Python script that only does file I/O (no mmdet imports).
    # find_spec('mmdet') locates the package dir without executing any __init__.py.
    MMDET_DIR=$(python3 -c "import importlib.util, os; s = importlib.util.find_spec('mmdet'); print(os.path.dirname(s.origin))")
    python3 - "$MMDET_DIR" <<'PYEOF'
import sys, os

d = sys.argv[1]

# 1. mmdet/__init__.py: accept mmcv 2.2.0 (default hard-check is <2.2.0)
p = os.path.join(d, '__init__.py')
src = open(p).read()
src = src.replace("mmcv_maximum_version = '2.2.0'", "mmcv_maximum_version = '2.3.0'")
open(p, 'w').write(src)
print('[dji] patched mmdet: mmcv_maximum_version -> 2.3.0')

# 2. mmdet/evaluation/metrics/__init__.py: remove CrowdHumanMetric
#    crowdhuman_metric.py imports scipy which requires numpy>=2.1 but torch 2.2+cu118
#    lands on numpy 2.0.x. CrowdHumanMetric is unused in YOLOv8 training/inference.
#    Must remove both the import line AND the __all__ entry, or `from .metrics import *`
#    raises AttributeError when it can't find the name in the module.
p = os.path.join(d, 'evaluation', 'metrics', '__init__.py')
src = open(p).read()
src = src.replace(
    'from .crowdhuman_metric import CrowdHumanMetric\n',
    ''
)
src = src.replace("'CrowdHumanMetric', ", "")
src = src.replace(", 'CrowdHumanMetric'", "")
open(p, 'w').write(src)
print('[dji] patched mmdet.evaluation.metrics: removed CrowdHumanMetric')

# 3. mmdet/models/utils/vlfuse_helper.py: the transformers import guard uses
#    `except ImportError` but newer Colab transformers raises NameError when
#    loaded with torch<2.4. Broaden to Exception so the guard works.
p = os.path.join(d, 'models', 'utils', 'vlfuse_helper.py')
src = open(p).read()
src = src.replace('except ImportError:', 'except Exception:')
open(p, 'w').write(src)
print('[dji] patched mmdet vlfuse_helper: broadened transformers import guard')
PYEOF

    # mmyolo — requires --no-build-isolation (setup.py imports torch at build time)
    $PIP install -q "$HERE/mmyolo_src" --no-build-isolation

    # numpy<2 pinned last: torch 2.2.0 C bindings require numpy 1.x;
    # mmengine/mmdet reinstall numpy 2.x so this must come after everything else.
    # --no-deps skips the resolver so pip doesn't print conflicts with Colab's numpy>=2 packages.
    $PIP install -q --no-deps "numpy<2"

    echo ""
    echo "[dji] mmyolo ready."
    echo "[dji] Source: $HERE/mmyolo_src"
    echo "[dji] Train:  cd $HERE/mmyolo_src && DATA_ROOT=/path/to/dataset python tools/train.py configs/yolov8/yolov8_s_syncbn_fast_8xb16-500e_coco.py --work-dir <work_dir>"
    echo "[dji] Note: training and inference (!python ...) already use numpy 1.26.4 — no restart needed."
    echo "[dji]       To import torch/mmyolo in notebook cells, run this in a new cell and then continue manually:"
    echo "[dji]         import os; os.kill(os.getpid(), 9)"

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

    # numpy<2 pinned last: same reason as yolov8 branch
    $PIP install -q --no-deps "numpy<2"

    echo ""
    echo "[dji] mmseg ready."
    echo "[dji] Source: $HERE/mmseg_src"
    echo "[dji] Train:  cd $HERE/mmseg_src && DATA_ROOT=/path/to/dataset python tools/train.py configs/hrnet/fcn_hr18s_4xb2-160k_cityscapes-832x832.py --work-dir <work_dir>"
fi

echo "[dji] Verify: python3 -c \"import mmyolo; print(mmyolo.__version__)\""
echo "[dji] Done."
