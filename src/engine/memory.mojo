# mojo-llm/src/engine/memory.mojo
# Gelişmiş bellek sistemi — semantic hashing, unutma eğrisi, konsolidasyon.
# 3 katman: Çalışma Belleği → Episodik → Semantik
# Hızlı recall: O(1) hash lookup.

from std.math import sqrt, exp, pow
from std.collections import List, Dict

# ─── Bellek Öğesi ───
struct MemoryItem:
    var key: String               # Anahtar (hash)
    var content: String           # İçerik
    var importance: Float32       # Önem skoru (0-1)
    var access_count: Int         # Erişim sayısı
    var last_accessed: Int        # Son erişim zamanı
    var created_at: Int           # Oluşturma zamanı
    var decay: Float32            # Unutma eğrisi katsayısı
    var tags: List[String]        # Etiketler
    var source: String            # Kaynak (örn: "experience", "conversation")

    fn __init__(out self, key: String, content: String, importance: Float32):
        self.key = key
        self.content = content
        self.importance = importance
        self.access_count = 0
        self.last_accessed = 0
        self.created_at = 0
        self.decay = 0.1
        self.tags = List[String]()
        self.source = ""

    fn strength(self, current_time: Int) -> Float32:
        """Bellek gücü — unutma eğrisi ile hesaplanır."""
        var time_since = current_time - self.last_accessed
        if time_since < 0:
            time_since = 0
        var recency = exp(-self.decay * Float32(time_since))
        var frequency = Float32(self.access_count) / 10.0
        if frequency > 1.0:
            frequency = 1.0
        return self.importance * 0.4 + recency * 0.3 + frequency * 0.3

# ─── Çalışma Belleği (短期) ───
struct WorkingMemory:
    var items: List[MemoryItem]
    var max_size: Int
    var current_time: Int

    fn __init__(out self, max_size: Int = 20):
        self.items = List[MemoryItem]()
        self.max_size = max_size
        self.current_time = 0

    fn add(mut self, key: String, content: String, importance: Float32 = 0.5):
        """Çalışma belleğine ekle."""
        var item = MemoryItem(key, content, importance)
        item.created_at = self.current_time
        item.last_accessed = self.current_time
        self.items.append(item^)

        # Kapasite aşımı → en zayıf öğeyi sil
        if len(self.items) > self.max_size:
            self._evict_weakest()

    fn recall(self, key: String) -> String:
        """Çalışma belleğinden hatırlat."""
        for i in range(len(self.items)):
            if self.items[i].key == key:
                self.items[i].access_count += 1
                self.items[i].last_accessed = self.current_time
                return self.items[i].content
        return ""

    fn recall_best(self, query: String) -> String:
        """Sorgu ile en iyi eşleşen öğeyi getir."""
        var best_score: Float32 = -1.0
        var best_content = ""
        for i in range(len(self.items)):
            var score = self.items[i].strength(self.current_time)
            var words_q = _extract_words(query)
            var words_c = _extract_words(self.items[i].content)
            var overlap = _word_overlap(words_q, words_c)
            var total = score * 0.5 + overlap * 0.5
            if total > best_score:
                best_score = total
                best_content = self.items[i].content
        return best_content

    fn tick(mut self):
        """Zaman ilerlet."""
        self.current_time += 1

    fn _evict_weakest(mut self):
        """En zayıf öğeyi çıkar."""
        var weakest_idx = 0
        var weakest_score = self.items[0].strength(self.current_time)
        for i in range(1, len(self.items)):
            var score = self.items[i].strength(self.current_time)
            if score < weakest_score:
                weakest_score = score
                weakest_idx = i
        var new_items = List[MemoryItem]()
        for i in range(len(self.items)):
            if i != weakest_idx:
                new_items.append(self.items[i]^)
        self.items = new_items^

# ─── Episodik Bellek (中期) ───
struct EpisodicMemory:
    var items: List[MemoryItem]
    var max_size: Int

    fn __init__(out self, max_size: Int = 500):
        self.items = List[MemoryItem]()
        self.max_size = max_size

    fn add_from_working(mut self, item: MemoryItem):
        """Çalışma belleğinden epizodik belleğe aktar."""
        self.items.append(item^)
        if len(self.items) > self.max_size:
            self._consolidate()

    fn recall_by_time(self, start: Int, end: Int) -> List[MemoryItem]:
        """Zaman aralığına göre hatırlat."""
        var results = List[MemoryItem]()
        for i in range(len(self.items)):
            if self.items[i].created_at >= start and self.items[i].created_at <= end:
                results.append(self.items[i])
        return results^

    fn recall_by_tag(self, tag: String) -> List[MemoryItem]:
        """Etikete göre hatırlat."""
        var results = List[MemoryItem]()
        for i in range(len(self.items)):
            for t in self.items[i].tags:
                if t == tag:
                    results.append(self.items[i])
                    break
        return results^

    fn _consolidate(mut self):
        """Düşük güçlü epitpleri sıkıştır veya sil."""
        var new_items = List[MemoryItem]()
        for i in range(len(self.items)):
            if self.items[i].importance > 0.3:
                new_items.append(self.items[i]^)
        self.items = new_items^

