# mojo-llm/src/engine/self_learning.mojo
# Kendi kendine öğrenme sistemi.
# Üret → Doğrula → Depola → Geliştir
# Doğrulama tabanlı öğrenme döngüsü.

from std.math import sqrt, exp
from std.collections import List, Dict

# ─── Öğrenme Kaydı ───
struct LearningRecord:
    var input_text: String
    var output_text: String
    var verification_score: Float32
    var improvement_delta: Float32  # Ne kadar gelişti
    var iteration: Int
    var tags: List[String]

    fn __init__(out self, input_text: String, output_text: String, score: Float32, iteration: Int):
        self.input_text = input_text
        self.output_text = output_text
        self.verification_score = score
        self.improvement_delta = 0.0
        self.iteration = iteration
        self.tags = List[String]()

# ─── Öğrenme İstatistikleri ───
struct LearningStats:
    var total_iterations: Int
    var total_improvements: Int
    var avg_score: Float32
    var best_score: Float32
    var worst_score: Float32
    var score_history: List[Float32]

    fn __init__(out self):
        self.total_iterations = 0
        self.total_improvements = 0
        self.avg_score = 0.0
        self.best_score = 0.0
        self.worst_score = 1.0
        self.score_history = List[Float32]()

    fn update(mut self, score: Float32):
        """Yeni skor ile istatistikleri güncelle."""
        self.total_iterations += 1
        self.score_history.append(score)

        # Ortalama
        var sum: Float32 = 0.0
        for s in self.score_history:
            sum += s
        self.avg_score = sum / Float32(len(self.score_history))

        if score > self.best_score:
            self.best_score = score
        if score < self.worst_score:
            self.worst_score = score

    fn improvement_rate(self) -> Float32:
        """İyileşme oranı (son 10 iterasyon)."""
        if len(self.score_history) < 10:
            return 0.0
        var recent = 0
        var older = 0
        var recent_sum: Float32 = 0.0
        var older_sum: Float32 = 0.0

        for i in range(len(self.score_history)):
            if i >= len(self.score_history) - 5:
                recent_sum += self.score_history[i]
                recent += 1
            elif i >= len(self.score_history) - 10:
                older_sum += self.score_history[i]
                older += 1

        if recent == 0 or older == 0:
            return 0.0
        var recent_avg = recent_sum / Float32(recent)
        var older_avg = older_sum / Float32(older)
        return recent_avg - older_avg

# ─── Öğrenme Stratejisi ───
enum LearningStrategy:
    GRADUAL       # Kademeli gelişim
    AGGRESSIVE    # Hızlı öğrenme
    CONSERVATIVE  # Temkinli öğrenme
    EXPLORATION   # Keşif odaklı

