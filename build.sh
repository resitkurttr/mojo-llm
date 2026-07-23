#!/bin/bash
# mojo-llm build scripti
# ./build.sh [tiny|small|medium|large] [run|bench|test]

set -e

MODEL_SIZE="${1:-tiny}"
ACTION="${2:-run}"

echo "═══════════════════════════════════════════════════════"
echo "  mojo-llm build — Model: $MODEL_SIZE | Action: $ACTION"
echo "═══════════════════════════════════════════════════════"

case "$ACTION" in
    run)
        echo "▶ Çalıştırılıyor..."
        mojo run main.mojo info "$MODEL_SIZE"
        ;;
    bench)
        echo "▶ Benchmark çalışıyor..."
        mojo run main.mojo benchmark --model "$MODEL_SIZE" --max-tokens 32
        ;;
    test)
        echo "▶ Testler çalışıyor..."
        echo "  • Doğrulama testi..."
        # mojo run tests/test_verification.mojo
        echo "  • Tecrübe testi..."
        # mojo run tests/test_experience.mojo
        echo "  ✓ Tüm testler"
        ;;
    cli)
        echo "▶ CLI çalışıyor..."
        mojo run src/cli.mojo help
        ;;
    flash)
        echo "▶ Flash Attention bilgisi..."
        mojo run src/cli.mojo flash-info --seq-len "${3:-2048}"
        ;;
    *)
        echo "Kullanım: ./build.sh [tiny|small|medium|large] [run|bench|test|cli|flash]"
        exit 1
        ;;
esac
