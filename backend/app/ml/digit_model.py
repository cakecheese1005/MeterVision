"""
Trained digit-sequence reader for PSPCL meter reading crops.

Architecture:
MobileNetV3-Small backbone + six parallel 10-way digit heads.

This file is used only for inference in the FastAPI backend.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import torch
from PIL import Image
from torch import nn
from torchvision import models, transforms


# =========================================================
# MODEL CONFIG
# =========================================================

MAX_DIGITS = 6
IMG_WIDTH = 192
IMG_HEIGHT = 64

MIN_DIGIT_CONFIDENCE = 0.55


# =========================================================
# CHECKPOINT PATH
# =========================================================
#
# Current structure:
#
# backend/
# ├── app/
# │   └── ml/
# │       └── digit_model.py
# │
# └── models/
#     └── digit_reader.pt
#
# parents[0] = app/ml
# parents[1] = app
# parents[2] = backend
#

CHECKPOINT_PATH = (
    Path(__file__).resolve().parents[2]
    / "models"
    / "digit_reader.pt"
)


# =========================================================
# PREPROCESSING
# =========================================================

_NORMALIZE = transforms.Normalize(
    mean=[0.485, 0.456, 0.406],
    std=[0.229, 0.224, 0.225],
)


def build_transform() -> transforms.Compose:

    return transforms.Compose(
        [
            transforms.Resize(
                (IMG_HEIGHT, IMG_WIDTH)
            ),
            transforms.ToTensor(),
            _NORMALIZE,
        ]
    )


# =========================================================
# MODEL
# =========================================================

class MultiDigitNet(nn.Module):

    def __init__(
        self,
        max_digits: int = MAX_DIGITS,
        pretrained: bool = True,
        dropout: float = 0.3,
    ):

        super().__init__()

        weights = (
            models.MobileNet_V3_Small_Weights.IMAGENET1K_V1
            if pretrained
            else None
        )

        backbone = models.mobilenet_v3_small(
            weights=weights
        )

        self.features = backbone.features

        self.pool = nn.AdaptiveAvgPool2d(1)

        self.dropout = nn.Dropout(dropout)

        feat_dim = backbone.classifier[0].in_features

        self.max_digits = max_digits

        self.heads = nn.ModuleList(
            [
                nn.Linear(feat_dim, 10)
                for _ in range(max_digits)
            ]
        )


    def forward(
        self,
        x: torch.Tensor,
    ) -> torch.Tensor:

        feats = (
            self.dropout(
                self.pool(
                    self.features(x)
                ).flatten(1)
            )
        )

        return torch.stack(
            [
                head(feats)
                for head in self.heads
            ],
            dim=1,
        )


# =========================================================
# MODEL CROP
# =========================================================

def crop_for_model(
    image: Image.Image,
    bbox: tuple[
        float,
        float,
        float,
        float,
    ],
) -> Image.Image:

    from app.ml.meter_core import padded_crop

    crop, _, _ = padded_crop(
        image,
        bbox,
        pad_ratio_x=0.15,
        pad_ratio_y=0.12,
    )

    return crop


# =========================================================
# MODEL WRAPPER
# =========================================================

@dataclass
class DigitReaderModel:

    net: MultiDigitNet
    transform: transforms.Compose


    def predict(
        self,
        crop: Image.Image,
    ) -> dict | None:

        if (
            crop.width == 0
            or crop.height == 0
        ):
            return None


        x = (
            self.transform(
                crop.convert("RGB")
            )
            .unsqueeze(0)
        )


        with torch.no_grad():

            logits = self.net(x)[0]

            probs = torch.softmax(
                logits,
                dim=-1,
            )

            digit_conf, digit_idx = (
                probs.max(dim=-1)
            )


        digits = "".join(
            str(int(d))
            for d in digit_idx.tolist()
        )

        confidences = (
            digit_conf.tolist()
        )


        return {

            "text":
                digits.lstrip("0")
                or "0",

            "raw_text":
                digits,

            "confidence":
                float(
                    min(confidences)
                ),

            "mean_confidence":
                float(
                    sum(confidences)
                    / len(confidences)
                ),

            "digit_confidences":
                confidences,

        }


    def predict_region(
        self,
        image: Image.Image,
        bbox: tuple[
            float,
            float,
            float,
            float,
        ],
    ) -> dict | None:

        crop = crop_for_model(
            image,
            bbox,
        )

        return self.predict(crop)


# =========================================================
# LOAD MODEL
# =========================================================

def load_digit_model() -> DigitReaderModel | None:

    if not CHECKPOINT_PATH.exists():

        return None


    net = MultiDigitNet(
        pretrained=False
    )


    state = torch.load(
        CHECKPOINT_PATH,
        map_location="cpu",
    )


    net.load_state_dict(
        state
    )


    net.eval()


    return DigitReaderModel(
        net=net,
        transform=build_transform(),
    )