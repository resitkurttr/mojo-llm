#!/usr/bin/env python3
"""
mojo-llm fingerprint — Parmak izi bırakmadan gezinme.
User-Agent rotation, referer spoofing, rate limiting.
"""

import random
import time
import hashlib
from typing import Dict, Optional

USER_AGENTS = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:133.0) Gecko/20100101 Firefox/133.0",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:133.0) Gecko/20100101 Firefox/133.0",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.2 Safari/605.1.15",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36 Edg/131.0.0.0",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
    "Mozilla/5.0 (iPhone; CPU iPhone OS 18_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.2 Mobile/15E148 Safari/604.1",
    "Mozilla/5.0 (Linux; Android 14; SM-S928B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36",
]

ACCEPT_LANGUAGES = [
    "tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7",
    "tr-TR,tr;q=0.9",
    "tr,en-US;q=0.8,en;q=0.7",
]


class Fingerprint:
    """Tarayıcı parmak izi yöneticisi."""

    def __init__(self, seed: Optional[int] = None):
        self.rng = random.Random(seed or int(time.time()))
        self.session_ua = self._pick_ua()
        self.session_id = hashlib.sha256(
            f"{time.time()}{self.session_ua}".encode()
        ).hexdigest()[:16]
        self._request_count = 0

    def _pick_ua(self) -> str:
        return self.rng.choice(USER_AGENTS)

    def get_headers(self, referer: Optional[str] = None) -> Dict[str, str]:
        """Her istek için farklı headers döndür."""
        self._request_count += 1
        headers = {
            "User-Agent": self.rng.choice(USER_AGENTS),
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
            "Accept-Language": self.rng.choice(ACCEPT_LANGUAGES),
            # Don't set Accept-Encoding - requests handles decompression
            "DNT": "1",
            "Connection": "keep-alive",
            "Upgrade-Insecure-Requests": "1",
            "Sec-Fetch-Dest": "document",
            "Sec-Fetch-Mode": "navigate",
            "Sec-Fetch-Site": "none" if not referer else "cross-site",
            "Cache-Control": "max-age=0",
        }
        if referer:
            headers["Referer"] = referer
        return headers

    def human_delay(self, min_s: float = 1.0, max_s: float = 5.0):
        """İnsan benzeri gecikme."""
        delay = self.rng.uniform(min_s, max_s)
        time.sleep(delay)

    def rotate_session(self):
        """Yeni oturum başlat."""
        self.session_ua = self._pick_ua()
        self.session_id = hashlib.sha256(
            f"{time.time()}{self.session_ua}".encode()
        ).hexdigest()[:16]

    def stats(self) -> str:
        return f"Fingerprint: session={self.session_id}, requests={self._request_count}"
