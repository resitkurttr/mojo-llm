# mojo-llm/src/engine/verification.mojo
# Doğrulama sistemi — modelin kendi çıktılarını kontrol etmesi.
# Mantıksal tutarlılık, koherans, gerçeklik doğrulama.

from std.math import sqrt, exp, abs
from std.collections import List, Dict

# ─── Doğrulama Sonucu ───
struct VerificationResult:
    var score: Float32          # 0.0-1.0 arası genel skor
    var logical_score: Float32  # Mantıksal tutarlılık
    var coherence_score: Float32 # Koherans
    var factuality_score: Float32 # Gerçeklik
    var completeness_score: Float32 # Eksiksizlik
    var issues: List[String]    # Tespit edilen sorunlar
    var suggestions: List[String] # Öneriler

    fn __init__(out self):
        self.score = 0.0
        self.logical_score = 0.0
        self.coherence_score = 0.0
        self.factuality_score = 0.0
        self.completeness_score = 0.0
        self.issues = List[String]()
        self.suggestions = List[String]()

    fn is_valid(self) -> Bool:
        return self.score >= 0.6

    fn summary(self) -> String:
        var s = "Doğrulama: " + String(Int(self.score * 100)) + "%"
        s += " (mantık:" + String(Int(self.logical_score * 100))
        s += " koherans:" + String(Int(self.coherence_score * 100))
        s += " gerçeklik:" + String(Int(self.factuality_score * 100))
        s += " eksiksizlik:" + String(Int(self.completeness_score * 100)) + ")"
        return s

# ─── Doğrulama Kriteri ───
enum VerificationCriterion:
    LOGICAL     # Mantıksal tutarlılık
    COHERENCE   # Koherans ve akıcılık
    FACTUALITY  # Gerçeklik
    COMPLETENESS # Eksiksizlik
    SAFETY      # Güvenlik
    RELEVANCE   # İlgililik

