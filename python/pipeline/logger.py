#!/usr/bin/env python3
"""
mojo-llm logger — Aktivite log sistemi.
Her işlemi dosyaya kaydeder, zaman damgası ekler.
"""

import json
import os
import time
from pathlib import Path
from typing import Any, Optional
from datetime import datetime


class ActivityLogger:
    """Aktivite log yöneticisi."""

    def __init__(self, log_dir: str = "data/logs", level: str = "info"):
        self.log_dir = Path(log_dir)
        self.log_dir.mkdir(parents=True, exist_ok=True)
        self.level = level
        self.session_id = datetime.now().strftime("%Y%m%d_%H%M%S")
        self._counters = {
            "pages_fetched": 0,
            "articles_parsed": 0,
            "videos_transcribed": 0,
            "experiences_stored": 0,
            "errors": 0,
        }

    def _log_file(self) -> Path:
        """Günlük dosyası."""
        today = datetime.now().strftime("%Y-%m-%d")
        return self.log_dir / f"activity_{today}.jsonl"

    def _write(self, entry: dict):
        """JSONL dosyasına yaz."""
        entry["timestamp"] = datetime.now().isoformat()
        entry["session"] = self.session_id
        with open(self._log_file(), "a", encoding="utf-8") as f:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")

    def info(self, action: str, details: Optional[dict] = None):
        """Bilgi seviyesi log."""
        entry = {"level": "info", "action": action}
        if details:
            entry["details"] = details
        self._write(entry)

    def error(self, action: str, error: str, details: Optional[dict] = None):
        """Hata log."""
        self._counters["errors"] += 1
        entry = {"level": "error", "action": action, "error": error}
        if details:
            entry["details"] = details
        self._write(entry)

    def fetch(self, url: str, status: int, size: int):
        """Sayfa çekme logu."""
        self._counters["pages_fetched"] += 1
        self._write({
            "level": "info",
            "action": "fetch",
            "url": url,
            "status": status,
            "size_bytes": size,
        })

    def parse(self, url: str, content_type: str, chars: int):
        """Parse logu."""
        self._counters["articles_parsed"] += 1
        self._write({
            "level": "info",
            "action": "parse",
            "url": url,
            "content_type": content_type,
            "chars": chars,
        })

    def transcribe(self, video_id: str, title: str, duration: int):
        """YouTube transcript logu."""
        self._counters["videos_transcribed"] += 1
        self._write({
            "level": "info",
            "action": "transcribe",
            "video_id": video_id,
            "title": title,
            "duration_s": duration,
        })

    def experience(self, source: str, score: float, summary: str):
        """Tecrübe kaydı logu."""
        self._counters["experiences_stored"] += 1
        self._write({
            "level": "info",
            "action": "experience",
            "source": source,
            "score": score,
            "summary": summary[:200],
        })

    def counter(self, name: str, value: int = 1):
        """Sayaç artır."""
        if name in self._counters:
            self._counters[name] += value

    def stats(self) -> dict:
        """İstatistikleri döndür."""
        return {
            "session": self.session_id,
            "counters": self._counters.copy(),
        }

    def summary(self) -> str:
        """İnsan okunabilir özet."""
        s = f"Logger [{self.session_id}]\n"
        for k, v in self._counters.items():
            s += f"  {k}: {v}\n"
        return s

    def read_today(self) -> list:
        """Bugünün loglarını oku."""
        entries = []
        log_file = self._log_file()
        if log_file.exists():
            with open(log_file, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if line:
                        entries.append(json.loads(line))
        return entries