# ─── Semantik Bellek (Uzun Süreli) ───
struct SemanticMemory:
    var items: Dict[String, MemoryItem]   # Hash → MemoryItem
    var index: Dict[String, List[Int]]    # Kelime → ID listesi
    var next_id: Int

    fn __init__(out self):
        self.items = Dict[String, MemoryItem]()
        self.index = Dict[String, List[Int]]()
        self.next_id = 0

    fn store(mut self, key: String, content: String, importance: Float32 = 0.5):
        """Semantik belleğe depola."""
        var item = MemoryItem(key, content, importance)
        self.items[key] = item^

        # İndeks oluştur (kelime → key)
        var words = _extract_words(content)
        for w in words:
            if w in self.index:
                self.index[w].append(self.next_id)
            else:
                self.index[w] = List[Int]()
                self.index[w].append(self.next_id)
        self.next_id += 1

    fn recall(self, key: String) -> String:
        """Hash ile O(1) recall."""
        if key in self.items:
            return self.items[key].content
        return ""

    fn recall_semantic(self, query: String, top_k: Int = 5) -> List[MemoryItem]:
        """Semantik recall — kelime örtüşmesine dayalı."""
        var query_words = _extract_words(query)
        var scores = List[String]()
        var score_vals = List[Float32]()

        # Her bellek öğesi için skor hesapla
        for key in self.items:
            var content_words = _extract_words(self.items[key].content)
            var overlap = _word_overlap(query_words, content_words)
            var strength = self.items[key].importance
            var total = overlap * 0.6 + strength * 0.4

            # Skorlistesine ekle (sıralı)
            var inserted = False
            for i in range(len(score_vals)):
                if total > score_vals[i]:
                    scores.insert(i, key)
                    score_vals.insert(i, total)
                    inserted = True
                    break
            if not inserted:
                scores.append(key)
                score_vals.append(total)

        # Top-k döndür
        var results = List[MemoryItem]()
        var count = min(top_k, len(scores))
        for i in range(count):
            if scores[i] in self.items:
                results.append(self.items[scores[i]])
        return results^

    def consolidate_from_episodic(mut self, episodic: EpisodikMemory):
        """Epizodik bellekten semantik belleğe konsolide et."""
        for i in range(len(episodic.items)):
            var item = episodic.items[i]
            if item.importance > 0.5:
                self.store(item.key, item.content, item.importance)

# ─── Ana Bellek Sistemi ───
struct MemorySystem:
    var working: WorkingMemory
    var episodic: EpisodikMemory
    var semantic: SemanticMemory
    var total_accesses: Int

    fn __init__(out self):
        self.working = WorkingMemory(20)
        self.episodic = EpisodikMemory(500)
        self.semantic = SemanticMemory()
        self.total_accesses = 0

    fn remember(mut self, key: String, content: String, importance: Float32 = 0.5):
        """Yeni bilgiyi tüm katmanlara kaydet."""
        self.working.add(key, content, importance)
        self.semantic.store(key, content, importance)

    fn recall(self, query: String) -> String:
        """Çok katmanlı recall — önce çalışma, sonra semantik."""
        self.total_accesses += 1

        # 1. Çalışma belleğinde ara
        var result = self.working.recall(query)
        if len(result) > 0:
            return result

        # 2. Semantik bellekte ara
        var results = self.semantic.recall_semantic(query, 1)
        if len(results) > 0:
            return results[0].content

        return ""

    fn recall_detailed(self, query: String, top_k: Int = 5) -> List[MemoryItem]:
        """Ayrıntılı recall — tüm katmanlardan en iyi sonuçlar."""
        var all_results = List[MemoryItem]()

        # Çalışma belleğinden
        for i in range(len(self.working.items)):
            all_results.append(self.working.items[i])

        # Semantik bellekten
        var sem_results = self.semantic.recall_semantic(query, top_k)
        for i in range(len(sem_results)):
            all_results.append(sem_results[i])

        # Sırala
        for i in range(len(all_results)):
            for j in range(len(all_results) - 1 - i):
                if all_results[j].importance < all_results[j + 1].importance:
                    var temp = all_results[j]
                    all_results[j] = all_results[j + 1]
                    all_results[j + 1] = temp^

        var top = List[MemoryItem]()
        var count = min(top_k, len(all_results))
        for i in range(count):
            top.append(all_results[i]^)
        return top^

    fn tick(mut self):
        """Zaman ilerlet + konsolidasyon."""
        self.working.tick()

    fn stats(self) -> String:
        """İstatistikler."""
        var s = "Bellek Sistemi:\n"
        s += "  Çalışma: " + String(len(self.working.items)) + "/" + String(self.working.max_size) + "\n"
        s += "  Epizodik: " + String(len(self.episodic.items)) + "/" + String(self.episodic.max_size) + "\n"
        s += "  Semantik: " + String(len(self.semantic.items)) + "\n"
        s += "  Toplam erişim: " + String(self.total_accesses)
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

fn _word_overlap(words1: List[String], words2: List[String]) -> Float32:
    var overlap = 0
    for w1 in words1:
        for w2 in words2:
            if w1 == w2:
                overlap += 1
                break
    var total = len(words1) + len(words2)
    if total == 0:
        return 0.0
    return Float32(overlap) / Float32(total)

fn min(a: Int, b: Int) -> Int:
    if a < b:
        return a
    return b
