#!/usr/bin/env python3
"""
Örnek: Tek URL çek ve tecrübe oluştur.
"""

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent / "python"))

from pipeline import ContentPipeline

# Pipeline oluştur
pipeline = ContentPipeline(data_dir="data")

# Tek URL çek
url = "https://evrimagaci.org/biyoloji/nedir-hucre"
print(f"▶ Çekiliyor: {url}")

items = pipeline.process_url(url)
print(f"✓ {len(items)} tecrübe kaydedildi")

# Sonuçları göster
for i, item in enumerate(items[:3]):
    print(f"\n--- Tecrübe {i+1} ---")
    print(f"Başlık: {item.get('title', '')}")
    print(f"Kelime: {item.get('word_count', 0)}")
    print(f"Hash: {item.get('hash', '')}")
    text = item.get('text', '')
    print(f"Metin: {text[:200]}...")

# İstatistikler
print(f"\n{pipeline.summary()}")
