# /// script
# requires-python = ">=3.11"
# dependencies = ["sentence-transformers>=5", "torch"]
#
# [[tool.uv.index]]
# name = "pytorch-cpu"
# url = "https://download.pytorch.org/whl/cpu"
# explicit = true
#
# [tool.uv.sources]
# torch = { index = "pytorch-cpu" }
# ///
"""Do PC embeddings (sentence-transformers, full precision) match the phone's?

    HF_TOKEN=$(cat ~/.cache/huggingface/token) uv run tool/compare_embeddings.py embedding_check.json

Input: the JSON written by integration_test/embedding_check_test.dart. This is
also the reference for embedding nutri.db docs on a PC: same model, and the
document prefix 'title: none | text: ' instead of the query prefix used here.
"""

import json
import sys

import numpy as np
from sentence_transformers import SentenceTransformer

data = json.load(open(sys.argv[1]))
model = SentenceTransformer("google/embeddinggemma-300m")
pc = model.encode(data["texts"], prompt=data["prefix"], normalize_embeddings=True)

for name in ("seq512", "seq256"):
    phone = np.array(data[name])
    phone /= np.linalg.norm(phone, axis=1, keepdims=True)
    cos = (pc * phone).sum(axis=1)
    print(f"{name}: cos min {cos.min():.4f} mean {cos.mean():.4f}")
    for c, t in zip(cos, data["texts"]):
        print(f"   {c:.4f}  {t[:50]}")

# Retrieval sanity: does the PC query vector still find the right phone vector?
phone = np.array(data["seq512"])
phone /= np.linalg.norm(phone, axis=1, keepdims=True)
hits = ((pc @ phone.T).argmax(axis=1) == np.arange(len(pc))).mean()
print(f"nearest-neighbour agreement PC->phone: {hits:.0%}")
