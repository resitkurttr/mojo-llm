#!/usr/bin/env python3
"""
mojo-llm sources — Türkçe kaynak listesi.
Kitaplar, dergiler, akademik makaleler, edebi metinler, YouTube kanalları.
"""

from dataclasses import dataclass, field
from typing import List, Optional
from enum import Enum


class SourceType(Enum):
    BOOK = "book"
    ARTICLE = "article"
    ACADEMIC = "academic"
    LITERARY = "literary"
    NEWS = "news"
    YOUTUBE = "youtube"
    FORUM = "forum"
    BLOG = "blog"


class Category(Enum):
    SOFTWARE = "yazilim"
    LITERATURE = "edebiyat"
    PHILOSOPHY = "felsefe"
    SCIENCE = "bilim"
    HISTORY = "tarih"
    MATHEMATICS = "matematik"
    AI = "yapay-zeka"
    GENERAL = "genel"


@dataclass
class Source:
    name: str
    url: str
    source_type: SourceType
    category: Category
    language: str = "tr"
    priority: int = 5  # 1-10, en yüksek
    tags: List[str] = field(default_factory=list)
    enabled: bool = True


# ═══════════════════════════════════════════════════════════════
# Türkçe Kaynak Havuzu
# ═══════════════════════════════════════════════════════════════

TURKISH_SOURCES: List[Source] = [
    # ── Yazılım / Teknoloji ──
    Source("Ekşi Sözlük - Yazılım", "https://eksisozluk.com/yazilim--1706183", SourceType.FORUM, Category.SOFTWARE, priority=7, tags=["yazılım", "gündem"]),
    Source("Donanım Haber", "https://www.donanimhaber.com/", SourceType.NEWS, Category.SOFTWARE, priority=6, tags=["teknoloji", "donanım"]),
    Source("Shiftdelete.net", "https://shiftdelete.net/", SourceType.NEWS, Category.SOFTWARE, priority=6, tags=["teknoloji", "yazılım"]),
    Source("Webrazzi", "https://webrazzi.com/", SourceType.BLOG, Category.SOFTWARE, priority=7, tags=["startup", "tech", "yazılım"]),
    Source("Dijital Ajanslar", "https://dijitalajanslar.com/", SourceType.BLOG, Category.SOFTWARE, priority=5, tags=["dijital", "pazarlama"]),
    Source("Medium - Türkçe Yazılım", "https://medium.com/tag/yaz%C4%B1l%C4%B1m développement", SourceType.BLOG, Category.SOFTWARE, priority=7, tags=["yazılım", "makale"]),
    Source("Yazilim Uzmanı", "https://www.yazilimuzmani.com.tr/", SourceType.BLOG, Category.SOFTWARE, priority=6, tags=["yazılım", "eğitim"]),
    Source("Hacker News Türkçe", "https://news.ycombinator.com/", SourceType.FORUM, Category.SOFTWARE, priority=8, tags=["tech", "startup", "hacker"]),

    # ── Edebiyat / Şiir ──
    Source("Kitap Zamanı", "https://www.kitapzamani.com.tr/", SourceType.BOOK, Category.LITERATURE, priority=8, tags=["kitap", "inceleme"]),
    Source("Edebiyat Nöbeti", "https://edebiyatnöbeti.com/", SourceType.BLOG, Category.LITERATURE, priority=7, tags=["edebiyat", "şiir"]),
    Source("İnsancıl", "https://www.insancil.com/", SourceType.BLOG, Category.LITERATURE, priority=7, tags=["edebiyat", "çeviri"]),
    Source("Notos Kitap", "https://www.notoskitap.com/", SourceType.BOOK, Category.LITERATURE, priority=6, tags=["kitap", "yayın"]),
    Source("K24 - Kitap", "https://k24.com.tr/", SourceType.BLOG, Category.LITERATURE, priority=8, tags=["kitap", "edebiyat", "eleştiri"]),
    Source("Sabit Fikir", "https://sabitfikir.com/", SourceType.BLOG, Category.LITERATURE, priority=7, tags=["kitap", "sinema", "kültür"]),
    Source("Özgür İfade", "https://www.ozgurifade.com/", SourceType.BLOG, Category.LITERATURE, priority=5, tags=["şiir", "edebiyat"]),

    # ── Felsefe / Düşünce ──
    Source("Felsefe Portalı", "https://www.felsefeportali.com/", SourceType.BLOG, Category.PHILOSOPHY, priority=7, tags=["felsefe", "düşünce"]),
    Source("Birikim Dergisi", "https://www.birikimdergisi.com/", SourceType.ACADEMIC, Category.PHILOSOPHY, priority=8, tags=["felsefe", "siyaset", "kültür"]),
    Source("Metis Yayınları Blog", "https://www.metis.com.tr/", SourceType.BOOK, Category.PHILOSOPHY, priority=6, tags=["felsefe", "kitap"]),

    # ── Bilim ──
    Source("Bilim ve Teknik", "https://www.bilimveteknik.gov.tr/", SourceType.ACADEMIC, Category.SCIENCE, priority=8, tags=["bilim", "teknik"]),
    Source("Evrim Ağacı", "https://evrimagaci.org/", SourceType.BLOG, Category.SCIENCE, priority=8, tags=["bilim", "evrim", "popüler bilim"]),
    Source("Kozmik Anafor", "https://www.kozmikanfor.com/", SourceType.BLOG, Category.SCIENCE, priority=6, tags=["uzay", "fizik", "bilim"]),

    # ── Tarih ──
    Source("Tarih Dergisi", "https://www.tarihdergisi.com/", SourceType.ACADEMIC, Category.HISTORY, priority=6, tags=["tarih", "akademik"]),
    Source("Belgesel TV", "https://www.belgeseltv.com.tr/", SourceType.BLOG, Category.HISTORY, priority=5, tags=["tarih", "belgesel"]),

    # ── Yapay Zeka ──
    Source("Yapay Zeka Türkiye", "https://yapayzekaturkiye.com/", SourceType.BLOG, Category.AI, priority=7, tags=["yapay-zeka", "ml"]),
    Source("Turkish AI Solutions", "https://turkishaisolutions.com/", SourceType.BLOG, Category.AI, priority=5, tags=["yapay-zeka", "startup"]),

    # ── Akademik ──
    Source("YÖK Tez Merkezi", "https://tez.yok.gov.tr/", SourceType.ACADEMIC, Category.GENERAL, priority=6, tags=["tez", "akademik"]),
    Source("DergiPark", "https://dergipark.org.tr/", SourceType.ACADEMIC, Category.GENERAL, priority=7, tags=["dergi", "akademik", "makale"]),
    Source("TR Dizin", "https://www.trdizin.gov.tr/", SourceType.ACADEMIC, Category.GENERAL, priority=7, tags=["akademik", "makale"]),

    # ── YouTube Kanalları (Türkçe) ──
    Source("Ege Acar", "https://www.youtube.com/@EgeAcar", SourceType.YOUTUBE, Category.SOFTWARE, priority=8, tags=["yazılım", "python", "eğitim"]),
    Source("Kodlama TV", "https://www.youtube.com/@kodlamatv", SourceType.YOUTUBE, Category.SOFTWARE, priority=7, tags=["yazılım", "programlama"]),
    Source("Emrah Yücel", "https://www.youtube.com/@emrahyucel", SourceType.YOUTUBE, Category.AI, priority=7, tags=["yapay-zeka", "ml", "python"]),
    Source("Yazılım Günlüğü", "https://www.youtube.com/@yazilimgunlugu", SourceType.YOUTUBE, Category.SOFTWARE, priority=6, tags=["yazılım", "kariyer"]),
    Source("Barış Özcan", "https://www.youtube.com/@barisozcan", SourceType.YOUTUBE, Category.SCIENCE, priority=8, tags=["bilim", "teknoloji", "sanat"]),
    Source("Bilim Adamı", "https://www.youtube.com/@bilimadami", SourceType.YOUTUBE, Category.SCIENCE, priority=7, tags=["bilim", "popüler"]),
    Source("Felsefe Sokağı", "https://www.youtube.com/@felsefesokagi", SourceType.YOUTUBE, Category.PHILOSOPHY, priority=7, tags=["felsefe", "düşünce"]),
    Source("Tarihçe", "https://www.youtube.com/@tarihce", SourceType.YOUTUBE, Category.HISTORY, priority=6, tags=["tarih", "osmanlı"]),
]


