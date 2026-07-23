#!/usr/bin/env python3
"""
mojo-llm — Ana çalıştırıcı.
Python pipeline + Mojo engine birlikte kullanım.

Kullanım:
  python main.py --mode web --category yazilim --max 5
  python main.py --mode youtube --channel "Ege Acar" --max 3
  python main.py --mode all --max 2
  python main.py --mode sources
  python main.py --mode stats
"""

import argparse
import sys
import json
from pathlib import Path

# Pipeline import
sys.path.insert(0, str(Path(__file__).parent))
from pipeline import (
    ContentPipeline,
    Category,
    SourceType,
    get_sources,
    source_stats,
)


def cmd_sources():
    """Mevcut kaynakları göster."""
    print(source_stats())


def cmd_web(args):
    """Web içerik çek."""
    pipeline = ContentPipeline(data_dir="data")

    if args.url:
        print(f"▶ URL çekiliyor: {args.url}")
        items = pipeline.process_url(args.url)
        print(f"  ✓ {len(items)} tecrübe kaydedildi")
    elif args.category:
        try:
            cat = Category(args.category)
        except ValueError:
            print(f"✗ Bilinmeyen kategori: {args.category}")
            print(f"  Mevcut: {', '.join(c.value for c in Category)}")
            return
        print(f"▶ Kategori: {cat.value}")
        items = pipeline.process_category(cat, max_items=args.max)
        print(f"  ✓ {len(items)} tecrübe kaydedildi")
    else:
        print("▶ Tüm kategoriler işleniyor...")
        report = pipeline.process_all(max_per_category=args.max)
        print(f"  ✓ Toplam: {report['total']} tecrübe")
        for cat, count in report["categories"].items():
            print(f"    {cat}: {count}")

    print(pipeline.summary())


def cmd_stats():
    """İstatistikleri göster."""
    pipeline = ContentPipeline(data_dir="data")
    stats = pipeline.stats()
    print("═══ mojo-llm İstatistikleri ═══")
    print(json.dumps(stats, indent=2, ensure_ascii=False))


def main():
    parser = argparse.ArgumentParser(
        description="mojo-llm — Türkçe içerik çekme ve öğrenme",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Örnekler:
  %(prog)s --mode sources                    Kaynakları listele
  %(prog)s --mode web --category yazilim     Yazılım kategorisini çek
  %(prog)s --mode web --url https://...      Tek URL çek
  %(prog)s --mode youtube --channel "Ege Acar"
  %(prog)s --mode all --max 2               Tümünü çek
  %(prog)s --mode stats                      İstatistikleri göster
        """,
    )

    parser.add_argument(
        "--mode",
        choices=["web", "all", "sources", "stats"],
        default="sources",
        help="Çalışma modu",
    )
    parser.add_argument("--url", help="Tek URL")
    parser.add_argument("--channel", help="YouTube kanal adı")
    parser.add_argument(
        "--category",
        choices=[c.value for c in Category],
        help="Kategori filtresi",
    )
    parser.add_argument("--max", type=int, default=5, help="Maks öğe sayısı")
    parser.add_argument("--log-level", default="info", help="Log seviyesi")

    args = parser.parse_args()

    print("═══════════════════════════════════════════════")
    print("  mojo-llm v0.4.0 — Türkçe İçerik Pipeline")
    print("═══════════════════════════════════════════════\n")

    if args.mode == "sources":
        cmd_sources()
    elif args.mode == "web":
        cmd_web(args)
    elif args.mode == "all":
        cmd_web(args)
    elif args.mode == "stats":
        cmd_stats()


if __name__ == "__main__":
    main()
