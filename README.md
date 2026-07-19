# mojo-llm

Yerel makinede **Mojo 0.26** ile derlenen, tek dosyalık (`main.mojo`) minimal bir LLM çıkarım motoru.

- Transformer (RoPE + causal self-attention + SwiGLU FFN)
- BPE tokenizer (byte-level, char-based)
- fp32 çıkarım + int8 destekli parametre sayacı
- CLI: `info`, `infer`, `quantize`, `benchmark`

## Gereksinimler

- Mojo 0.26.x (`max` toolchain)
- Linux (math kütüphanesi `-lm` ile link edilir)

## Kurulum

```bash
export PATH="/home/pardus/.local/share/uv/tools/max/bin:$PATH"
```

## Derleme

> Not: `sincosf` gibi math sembolleri için `-Xlinker -lm` bayrağı gereklidir.

```bash
mojo build -Xlinker -lm main.mojo -o mojo_llm_bin
```

Veya hazır script ile:

```bash
./build.sh
```

## Kullanım

```bash
# Model bilgisi
./mojo_llm_bin info tiny

# Çıkarım
./mojo_llm_bin infer --model tiny --prompt "Merhaba dunya" --max-tokens 32

# int8 parametre hesabı
./mojo_llm_bin quantize --model tiny --quant int8

# Performans testi (ardışık generate)
./mojo_llm_bin benchmark --model tiny --prompt "Test" --max-tokens 16
```

## Desteklenen modeller

| Model    | d_model | katman | head | d_ff  | parametre |
|----------|---------|--------|------|-------|-----------|
| `tiny`   | 256     | 4      | 4    | 1024  | ~19.7M    |
| `small`  | 768     | 12     | 12   | 3072  | ~85M      |
| `medium` | 1024    | 24     | 16   | 4096  | ~300M     |
| `large`  | 2048    | 24     | 32   | 8192  | ~1.2B     |

## Teknik Notlar

- `Matrix` / `Vector` yapıları `UnsafePointer[Float32]` üzerine kurulu, referans sayımı (refcount) ile `Copyable` yapıldı. Paylaşılan buffer için tek `alloc` bloğunda `refs` (Int) + `data` (Float32) tutulur.
- Tüm matris işlemleri (`@`, `+`, `*`, `T`) saf Mojo döngüleriyle yazıldı.
- `Matrix` `Copyable` fakat `ImplicitlyCopyable` değil → taşıma (`^`) veya `.copy()` açıkça kullanılır.

## Lisans

MIT — see [LICENSE](LICENSE).
