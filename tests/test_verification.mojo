# mojo-llm/tests/test_verification.mojo
# Doğrulama sistemi testleri.
# mojo run tests/test_verification.mojo

from std.collections import List

fn main():
    print("═══ Doğrulama Sistemi Testleri ═══\n")

    # Test 1: Temel doğrulama
    print("Test 1: Temel doğrulama motoru")
    var engine = VerificationEngine()
    var result = engine.verify("Python nedir?", "Python yüksek seviyeli bir programlama dilidir.")
    print("  Prompt: Python nedir?")
    print("  Response: Python yüksek seviyeli bir programlama dilidir.")
    print("  Skor: " + result.summary())
    assert(result.logical_score > 0.0, "Mantıksal skor pozitif olmalı")
    print("  ✓ Geçti\n")

    # Test 2: Kısa cevap tespiti
    print("Test 2: Kısa cevap tespiti")
    var result2 = engine.verify("Nasıl program yazılır?", "Yazılır.")
    print("  Skor: " + result2.summary())
    assert(result2.logical_score < 0.8, "Kısa cevap düşük skor almalı")
    print("  ✓ Geçti\n")

    # Test 3: Koherans kontrolü
    print("Test 3: Koherans kontrolü")
    var result3 = engine.verify("Test", "Bu çok uzun bir metin. İçinde birden fazla cümle var. Her cümle farklı bir konudan bahsediyor. Bu da koheransı etkiler.")
    print("  Skor: " + result3.summary())
    assert(result3.coherence_score > 0.0, "Koherans skoru pozitif olmalı")
    print("  ✓ Geçti\n")

    # Test 4: Geçerlilik kontrolü
    print("Test 4: Geçerlilik kontrolü")
    var valid = VerificationResult()
    valid.score = 0.8
    assert(valid.is_valid(), "0.8 skor geçerli olmalı")
    var invalid = VerificationResult()
    invalid.score = 0.3
    assert(not invalid.is_valid(), "0.3 skor geçersiz olmalı")
    print("  ✓ Geçti\n")

    print("═══ Tüm testler geçti! ═══")