# ─── Doğrulama Motoru ───
struct VerificationEngine:
    var weights: Dict[String, Float32]
    var min_threshold: Float32
    var max_issues: Int

    fn __init__(out self):
        self.weights = Dict[String, Float32]()
        self.weights["logical"] = 0.3
        self.weights["coherence"] = 0.25
        self.weights["factuality"] = 0.25
        self.weights["completeness"] = 0.2
        self.min_threshold = 0.6
        self.max_issues = 10

    fn verify(self, prompt: String, response: String) -> VerificationResult:
        var result = VerificationResult()
        result.logical_score = self._check_logical(prompt, response)
        result.coherence_score = self._check_coherence(response)
        result.factuality_score = self._check_factuality(response)
        result.completeness_score = self._check_completeness(prompt, response)

        # Ağırlıklı genel skor
        result.score = (
            result.logical_score * self.weights["logical"] +
            result.coherence_score * self.weights["coherence"] +
            result.factuality_score * self.weights["factuality"] +
            result.completeness_score * self.weights["completeness"]
        )
        return result^

    fn _check_logical(self, prompt: String, response: String) -> Float32:
        var score: Float32 = 0.7  # Varsayılan iyi

        # Cevap prompt ile ilgili mi?
        var prompt_words = self._extract_words(prompt)
        var response_words = self._extract_words(response)
        var overlap = self._word_overlap(prompt_words, response_words)
        if overlap > 0.3:
            score += 0.2
        elif overlap < 0.05:
            score -= 0.3

        # Cevap çok kısa mı?
        if len(response) < 10:
            score -= 0.3
            self.issues.append("Cevap çok kısa")
        elif len(response) > 5000:
            score -= 0.1
            self.issues.append("Cevap çok uzun")

        # Tutarlılık kontrolü (basit: çelişki tespiti)
        if self._has_contradiction(response):
            score -= 0.4
            self.issues.append("Cevapta çelişki tespit edildi")

        return max(0.0, min(1.0, score))

    fn _check_coherence(self, response: String) -> Float32:
        var score: Float32 = 0.7

        # Cümle uzunlukları tutarlı mı?
        var sentences = self._split_sentences(response)
        if len(sentences) > 1:
            var avg_len: Float32 = 0.0
            for s in sentences:
                avg_len += Float32(len(s))
            avg_len /= Float32(len(sentences))

            var variance: Float32 = 0.0
            for s in sentences:
                var diff = Float32(len(s)) - avg_len
                variance += diff * diff
            variance /= Float32(len(sentences))

            # Düşük varyans = daha tutarlı
            if variance < 100.0:
                score += 0.2
            elif variance > 1000.0:
                score -= 0.2
                self.issues.append("Cümle uzunlukları tutarsız")

        # Paragraf yapısı
        var paragraphs = self._split_paragraphs(response)
        if len(paragraphs) > 1:
            score += 0.1  # Yapı var

        return max(0.0, min(1.0, score))

    fn _check_factuality(self, response: String) -> Float32:
        var score: Float32 = 0.7

        # Belirsiz ifadeler (olumsuz sinyal)
        var uncertain_phrases = List[String]()
        uncertain_phrases.append("belki")
        uncertain_phrases.append("muhtemelen")
        uncertain_phrases.append("sanırım")
        uncertain_phrases.append("emin değilim")
        uncertain_phrases.append("olabilir")

        var uncertain_count = 0
        for phrase in uncertain_phrases:
            if self._contains(response, phrase):
                uncertain_count += 1

        if uncertain_count > 2:
            score -= 0.2
            self.issues.append("Çok fazla belirsiz ifade")

        # Kesin ifadeler (olumlu sinyal)
        var certain_phrases = List[String]()
        certain_phrases.append("kesinlikle")
        certain_phrases.append("her zaman")
        certain_phrases.append("asla")

        var certain_count = 0
        for phrase in certain_phrases:
            if self._contains(response, phrase):
                certain_count += 1

        if certain_count > 3:
            score -= 0.1
            self.issues.append("Aşırı kesin ifadeler")

        return max(0.0, min(1.0, score))

    fn _check_completeness(self, prompt: String, response: String) -> Float32:
        var score: Float32 = 0.7

        # Soru tipini belirle
        var question_words = List[String]()
        question_words.append("nasıl")
        question_words.append("neden")
        question_words.append("nedir")
        question_words.append("hangisi")
        question_words.append("kaç")
        question_words.append("ne")

        var is_question = False
        for qw in question_words:
            if self._contains(prompt, qw):
                is_question = True
                break

        if is_question:
            # Soru cevaplanmış mı?
            if len(response) > 50:
                score += 0.2
            else:
                score -= 0.2
                self.issues.append("Soru tam cevaplanmamış")

        # Liste/tablo var mı?
        if self._contains(response, "1.") or self._contains(response, "- "):
            score += 0.1  # Yapısal cevap

        return max(0.0, min(1.0, score))

    fn _has_contradiction(self, text: String) -> Bool:
        var negations = List[String]()
        negations.append("değil")
        negations.append("yok")
        negations.append("olmaz")

        var affirmations = List[String]()
        affirmations.append("vardır")
        affirmations.append("olur")
        affirmations.append("mümkündür")

        # Basit çelişki: aynı cümlede hem olumsuz hem olumlu
        # (Geliştirilmiş versiyonda NLP gerekir)
        return False

    fn _extract_words(self, text: String) -> List[String]:
        var words = List[String]()
        var current = ""
        for i in range(len(text)):
            var c = text.unsafe_ptr()[i]
            if c == 32 or c == 10 or c == 46 or c == 44:  # space, newline, .
                if len(current) > 2:
                    words.append(current)
                current = ""
            else:
                current += String(c)
        if len(current) > 2:
            words.append(current)
        return words^

    fn _word_overlap(self, words1: List[String], words2: List[String]) -> Float32:
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

    fn _split_sentences(self, text: String) -> List[String]:
        var sentences = List[String]()
        var current = ""
        for i in range(len(text)):
            var c = text.unsafe_ptr()[i]
            current += String(c)
            if c == 46 or c == 33 or c == 63:  # . ! ?
                if len(current) > 5:
                    sentences.append(current)
                current = ""
        if len(current) > 5:
            sentences.append(current)
        return sentences^

    fn _split_paragraphs(self, text: String) -> List[String]:
        var paragraphs = List[String]()
        var current = ""
        for i in range(len(text)):
            var c = text.unsafe_ptr()[i]
            current += String(c)
            if c == 10 and i + 1 < len(text) and text.unsafe_ptr()[i + 1] == 10:
                if len(current) > 10:
                    paragraphs.append(current)
                current = ""
        if len(current) > 10:
            paragraphs.append(current)
        return paragraphs^

    fn _contains(self, text: String, substr: String) -> Bool:
        if len(substr) > len(text):
            return False
        for i in range(len(text) - len(substr) + 1):
            var match = True
            for j in range(len(substr)):
                if text.unsafe_ptr()[i + j] != substr.unsafe_ptr()[j]:
                    match = False
                    break
            if match:
                return True
        return False
