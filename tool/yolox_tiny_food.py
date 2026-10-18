"""YOLOX-Tiny for the live food detector (step 7, docs/PLAN.md). Trained in a YOLOX checkout (Apache 2.0):

    cd ~/src/YOLOX && systemd-run --user --scope -p MemoryMax=9G -p MemorySwapMax=0 \\
        .venv/bin/python tools/train.py -f <repo>/tool/yolox_tiny_food.py -d 1 -b 24 --fp16 -c yolox_tiny.pth

The checkout needs tool/yolox_no_anchor.patch (git apply): YOLOX's label assignment crashed at random
("selected index k out of range") on an image whose boxes all have no anchor near them; the patch gives such
an image no positives and logs the boxes. The cause: 27 training photos are EXIF-rotated, cv2 loads them turned
but the annotations keep the stored 4032x3024 frame, so a flip can push their boxes off the image (val is clean).
Resume a stopped run with --resume -c <output>/latest_ckpt.pth.
Data from tool/detector_data.py; one class per line of db/detector_labels.tsv. Starts from the COCO-trained
yolox_tiny.pth (its class head is replaced). Images are ~400-480 px, so 416 px input loses nothing.
"""

import os

from yolox.exp import Exp as BaseExp


class Exp(BaseExp):
    def __init__(self):
        super().__init__()
        # YOLOX-Tiny (exps/default/yolox_tiny.py).
        self.depth, self.width = 0.33, 0.375
        self.input_size = self.test_size = (416, 416)
        self.mosaic_scale = (0.5, 1.5)
        self.random_size = (10, 20)
        self.enable_mixup = False

        self.num_classes = 164
        self.data_dir = os.path.expanduser("~/datasets/detector")
        self.train_ann, self.val_ann = "train.json", "val.json"

        self.max_epoch = 80
        self.no_aug_epochs = 10
        self.eval_interval = 5
        self.data_num_workers = 4  # 14 GB box: more workers, more RAM
        self.exp_name = "yolox_tiny_food"
