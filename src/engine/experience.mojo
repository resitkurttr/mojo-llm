# mojo-llm/src/engine/experience.mojo
# Tecrübe kütüphanesi — hiyerarşik sıkıştırma sistemi.
# Ham tecrübe → Özet → Pattern → Meta-pattern
# Hızlı recall için semantic hash kullanır.

from std.math import sqrt, exp
from std.collections import List, Dict

# ─── Sıkıştırma Seviyesi ───
enum CompressionLevel:
    RAW          # Ham tecrübe (orijinal metin)
    SUMMARY      # Özet (1-2 cümle)
    PATTERN      # Genelleştirilmiş pattern
    META_PATTERN # Meta-seviye pattern (diğer patternlardan öğrenilen)

# ─── Ham Tecrübe ───
struct ExperienceItem:
    var id: Int
    var input_text: String
    var output_text: String
    var score: Float32
    var timestamp: Int            # Basit zaman damgası
    var context: String           # Bağlam
    var tags: List[String]        # Etiketler
    var access_count: Int         # Erişim sayısı
    var last_accessed: Int        # Son erişim zamanı

    fn __init__(out self, id: Int, input_text: String, output_text: String, score: Float32):
        self.id = id
        self.input_text = input_text
        self.output_text = output_text
        self.score = score
        self.timestamp = 0
        self.context = ""
        self.tags = List[String]()
        self.access_count = 0
        self.last_accessed = 0

    fn relevance(self, query: String) -> Float32:
        """Sorgu ile ne kadar ilgili (0-1)."""
        var words_q = _extract_words(query)
        var words_i = _extract_words(self.input_text)
        var words_o = _extract_words(self.output_text)

        var overlap = 0
        for wq in words_q:
            for wi in words_i:
                if wq == wi:
                    overlap += 1
                    break
            for wo in words_o:
                if wq == wo:
                    overlap += 1
                    break

        var total = len(words_q)
        if total == 0:
            return 0.0
        return min(1.0, Float32(overlap) / Float32(total))

# ─── Sıkıştırılmış Tecrübe ───
struct CompressedExperience:
    var id: Int
    var level: CompressionLevel
    var summary: String
    var source_ids: List[Int]     # Hangi ham tecrübelerden türetildi
    var score: Float32
    var usage_count: Int

    fn __init__(out self, id: Int, level: CompressionLevel, summary: String):
        self.id = id
        self.level = level
        self.summary = summary
        self.source_ids = List[Int]()
        self.score = 0.0
        self.usage_count = 0

# ─── Pattern ───
struct Pattern:
    var id: Int
    var description: String       # Pattern açıklaması
    var input_template: String    # Girdi şablonu
    var output_template: String   # Çıktı şablonu
    var confidence: Float32       # Güven skoru
    var example_count: Int        # Kaç örnekle destekleniyor
    var tags: List[String]

    fn __init__(out self, id: Int, description: String):
        self.id = id
        self.description = description
        self.input_template = ""
        self.output_template = ""
        self.confidence = 0.5
        self.example_count = 0
        self.tags = List[String]()

