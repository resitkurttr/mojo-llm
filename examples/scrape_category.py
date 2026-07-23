#!/usr/bin/env python3
"""
Örnek: Kategoriye göre toplu çekim.
"""

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent / "python"))

from pipeline import ContentPipeline, Category, get_sources

pipeline = ContentPipeline(data_dir="data")

# Yazılım kategorisindeki kaynakları çek
print("▶ Yazılım kategorisi kaynakları:")
sources = get_sources(category=Category.SOFTWARE)
for s in sources:
    print(f"  [{s.priority}] {s.name} — {s.url}")

print(f"\n▶ {len(sources)} kaynak çekiliyor (max 3)...")
items = pipeline.process_category(Category.SOFTWARE, max_items=3)
print(f"✓ {len(items)} tecrübe kaydedildi")

# Tümünü çek
print("\n▶ Tüm kategoriler işleniyor...")
report = pipeline.process_all(max_per_category=1)
for cat, count in report["categories"].items():
    print(f"  {cat}: {count} tecrübe")
print(f"Toplam: {report['total']}")