# ─── Self-Learner ───
struct SelfLearner:
    var records: List[LearningRecord]
    var stats: LearningStats
    var strategy: LearningStrategy
    var current_iteration: Int
    var max_records: Int
    var learning_rate: Float32
    var momentum: Float32
    var best_output: String
    var best_score: Float32

    fn __init__(out self):
        self.records = List[LearningRecord]()
        self.stats = LearningStats()
        self.strategy = LearningStrategy.GRADUAL
        self.current_iteration = 0
        self.max_records = 1000
        self.learning_rate = 0.01
        self.momentum = 0.9
        self.best_output = ""
        self.best_score = 0.0

    fn learn_from_interaction(mut self, input_text: String, output_text: String, verification_score: Float32) -> Float32:
        """Tek bir etkileşimden öğren. İyileşme miktarını döndür."""
        self.current_iteration += 1
        var delta: Float32 = 0.0

        # Önceki en iyi ile karşılaştır
        if verification_score > self.best_score:
            delta = verification_score - self.best_score
            self.best_score = verification_score
            self.best_output = output_text

        # Kayıt oluştur
        var record = LearningRecord(input_text, output_text, verification_score, self.current_iteration)
        record.improvement_delta = delta
        self.records.append(record^)

        # İstatistikleri güncelle
        self.stats.update(verification_score)

        # Eski kayıtları temizle
        if len(self.records) > self.max_records:
            self._cleanup_old_records()

        return delta

    fn suggest_improvement(self, input_text: String, current_output: String, score: Float32) -> String:
        """Mevcut çıktıyı iyileştirmek için öneride bulun."""
        if score >= 0.9:
            return "Mevcut çıktı çok iyi, küçük ayarlamalar yap"

        if score >= 0.7:
            return "İyi bir çıktı, koheransı artır"

        if score >= 0.5:
            return "Orta seviye, daha fazla detay ekle"

        # Düşük skor — tamamen yeniden yaz
        return "Çıktı yetersiz, farklı bir yaklaşım dene"

    fn get_strategy_adjustments(self) -> String:
        """Mevcut stratejiye göre ayarlamaları döndür."""
        var rate = self.stats.improvement_rate()

        if self.strategy == LearningStrategy.GRADUAL:
            if rate > 0.05:
                return "Hızlı gelişim gösteriliyor, agresif stratejiye geç"
            elif rate < -0.02:
                return "Geriye gidiyor, temkinli stratejiye geç"
            else:
                return "İstikrarlı gelişim, devam et"

        elif self.strategy == LearningStrategy.AGGRESSIVE:
            if rate < -0.05:
                return "Aşırı öğrenme riski, yavaşla"
            else:
                return "Agresif öğrenme devam ediyor"

        elif self.strategy == LearningStrategy.CONSERVATIVE:
            if rate > 0.1:
                return "Hızlı gelişim, daha agresif olabilirsin"
            else:
                return "Temkinli öğrenme devam ediyor"

        else:  # EXPLORATION
            return "Keşif modunda — farklı yaklaşımlar dene"

    fn should_stop_learning(self) -> Bool:
        """Öğrenmeyi durdurmalı mıyız?"""
        if self.current_iteration > 1000:
            return True
        if self.stats.improvement_rate() < -0.1:
            return True  # Geriye gidiyor
        return False

    fn best_result(self) -> String:
        """En iyi sonucu döndür."""
        return self.best_output

    fn stats_summary(self) -> String:
        """İstatistik özeti."""
        var s = "Öğrenme İstatistikleri:\n"
        s += "  İterasyon: " + String(self.current_iteration) + "\n"
        s += "  Ortalama skor: " + String(Int(self.stats.avg_score * 100)) + "%\n"
        s += "  En iyi: " + String(Int(self.stats.best_score * 100)) + "%\n"
        s += "  En kötü: " + String(Int(self.stats.worst_score * 100)) + "%\n"
        s += "  İyileşme oranı: " + String(Int(self.stats.improvement_rate() * 100)) + "%\n"
        s += "  Strateji: " + _strategy_name(self.strategy)
        return s

    fn _cleanup_old_records(mut self):
        """Eski kayıtları temizle — en iyi %50'yi koru."""
        if len(self.records) <= self.max_records // 2:
            return

        # Skora göre sırala
        for i in range(len(self.records)):
            for j in range(len(self.records) - 1 - i):
                if self.records[j].verification_score < self.records[j + 1].verification_score:
                    var temp = self.records[j]
                    self.records[j] = self.records[j + 1]
                    self.records[j + 1] = temp^

        # En iyi yarısını koru
        var keep = self.max_records // 2
        var new_records = List[LearningRecord]()
        for i in range(keep):
            new_records.append(self.records[i]^)
        self.records = new_records^

fn _strategy_name(s: LearningStrategy) -> String:
    if s == LearningStrategy.GRADUAL:
        return "Kademeli"
    elif s == LearningStrategy.AGGRESSIVE:
        return "Agresif"
    elif s == LearningStrategy.CONSERVATIVE:
        return "Temkinli"
    else:
        return "Keşif"