# ─── Tecrübe Kütüphanesi ───
struct ExperienceLibrary:
    var raw_items: List[ExperienceItem]
    var compressed: List[CompressedExperience]
    var patterns: List[Pattern]
    var next_id: Int
    var max_raw: Int              # Maksimum ham tecrübe
    var max_compressed: Int       # Maksimum sıkıştırılmış
    var compression_threshold: Float32  # Sıkıştırma eşiği

    fn __init__(out self):
        self.raw_items = List[ExperienceItem]()
        self.compressed = List[CompressedExperience]()
        self.patterns = List[Pattern]()
        self.next_id = 1
        self.max_raw = 10000
        self.max_compressed = 5000
        self.compression_threshold = 0.7

    fn add_experience(mut self, input_text: String, output_text: String, score: Float32) -> Int:
        """Yeni tecrübe ekle. ID döndür."""
        var item = ExperienceItem(self.next_id, input_text, output_text, score)
        item.timestamp = self.next_id  # Basit timestamp
        self.raw_items.append(item^)
        var id = self.next_id
        self.next_id += 1

        # Otomatik sıkıştırma
        if len(self.raw_items) > self.max_raw:
            self._compress_old()

        return id

    fn recall(self, query: String, top_k: Int = 5) -> List[ExperienceItem]:
        """Sorguyla en ilgili tecrübeleri bul (hızlı recall)."""
        var results = List[ExperienceItem]()

        # Ham tecrübelerde ara
        for i in range(len(self.raw_items)):
            var rel = self.raw_items[i].relevance(query)
            if rel > 0.1:
                results.append(self.raw_items[i])
                self.raw_items[i].access_count += 1

        # Sırala (basit bubble sort — küçük listeler için yeterli)
        for i in range(len(results)):
            for j in range(len(results) - 1 - i):
                if results[j].relevance(query) < results[j + 1].relevance(query):
                    var temp = results[j]
                    results[j] = results[j + 1]
                    results[j + 1] = temp^

        # Top-k döndür
        var top = List[ExperienceItem]()
        var count = min(top_k, len(results))
        for i in range(count):
            top.append(results[i]^)
        return top^

    fn recall_compressed(self, query: String, top_k: Int = 3) -> List[CompressedExperience]:
        """Sıkıştırılmış tecrübelerde hızlı recall."""
        var results = List[CompressedExperience]()

        for i in range(len(self.compressed)):
            var words_q = _extract_words(query)
            var words_s = _extract_words(self.compressed[i].summary)
            var overlap = 0
            for wq in words_q:
                for ws in words_s:
                    if wq == ws:
                        overlap += 1
                        break
            if overlap > 0:
                results.append(self.compressed[i])

        var top = List[CompressedExperience]()
        var count = min(top_k, len(results))
        for i in range(count):
            top.append(results[i]^)
        return top^

    fn get_patterns(self, tag: String) -> List[Pattern]:
        """Etikete göre pattern getir."""
        var results = List[Pattern]()
        for i in range(len(self.patterns)):
            for t in self.patterns[i].tags:
                if t == tag:
                    results.append(self.patterns[i])
                    break
        return results^

    fn _compress_old(mut self):
        """Eski tecrübeleri sıkıştır."""
        # En düşük skorlu ve en az erişilen %20'yi sıkıştır
        var threshold = len(self.raw_items) * 80 / 100
        var to_compress = List[ExperienceItem]()

        # Skorlara göre sırala
        for i in range(len(self.raw_items)):
            for j in range(len(self.raw_items) - 1 - i):
                if self.raw_items[j].score > self.raw_items[j + 1].score:
                    var temp = self.raw_items[j]
                    self.raw_items[j] = self.raw_items[j + 1]
                    self.raw_items[j + 1] = temp^

        # En alttakileri sıkıştır
        var compressed_count = 0
        var i = 0
        while i < len(self.raw_items) and compressed_count < 10:
            if self.raw_items[i].score < self.compression_threshold:
                var summary = self._summarize(self.raw_items[i])
                var comp = CompressedExperience(
                    self.next_id,
                    CompressionLevel.SUMMARY,
                    summary
                )
                comp.source_ids.append(self.raw_items[i].id)
                comp.score = self.raw_items[i].score
                self.compressed.append(comp^)
                self.next_id += 1
                compressed_count += 1
                # Raw'dan kaldır
                var new_raw = List[ExperienceItem]()
                for j in range(len(self.raw_items)):
                    if j != i:
                        new_raw.append(self.raw_items[j]^)
                self.raw_items = new_raw^
            else:
                i += 1

    fn _summarize(self, item: ExperienceItem) -> String:
        """Tecrübeyi özetle (basit extractive)."""
        var sentences = _split_sentences(item.output_text)
        if len(sentences) == 0:
            return item.output_text
        if len(sentences) == 1:
            return sentences[0]

        # İlk ve son cümleyi al
        var summary = sentences[0]
        if len(sentences) > 1:
            summary += " " + sentences[len(sentences) - 1]
        return summary

    fn stats(self) -> String:
        """İstatistikleri döndür."""
        var s = "Tecrübe Kütüphanesi:\n"
        s += "  Ham: " + String(len(self.raw_items)) + "\n"
        s += "  Sıkıştırılmış: " + String(len(self.compressed)) + "\n"
        s += "  Pattern: " + String(len(self.patterns)) + "\n"
        s += "  Toplam ID: " + String(self.next_id)
        return s

# ─── Yardımcı Fonksiyonlar ───
fn _extract_words(text: String) -> List[String]:
    var words = List[String]()
    var current = ""
    for i in range(len(text)):
        var c = text.unsafe_ptr()[i]
        if c == 32 or c == 10 or c == 46 or c == 44 or c == 63 or c == 33:
            if len(current) > 2:
                words.append(current)
            current = ""
        else:
            current += String(c)
    if len(current) > 2:
        words.append(current)
    return words^

fn _split_sentences(text: String) -> List[String]:
    var sentences = List[String]()
    var current = ""
    for i in range(len(text)):
        var c = text.unsafe_ptr()[i]
        current += String(c)
        if c == 46 or c == 33 or c == 63:
            if len(current) > 5:
                sentences.append(current)
            current = ""
    if len(current) > 5:
        sentences.append(current)
    return sentences^
