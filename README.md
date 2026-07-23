# mojo-llm v0.4.0

**Kendi kendine öğrenen, agentic Mojo LLM sistemi.**

Mojo + Python ile yazılmış, doğrulama tabanlı öğrenme sistemi. Türkçe içerik çekme, tecrübe oluşturma ve hiyerarşik bellek ile çalışır.

## Mimari

```
mojo-llm/
├── main.mojo                    # Orijinal tek dosya iskelet (905 satır)
├── src/                         # Mojo modülleri
│   ├── cli.mojo                 # CLI arayüzü
│   ├── config.mojo              # Konfigürasyon
│   ├── core/
│   │   └── flash_attention.mojo # Flash Attention V2
│   └── engine/
│       ├── verification.mojo    # Doğrulama sistemi
│       ├── experience.mojo      # Tecrübe kütüphanesi
│       ├── memory.mojo          # 3 katmanlı bellek
│       ├── self_learning.mojo   # Kendi kendine öğrenme
│       ├── agent.mojo           # Agentic orchestration
│       ├── tool_use.mojo        # Tool registry
│       ├── multi_agent.mojo     # Orchestrator/Worker
│       ├── web_browser.mojo     # Web erişimi
│       ├── api_server.mojo      # OpenAI-uyumlu API
│       ├── save_load.mojo       # Model kaydetme
│       └── gguf.mojo            # GGUF format desteği
├── python/                      # Python pipeline
│   ├── main.py                  # Ana çalıştırıcı
│   └── pipeline/
│       ├── fingerprint.py       # UA rotation, parmak izi
│       ├── logger.py            # Aktivite log (JSONL)
│       ├── scraper.py           # Web scraping motoru
│       ├── sources.py           # Türkçe kaynak listesi
│       ├── youtube_transcript.py# YouTube transcript
│       └── content_pipeline.py  # Ana pipeline
├── configs/
│   ├── mobile.json              # Mobil cihaz ayarları
│   └── server.json              # Sunucu ayarları
├── examples/
│   ├── scrape_url.py            # Tek URL çekme
│   └── scrape_category.py       # Kategoriye göre çekme
├── tests/
│   ├── test_verification.mojo
│   └── test_experience.mojo
└── requirements.txt
```

## Mojo Modülleri (16 modül, 3,888 satır)

| Modül | Dosya | Açıklama |
|-------|-------|----------|
| Flash Attention | `src/core/flash_attention.mojo` | V2, tile-based, O(N) bellek |
| Doğrulama | `src/engine/verification.mojo` | Mantık, koherans, gerçeklik |
| Tecrübe | `src/engine/experience.mojo` | Hiyerarşik sıkıştırma, semantic hash |
| Bellek | `src/engine/memory.mojo` | 3 katman, unutma eğrisi |
| Öğrenme | `src/engine/self_learning.mojo` | Doğrulama tabanlı döngü |
| Ajan | `src/engine/agent.mojo` | Görev, plan, orkestratör |
| Tool Use | `src/engine/tool_use.mojo` | 12 tool, OpenAI schema |
| Multi-Agent | `src/engine/multi_agent.mojo` | Orchestrator/Worker |
| Web | `src/engine/web_browser.mojo` | HTTP, arama, cache |
| API | `src/engine/api_server.mojo` | OpenAI-uyumlu /v1/ |
| Kaydet | `src/engine/save_load.mojo` | Binary, quantization-aware |
| GGUF | `src/engine/gguf.mojo` | GGUF format okuma/yazma |

## Python Pipeline (7 modül, 1,219 satır)

| Modül | Dosya | Açıklama |
|-------|-------|----------|
| Fingerprint | `pipeline/fingerprint.py` | UA rotation, parmak izi spoofing |
| Logger | `pipeline/logger.py` | JSONL aktivite logu |
| Scraper | `pipeline/scraper.py` | Web scraping motoru |
| Sources | `pipeline/sources.py` | 28 Türkçe kaynak listesi |
| YouTube | `pipeline/youtube_transcript.py` | Transcript çıkarma |
| Pipeline | `pipeline/content_pipeline.py` | scrape → parse → chunk → learn |

## Kurulum

### Mojo
```bash
curl -fsSL https://get.modular.com | MODULAR_HOME=$HOME/.modular bash -
source ~/.bashrc
mojo --version  # >= 0.26.2
```

### Python
```bash
git clone https://github.com/resitkurttr/mojo-llm.git
cd mojo-llm
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Kullanım

### Mojo
```bash
mojo run main.mojo info tiny
mojo run main.mojo benchmark --model tiny --max-tokens 32
```

### Python Pipeline
```bash
# Kaynakları listele
python python/main.py --mode sources

# Tek URL çek
python python/main.py --mode web --url "https://evrimagaci.org/biyoloji"

# Kategoriye göre çek
python python/main.py --mode web --category yazilim --max 5

# Tümünü çek
python python/main.py --mode all --max 2

# İstatistikler
python python/main.py --mode stats
```

### Örnekler
```bash
python examples/scrape_url.py
python examples/scrape_category.py
```

## Model Boyutları

| Model | Parametre | FP32 MB | INT8 MB | INT4 MB |
|-------|-----------|---------|---------|---------|
| tiny | 11M | ~44 | ~11 | ~6 |
| small | 125M | ~500 | ~125 | ~63 |
| medium | 350M | ~1,400 | ~350 | ~175 |
| large | 1B | ~4,000 | ~1,000 | ~500 |

## Teknolojiler

- **Mojo**: 0.26.2+, yüksek performanslı sistem programlama
- **Python**: 3.10+, web scraping ve pipeline
- **Requests + BeautifulSoup**: HTTP ve HTML parsing
- **yt-dlp**: YouTube transcript çıkarma
- **GGUF**: llama.cpp uyumlu model formatı

## Lisans

MIT License
