# mojo-llm/tests/test_experience.mojo
# Tecrübe kütüphanesi testleri.

from std.collections import List

fn main():
    print("═══ Tecrübe Kütüphanesi Testleri ═══\n")

    # Test 1: Tecrübe ekleme
    print("Test 1: Tecrübe ekleme")
    var lib = ExperienceLibrary()
    var id1 = lib.add_experience("Python nedir?", "Python bir programlama dilidir.", 0.9)
    var id2 = lib.add_experience("Mojo nedir?", "Mojoysız yüksek performanslı programlama dilidir.", 0.8)
    assert(id1 == 1, "İlk ID 1 olmalı")
    assert(id2 == 2, "İkinci ID 2 olmalı")
    print("  ✓ İki tecrübe eklendi\n")

    # Test 2: Recall
    print("Test 2: Tecrübe hatırlama")
    var results = lib.recall("Python programlama", 5)
    assert(len(results) > 0, "Sonuç bulunmalı")
    print("  ✓ " + String(len(results)) + " sonuç bulundu\n")

    # Test 3: Stats
    print("Test 3: İstatistikler")
    var stats = lib.stats()
    print("  " + stats)
    print("  ✓ İstatistikler yazdırıldı\n")

    # Test 4: Sıkıştırılmış recall
    print("Test 4: Sıkıştırılmış recall")
    var comp_results = lib.recall_compressed("Python", 3)
    print("  Sıkıştırılmış sonuç: " + String(len(comp_results)))
    print("  ✓ Geçti\n")

    print("═══ Tüm testler geçti! ═══")
