#!/usr/bin/env python3
"""
mojo-llm content_pipeline — Ana pipeline.
scrape → parse → chunk → learn → log döngüsü.
"""

import json
import hashlib
import time
from pathlib import Path
from typing import Dict, List, Optional
from datetime import datetime

from .scraper import ContentScraper
from .youtube_transcript import YouTubeTranscript
from .logger import ActivityLogger
from .fingerprint import Fingerprint
from .sources import Source, SourceType, Category, get_sources, get_youtube_channels


class ContentPipeline:
    """İçerik işleme pipeline'ı.

    Akış:
    1. Kaynaklardan URL topla
    2. İçeriği çek (web scraping veya YouTube transcript)
    3. Metni chunk'lara böl
    4. Her chunk'ı tecrübe olarak kaydet
    5. Log tut
    """

    def __init__(self, data_dir: str = "data", log_level: str = "info"):
        self.data_dir = Path(data_dir)
        self.data_dir.mkdir(parents=True, exist_ok=True)

        self.logger = ActivityLogger(
            log_dir=str(self.data_dir / "logs"),
            level=log_level,
        )
        self.scraper = ContentScraper(logger=self.logger)
        self.youtube = YouTubeTranscript(
            cache_dir=str(self.data_dir / "cache" / "youtube")
        )
        self.fp = Fingerprint()

        self.experiences_dir = self.data_dir / "experiences"
        self.experiences_dir.mkdir(parents=True, exist_ok=True)

        self._stats = {
            "total_fetched": 0,
            "total_chunks": 0,
            "total_experiences": 0,
            "errors": 0,
        }

    # ═══════════════════════════════════════════════════════════
    # Ana Pipeline Fonksiyonları
    # ═══════════════════════════════════════════════════════════

    def process_url(self, url: str, source_type: str = "auto") -> List[Dict]:
        """Tek URL işle."""
        if source_type == "auto":
            source_type = self._detect_type(url)

        if source_type == "youtube":
            return self._process_youtube(url)
        else:
            return self._process_web(url)

    def process_urls(self, urls: List[str], max_items: int = 20) -> List[Dict]:
        """Çoklu URL işle."""
        results = []
        for i, url in enumerate(urls[:max_items]):
            try:
                items = self.process_url(url)
                results.extend(items)
                self._stats["total_fetched"] += 1
            except Exception as e:
                self.logger.error("process_url", str(e), {"url": url})
                self._stats["errors"] += 1
            # Gecikme
            if i < len(urls) - 1:
                self.fp.human_delay(2.0, 5.0)
        return results

    def process_source(self, source: Source, max_items: int = 10) -> List[Dict]:
        """Tek kaynak işle."""
        if source.source_type == SourceType.YOUTUBE:
            return self._process_youtube_channel(source.url, max_items)
        else:
            return self._process_web_source(source, max_items)

    def process_category(
        self, category: Category, max_items: int = 20
    ) -> List[Dict]:
        """Kategorideki tüm kaynakları işle."""
        sources = get_sources(category=category)
        results = []
        for source in sources:
            items = self.process_source(source, max_items=min(max_items, 5))
            results.extend(items)
            if len(results) >= max_items:
                break
        return results

    def process_all(self, max_per_category: int = 5) -> Dict:
        """Tüm kategorileri işle."""
        report = {"categories": {}, "total": 0}
        for cat in Category:
            items = self.process_category(cat, max_per_category)
            report["categories"][cat.value] = len(items)
            report["total"] += len(items)
            self.logger.info(
                "category_done",
                {"category": cat.value, "items": len(items)},
            )
        return report

    # ═══════════════════════════════════════════════════════════
    # Web İşleme
    # ═══════════════════════════════════════════════════════════

    def _process_web(self, url: str) -> List[Dict]:
        """Web sayfasını işle: çek → chunk → kaydet."""
        content = self.scraper.scrape_article(url)
        if not content or not content.get("text"):
            return []

        chunks = self.chunk_text(content["text"])
        experiences = []
        for i, chunk in enumerate(chunks):
            exp = {
                "source": url,
                "title": content.get("title", ""),
                "chunk_index": i,
                "text": chunk,
                "word_count": len(chunk.split()),
                "timestamp": datetime.now().isoformat(),
                "hash": hashlib.sha256(chunk.encode()).hexdigest()[:16],
            }
            experiences.append(exp)

        # Tecrübeleri kaydet
        self._save_experiences(experiences)
        self._stats["total_chunks"] += len(chunks)
        self._stats["total_experiences"] += len(experiences)

        self.logger.info(
            "web_processed",
            {"url": url, "chunks": len(chunks), "chars": content.get("char_count", 0)},
        )
        return experiences

    def _process_web_source(self, source: Source, max_items: int = 10) -> List[Dict]:
        """Web kaynağı işle: linkleri bul → çek."""
        links = self.scraper.find_article_links(source.url, max_links=max_items)
        if not links:
            # Direkt sayfayı çek
            return self._process_web(source.url)
        return self.process_urls(links, max_items=max_items)

    # ═══════════════════════════════════════════════════════════
    # YouTube İşleme
    # ═══════════════════════════════════════════════════════════

    def _process_youtube(self, url: str) -> List[Dict]:
        """YouTube videosunu işle."""
        metadata = self.youtube.get_metadata(url)
        transcript = self.youtube.get_transcript(url)

        if not transcript:
            self.logger.info("youtube_no_transcript", {"url": url})
            return []

        title = metadata.get("title", "Unknown")
        video_id = metadata.get("id", "unknown")
        duration = metadata.get("duration", 0)

        self.logger.transcribe(video_id, title, duration or 0)

        chunks = self.chunk_text(transcript)
        experiences = []
        for i, chunk in enumerate(chunks):
            exp = {
                "source": url,
                "title": title,
                "source_type": "youtube",
                "video_id": video_id,
                "duration": duration,
                "chunk_index": i,
                "text": chunk,
                "word_count": len(chunk.split()),
                "timestamp": datetime.now().isoformat(),
                "hash": hashlib.sha256(chunk.encode()).hexdigest()[:16],
            }
            experiences.append(exp)

        self._save_experiences(experiences)
        self._stats["total_chunks"] += len(chunks)
        self._stats["total_experiences"] += len(experiences)
        return experiences

    def _process_youtube_channel(self, channel_url: str, max_videos: int = 5) -> List[Dict]:
        """YouTube kanalının son videolarını işle."""
        video_urls = self.youtube.search_channel_videos(channel_url, max_videos)
        if not video_urls:
            return []

        all_experiences = []
        for url in video_urls:
            exps = self._process_youtube(url)
            all_experiences.extend(exps)
            self.fp.human_delay(2.0, 5.0)
        return all_experiences

    # ═══════════════════════════════════════════════════════════
    # Metin İşleme
    # ═══════════════════════════════════════════════════════════

    def chunk_text(self, text: str, chunk_size: int = 500, overlap: int = 50) -> List[str]:
        """Metni chunk'lara böl."""
        words = text.split()
        if len(words) <= chunk_size:
            return [text]

        chunks = []
        start = 0
        while start < len(words):
            end = start + chunk_size
            chunk_words = words[start:end]
            chunk = " ".join(chunk_words)
            chunks.append(chunk)
            start = end - overlap  # Overlap ile ilerle
        return chunks

    def extract_key_sentences(self, text: str, max_sentences: int = 5) -> List[str]:
        """En önemli cümleleri çıkar."""
        import re
        sentences = re.split(r'[.!?]+', text)
        sentences = [s.strip() for s in sentences if len(s.strip()) > 20]

        # Uzunluğa göre sırala (basit importance proxy)
        scored = [(len(s.split()), s) for s in sentences]
        scored.sort(reverse=True)
        return [s for _, s in scored[:max_sentences]]

    # ═══════════════════════════════════════════════════════════
    # Kaydetme
    # ═══════════════════════════════════════════════════════════

    def _save_experiences(self, experiences: List[Dict]):
        """Tecrübeleri dosyaya kaydet."""
        if not experiences:
            return

        today = datetime.now().strftime("%Y-%m-%d")
        file_path = self.experiences_dir / f"experiences_{today}.jsonl"

        with open(file_path, "a", encoding="utf-8") as f:
            for exp in experiences:
                f.write(json.dumps(exp, ensure_ascii=False) + "\n")

        # Log
        for exp in experiences:
            key_sentences = self.extract_key_sentences(exp["text"], 2)
            summary = " | ".join(key_sentences)
            self.logger.experience(
                exp["source"], 0.5, summary  # Score henüz yok
            )

    def load_experiences(self, date: Optional[str] = None) -> List[Dict]:
        """Tecrübeleri yükle."""
        if date is None:
            date = datetime.now().strftime("%Y-%m-%d")

        file_path = self.experiences_dir / f"experiences_{date}.jsonl"
        if not file_path.exists():
            return []

        experiences = []
        with open(file_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line:
                    experiences.append(json.loads(line))
        return experiences

    # ═══════════════════════════════════════════════════════════
    # Yardımcı Fonksiyonlar
    # ═══════════════════════════════════════════════════════════

    def _detect_type(self, url: str) -> str:
        """URL tipini algıla."""
        if "youtube.com" in url or "youtu.be" in url:
            return "youtube"
        return "web"

    def stats(self) -> Dict:
        """İstatistikleri döndür."""
        return {**self._stats, **self.logger.stats()}

    def summary(self) -> str:
        """İnsan okunabilir özet."""
        s = "═══ Content Pipeline Özeti ═══\n"
        s += f"  Çekilen: {self._stats['total_fetched']}\n"
        s += f"  Chunk: {self._stats['total_chunks']}\n"
        s += f"  Tecrübe: {self._stats['total_experiences']}\n"
        s += f"  Hata: {self._stats['errors']}\n"
        s += self.logger.summary()
        return s
