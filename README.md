# dji-ai-inside

Minimum-file distribution of mmyolo v0.6.0 and mmsegmentation b040e147, patched for
[DJI AI Inside](https://developer.dji.com/ai-inside/overview) NPU deployment.

Contains only the files required to train the two supported architectures:
- **YOLOv8** (`mmyolo_src/`) — detection, up to 10 classes
- **HRNet18** (`mmseg_src/`) — semantic segmentation, up to 5 classes

## Setup

Clone the repo to a persistent location, then run the setup script for the model you need.
Each model requires a separate Python environment — their torch/mmcv versions are incompatible.

### Colab / RunPod (YOLOv8)

```bash
git clone --depth 1 https://github.com/YOUR_USER/dji-ai-inside /content/dji-ai-inside && \
  bash /content/dji-ai-inside/setup.sh yolov8
```

### Colab / RunPod (HRNet18)

```bash
git clone --depth 1 https://github.com/YOUR_USER/dji-ai-inside /content/dji-ai-inside && \
  bash /content/dji-ai-inside/setup.sh hrnet
```

### Local Linux / WSL2

```bash
git clone --depth 1 https://github.com/YOUR_USER/dji-ai-inside ~/dji-ai-inside
bash ~/dji-ai-inside/setup.sh yolov8   # or hrnet
```

> **Colab note**: training and inference (`!python ...`) work immediately after setup — no restart needed.
> To import torch/mmyolo directly in notebook cells, run `import os; os.kill(os.getpid(), 9)` in a new
> cell to restart the kernel (installed packages persist, setup does not need to run again).

## What the script installs

| | YOLOv8 | HRNet18 |
|---|---|---|
| torch | 2.2.0+cu118 | 2.1.0+cu121 |
| torchvision | 0.17.0 | 0.16.0 |
| mmcv | 2.2.0 | 2.2.0 |
| mmengine | latest | latest |
| mmdet | ≥3.0.0,<4.0.0 | — |
| install mode | `pip install . --no-build-isolation` | `pip install -v -e .` |

`numpy<2` is pinned after all other installs — torch 2.x C bindings require numpy 1.x.

## Training

### YOLOv8

```bash
cd /content/dji-ai-inside/mmyolo_src
DATA_ROOT=/content/drive/MyDrive/my_dataset \
python tools/train.py \
    configs/yolov8/yolov8_s_syncbn_fast_8xb16-500e_coco.py \
    --work-dir /content/work_dirs/my_model
```

### HRNet18

```bash
cd /content/dji-ai-inside/mmseg_src
DATA_ROOT=/content/drive/MyDrive/my_dataset \
python tools/train.py \
    configs/hrnet/fcn_hr18s_4xb2-160k_cityscapes-832x832.py \
    --work-dir /content/work_dirs/my_model
```

## DJI constraints

These are locked by the DJI AI Inside platform. Do not change them.

| Parameter | YOLOv8 | HRNet18 |
|---|---|---|
| Base config | `yolov8_s_syncbn_fast_8xb16-500e_coco.py` only | `fcn_hr18s_4xb2-160k_cityscapes-832x832.py` only |
| `num_classes` | ≤ 10 | ≤ 5 (including background) |
| `widen_factor` | `0.25` (4K, default in config) · `0.5` for 2K | — |
| `act_cfg` | `ReLU` (not SiLU) | — |
| Checkpoint to submit | `best_coco_bbox_mAP_epoch_*.pth` | `best_mIoU_iter_*.pth` |
| Device target | Matrice 4D Series | Matrice 4D Series |

## What you can modify in configs

**YOLOv8**: `data_root`, `train_ann_file`, `val_ann_file`, `num_classes`, `class_name`,
`metainfo`, `widen_factor` (2K→4K only), `max_epochs`, `base_lr`, data augmentation.

**HRNet18**: `data_root`, `classes`, `palette`, `train_dataloader.dataset`,
`val_dataloader.dataset`, `val_evaluator`, data augmentation.

Do not modify architecture parameters or anything marked "Unmodified in most cases" in
the DJI documentation.

## What to upload to DJI Developer Portal

1. Best checkpoint `.pth` (not the last epoch)
2. `calibration_images.zip` — 500–1000 representative JPG/PNG from the real deployment
   environment (no HUD overlays, no thermal, no extreme oblique angles < 30°)
3. Select **Matrice 4D Series** when creating the model (not "Matrice 4 Series")
