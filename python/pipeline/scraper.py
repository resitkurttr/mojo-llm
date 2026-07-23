#!/usr/bin/env python3
"""
mojo-llm scraper — Türkçe web scraping motoru.
Kitap, makale, edebiyat, akademik içerik çekme.
"""

import re
import time
import hashlib
from pathlib import Path
from typing import Dict, List, Optional
from urllib.parse import urlparse, urljoin

try:
    import requests
    from bs4 import BeautifulSoup
    HAS_DEPS = True
except ImportError:
    HAS_DEPS = False

from .fingerprint import Fingerprint
from .logger import ActivityLogger


class ContentScraper:
    """Türkçe web içerik scraper."""

    def __init__(self, logger: Optional[ActivityLogger] = None):
        self.fp = Fingerprint()
        self.logger = logger or ActivityLogger()
        self.cache_dir = Path("data/cache/web")
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        self.session = None
        if HAS_DEPS:
            self.session = requests.Session()

    def fetch(self, url: str, use_cache: bool = True) -> Optional[str]:
        """Sayfayı çek (cache + fingerprint)."""
        # Cache kontrolü
        if use_cache:
            cache_key = hashlib.sha256(url.encode()).hexdigest()[:16]
            cache_file = self.cache_dir / f"{cache_key}.html"
            if cache_file.exists():
                age_hours = (time.time() - cache_file.stat().st_mtime) / 3600
                if age_hours < 24:  # 24 saat cache
                    self.logger.info("cache_hit", {"url": url})
                    return cache_file.read_text(encoding="utf-8")

        if not HAS_DEPS:
            self.logger.error("fetch", "requests/bs4 yüklü değil", {"url": url})
            return None

        try:
            headers = self.fp.get_headers()
            # Let requests handle decompression automatically
            response = self.session.get(url, headers=headers, timeout=15)
            response.raise_for_status()
            # Use text which auto-decodes based on Content-Type
            content = response.text
            self.logger.fetch(url, response.status_code, len(content))

            # Cache'e kaydet
            if use_cache:
                cache_key = hashlib.sha256(url.encode()).hexdigest()[:16]
                cache_file = self.cache_dir / f"{cache_key}.html"
                cache_file.write_text(content, encoding="utf-8")

            # İnsan benzeri gecikme
            self.fp.human_delay(1.0, 3.0)
            return content

        except Exception as e:
            self.logger.error("fetch", str(e), {"url": url})
            return None

    def extract_text(self, html: str, url: str = "") -> Dict:
        """HTML'den metin çıkar."""
        if not HAS_DEPS:
            return {"text": html, "title": "", "links": [], "error": "bs4 yok"}

        soup = BeautifulSoup(html, "html.parser")

        # Script ve stil elemanlarını kaldır
        for tag in soup(["script", "style", "nav", "footer", "header", "aside"]):
            tag.decompose()

        # Başlık
        title = ""
        if soup.title:
            title = soup.title.get_text(strip=True)
        h1 = soup.find("h1")
        if h1:
            title = h1.get_text(strip=True)

        # Ana metin
        # Makale/ikitik/icerik class'larını ara
        content_selectors = [
            "article",
            ".article-content",
            ".entry-content",
            ".post-content",
            ".content",
            "#content",
            ".article-body",
            ".story-body",
            "main",
        ]
        main_text = ""
        for selector in content_selectors:
            elem = soup.select_one(selector)
            if elem:
                main_text = elem.get_text(separator="\n", strip=True)
                break

        if not main_text:
            # Fallback: body'den al
            body = soup.find("body")
            if body:
                main_text = body.get_text(separator="\n", strip=True)

        # Temizle
        main_text = self._clean_text(main_text)

        # Linkler
        links = []
        for a in soup.find_all("a", href=True):
            href = a["href"]
            if href.startswith("http"):
                links.append(href)
            elif href.startswith("/"):
                base = f"{urlparse(url).scheme}://{urlparse(url).netloc}"
                links.append(urljoin(base, href))

        self.logger.parse(url, "html", len(main_text))

        return {
            "title": title,
            "text": main_text,
            "links": links[:50],  # İlk 50 link
            "word_count": len(main_text.split()),
            "char_count": len(main_text),
        }

    def scrape_article(self, url: str) -> Optional[Dict]:
        """Makale/ikitik çek ve ayrıştır."""
        html = self.fetch(url)
        if not html:
            return None
        content = self.extract_text(html, url)
        content["url"] = url
        content["source_type"] = "article"
        return content

    def scrape_page(self, url: str) -> Optional[Dict]:
        """Genel sayfa çekimi."""
        return self.scrape_article(url)

    def scrape_list(self, urls: List[str], max_items: int = 20) -> List[Dict]:
        """Toplu çekim."""
        results = []
        for i, url in enumerate(urls[:max_items]):
            content = self.scrape_article(url)
            if content and content.get("text"):
                results.append(content)
            # Gecikme
            if i < len(urls) - 1:
                self.fp.human_delay(2.0, 5.0)
        return results

    def find_article_links(self, url: str, max_links: int = 20) -> List[str]:
        """Bir sayfadaki makale linklerini bul."""
        html = self.fetch(url)
        if not html or not HAS_DEPS:
            return []

        soup = BeautifulSoup(html, "html.parser")
        base = f"{urlparse(url).scheme}://{urlparse(url).netloc}"
        links = []

        for a in soup.find_all("a", href=True):
            href = a["href"]
            if href.startswith("/"):
                href = urljoin(base, href)
            if not href.startswith("http"):
                continue
            # Makale linklerini filtrele
            parsed = urlparse(href)
            if parsed.netloc and parsed.path and len(parsed.path) > 10:
                if href not in links:
                    links.append(href)
                    if len(links) >= max_links:
                        break

        return links

    def _clean_text(self, text: str) -> str:
        """Metni temizle."""
        # Fazla boşlukları temizle
        text = re.sub(r"\n{3,}", "\n\n", text)
        text = re.sub(r" {2,}", " ", text)
        # Gereksiz satırları kaldır
        lines = []
        for line in text.split("\n"):
            line = line.strip()
            if line and len(line) > 3:  # Çok kısa satırları at
                lines.append(line)
        return "\n".join(lines)

    def is_available(self) -> bool:
        """Scraper kullanılabilir mi?"""
        return HAS_DEPS
