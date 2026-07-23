# mojo-llm v0.4.0

**Kendi kendine öğrenen, agentic Mojo LLM sistemi.**

Mojo dilinde yazılmış, tek dosya iskelet üzerine modüler genişletilmiş LLM sistemi. Temel özellik: **doğrulama tabanlı öğrenme** — model kendi çıktılarını kontrol ederek, tecrübelerini sıkıştırarak ve hiyerarşik bellek ile hatırlayarak gelişir.

## Mimari

```
mojo-llm/
├── main.mojo                    # Orijinal tek dosya iskelet (905 satır)
├── src/
│   ├── core/
│   │   └── flash_attention.mojo # Flash Attention V2 (bellek-verimli)
│   ├── engine/
│   │   ├── verification.mojo    # Doğrulama sistemi
│   │   ├── experience.mojo      # Tecrübe kütüphanesi + sıkıştırma
│   │   ├── memory.mojo          # 3 katmanlı bellek sistemi
│   │   ├── self_learning.mojo   # Kendi kendine öğrenme döngüsü
│   │   ├── agent.mojo           # Agentic orchestration
│   │   ├── tool_use.mojo        # Tool registry + execution
│   │   ├── multi_agent.mojo     # Orchestrator/Worker pattern
│   │   ├── web_browser.mojo     # Web erişimi
│   │   ├── api_server.mojo      # OpenAI-uyumlu API
│   │   ├── save_load.mojo       # Model kaydetme/yükleme
│   │   └── gguf.mojo            # GGUF format desteği
│   ├── cli.mojo                 # CLI arayüzü
│   └── config.mojo              # Konfigürasyon
├── tests/                       # Test dosyaları
├── configs/                     # Konfigürasyon dosyaları
└── examples/                    # Kullanım örnekleri
```

## Temel Özellikler

### 1. Doğrulama Tabanlı Öğrenme
Model her çıktısını kontrol eder:
- **Mantıksal tutarlılık**: Cevap mantıklı mı?
- **Koherans**: Metin akıcı mı?
- **Gerçeklik**: Bilgiler doğru mu?
- **Eksiksizlik**: Soru tam cevaplanmış mı?

### 2. Tecrübe Kütüphanesi
Hiyerarşik sıkıştırma sistemi:
```
Ham Tecrübe → Özet → Pattern → Meta-Pattern
     ↓           ↓        ↓          ↓
  [Detay]    [Kısa]   [Genel]   [Meta]
```
- Semantic hash ile O(1) recall
- Unutma eğrisi ile doğal temizleme
- Otomatik sıkıştırma

### 3. 3 Katmanlı Bellek
```
Çalışma Belleği (短期) → Episodik (中期) → Semantik (Uzun Süreli)
     ↓                       ↓                    ↓
  [20 öğe]             [500 öğe]          [Sınırsız]
```

### 4. Flash Attention V2
- Bellek karmaşıklığı: O(N²) → O(N)
- Tile-based computation
- Online softmax
- Mobil cihazlar için optimize

### 5. Tool Use
12 varsayılan tool: read_file, write_file, grep, web_search, web_fetch, run_code, run_shell, json_parse, csv_read, list_files, search_files

### 6. Multi-Agent
Orchestrator/Worker pattern ile görev dağıtımı.

## Kurulum

### Mojo Kurulumu
```bash
# macOS / Linux
curl -fsSL https://get.modular.com | MODULAR_HOME=$HOME/.modular bash -
source ~/.bashrc  # veya ~/.zshrc

# Mojo sürümü
mojo --version  # >= 0.26.2 olmalı
```

### Repo Kurulumu
```bash
git clone https://github.com/resitkurttr/mojo-llm.git
cd mojo-llm
```

## Kullanım

### Model Bilgisi
```bash
mojo run main.mojo info tiny
mojo run main.mojo info small
mojo run main.mojo info medium
mojo run main.mojo info large
```

### Tahmin
```bash
mojo run main.mojo infer --model tiny --prompt "Merhaba"
mojo run main.mojo infer --model small --prompt "Python nedir?" --max-tokens 128
```

### Benchmark
```bash
mojo run main.mojo benchmark --model tiny --max-tokens 32
```

### Yeni CLI (v0.4.0)
```bash
# Doğrulama
mojo run src/cli.mojo verify --prompt "Python nedir?" --response "Python bir programlama dilidir."

# Tecrübe ekleme
mojo run src/cli.mojo learn --input "Python nedir?" --output "Python bir programlama dilidir." --score 0.9

# Bellek
mojo run src/cli.mojo remember --key "python" --content "Python yüksek seviyeli programlama dili"

# Flash Attention bilgisi
mojo run src/cli.mojo flash-info --seq-len 2048
```

## Modüller

| Modül | Dosya | Açıklama |
|-------|-------|----------|
| Tensor | `main.mojo` | Vector, Matrix, referans sayacı |
| Transformer | `main.mojo` | Decoder-only, GQA, RoPE, SwiGLU |
| BPE Tokenizer | `main.mojo` | Byte-Pair Encoding |
| Inference | `main.mojo` | Token sampling, temperature, top-k/p |
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

## Model Boyutları

| Model | Parametre | FP32 MB | INT8 MB | INT4 MB |
|-------|-----------|---------|---------|---------|
| tiny | 11M | ~44 | ~11 | ~6 |
| small | 125M | ~500 | ~125 | ~63 |
| medium | 350M | ~1,400 | ~350 | ~175 |
| large | 1B | ~4,000 | ~1,000 | ~500 |

## Teknolojiler

- **Dil**: Mojo 0.26.2+
- **Bellek**: UnsafePointer ile manuel yönetim, referans sayacı
- **Sıkıştırma**: FP32, FP16, INT8, INT4, NF4 quantization
- **Format**: GGUF (llama.cpp uyumlu)
- **API**: OpenAI-uyumlu REST API

## Lisans

MIT License
