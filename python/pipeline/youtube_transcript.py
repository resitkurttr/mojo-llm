#!/usr/bin/env python3
"""
mojo-llm youtube_transcript — YouTube video transcript çıkarma.
yt-dlp ile transcript, metadata, thumbnail bilgisi.
"""

import json
import subprocess
import re
from pathlib import Path
from typing import Dict, List, Optional, Tuple


class YouTubeTranscript:
    """YouTube transcript çıkarma motoru."""

    def __init__(self, cache_dir: str = "data/cache/youtube"):
        self.cache_dir = Path(cache_dir)
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        self._installed = self._check_ytdlp()

    def _check_ytdlp(self) -> bool:
        """yt-dlp yüklü mü kontrol et."""
        try:
            result = subprocess.run(
                ["yt-dlp", "--version"],
                capture_output=True, text=True, timeout=10
            )
            return result.returncode == 0
        except (FileNotFoundError, subprocess.TimeoutExpired):
            return False

    def install_ytdlp(self) -> bool:
        """yt-dlp yükle."""
        try:
            subprocess.run(
                ["pip", "install", "-U", "yt-dlp"],
                capture_output=True, text=True, timeout=120
            )
            self._installed = self._check_ytdlp()
            return self._installed
        except Exception:
            return False

    def get_video_id(self, url: str) -> Optional[str]:
        """URL'den video ID çıkar."""
        patterns = [
            r'(?:v=|/v/|youtu\.be/)([a-zA-Z0-9_-]{11})',
            r'(?:embed/)([a-zA-Z0-9_-]{11})',
            r'^([a-zA-Z0-9_-]{11})$',
        ]
        for pattern in patterns:
            match = re.search(pattern, url)
            if match:
                return match.group(1)
        return None

    def get_metadata(self, url: str) -> Dict:
        """Video metadata bilgisi."""
        if not self._installed:
            return {"error": "yt-dlp yüklü değil"}

        try:
            result = subprocess.run(
                ["yt-dlp", "--dump-json", "--no-download", url],
                capture_output=True, text=True, timeout=30
            )
            if result.returncode == 0:
                data = json.loads(result.stdout)
                return {
                    "id": data.get("id"),
                    "title": data.get("title"),
                    "uploader": data.get("uploader"),
                    "duration": data.get("duration"),
                    "description": data.get("description", "")[:500],
                    "view_count": data.get("view_count"),
                    "upload_date": data.get("upload_date"),
                    "language": data.get("language"),
                    "subtitles": list(data.get("subtitles", {}).keys()),
                    "auto_captions": list(data.get("automatic_captions", {}).keys()),
                }
            return {"error": result.stderr[:200]}
        except Exception as e:
            return {"error": str(e)}

    def get_transcript(self, url: str, lang: str = "tr") -> Optional[str]:
        """Video transcript'ını çıkar."""
        video_id = self.get_video_id(url)
        if not video_id:
            return None

        # Önbellek kontrolü
        cache_file = self.cache_dir / f"{video_id}_{lang}.txt"
        if cache_file.exists():
            return cache_file.read_text(encoding="utf-8")

        if not self._installed:
            return None

        try:
            # Manuel altyazı dene
            result = subprocess.run(
                [
                    "yt-dlp",
                    "--write-sub",
                    "--write-auto-sub",
                    "--sub-lang", lang,
                    "--sub-format", "vtt",
                    "--skip-download",
                    "-o", str(self.cache_dir / f"{video_id}"),
                    url
                ],
                capture_output=True, text=True, timeout=60
            )

            # Altyazı dosyasını bul
            for f in self.cache_dir.glob(f"{video_id}*.{lang}*.vtt"):
                content = self._parse_vtt(f.read_text(encoding="utf-8"))
                cache_file.write_text(content, encoding="utf-8")
                return content

            # Türkçe yoksa İngilizce dene
            if lang != "en":
                return self.get_transcript(url, "en")

            return None
        except Exception:
            return None

    def get_batch_transcripts(self, urls: List[str], lang: str = "tr") -> List[Dict]:
        """Toplu transcript çıkarma."""
        results = []
        for url in urls:
            video_id = self.get_video_id(url)
            metadata = self.get_metadata(url)
            transcript = self.get_transcript(url, lang)
            results.append({
                "url": url,
                "video_id": video_id,
                "metadata": metadata,
                "transcript": transcript,
                "has_transcript": transcript is not None,
            })
        return results

    def _parse_vtt(self, vtt_content: str) -> str:
        """VTT formatını temizle."""
        lines = []
        for line in vtt_content.split("\n"):
            line = line.strip()
            # Zaman damgası satırlarını atla
            if "-->" in line:
                continue
            if line.startswith("WEBVTT"):
                continue
            if line.startswith("Kind:"):
                continue
            if line.startswith("Language:"):
                continue
            if not line:
                continue
            # HTML etiketlerini temizle
            line = re.sub(r"<[^>]+>", "", line)
            # Boşlukları düzelt
            line = re.sub(r"\s+", " ", line)
            if line and line not in lines[-1:]:  # Tekrarları engelle
                lines.append(line)
        return " ".join(lines)

    def search_channel_videos(self, channel_url: str, max_videos: int = 10) -> List[str]:
        """Kanalın son videolarını bul."""
        if not self._installed:
            return []
        try:
            result = subprocess.run(
                [
                    "yt-dlp",
                    "--flat-playlist",
                    "--print", "id",
                    "--playlist-end", str(max_videos),
                    channel_url
                ],
                capture_output=True, text=True, timeout=60
            )
            if result.returncode == 0:
                return [
                    f"https://www.youtube.com/watch?v={line.strip()}"
                    for line in result.stdout.strip().split("\n")
                    if line.strip()
                ]
            return []
        except Exception:
            return []

    def is_available(self) -> bool:
        """yt-dlp kullanılabilir mi?"""
        return self._installed