def get_sources(
    category: Optional[Category] = None,
    source_type: Optional[SourceType] = None,
    min_priority: int = 1,
    enabled_only: bool = True,
) -> List[Source]:
    """Kaynakları filtrele."""
    results = []
    for s in TURKISH_SOURCES:
        if enabled_only and not s.enabled:
            continue
        if category and s.category != category:
            continue
        if source_type and s.source_type != source_type:
            continue
        if s.priority < min_priority:
            continue
        results.append(s)
    return sorted(results, key=lambda x: x.priority, reverse=True)


def get_youtube_channels() -> List[Source]:
    """Sadece YouTube kanallarını döndür."""
    return get_sources(source_type=SourceType.YOUTUBE)


def get_academic_sources() -> List[Source]:
    """Akademik kaynakları döndür."""
    return get_sources(source_type=SourceType.ACADEMIC)


def source_stats() -> str:
    """Kaynak istatistikleri."""
    type_counts = {}
    cat_counts = {}
    for s in TURKISH_SOURCES:
        type_counts[s.source_type.value] = type_counts.get(s.source_type.value, 0) + 1
        cat_counts[s.category.value] = cat_counts.get(s.category.value, 0) + 1

    lines = ["Türkçe Kaynak Havuzu"]
    lines.append(f"  Toplam: {len(TURKISH_SOURCES)}")
    lines.append("  Tipler:")
    for t, c in sorted(type_counts.items()):
        lines.append(f"    {t}: {c}")
    lines.append("  Kategoriler:")
    for cat, c in sorted(cat_counts.items()):
        lines.append(f"    {cat}: {c}")
    return "\n".join(lines)
