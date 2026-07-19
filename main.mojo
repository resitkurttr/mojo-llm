# mojo-llm — Tek dosya (Mojo 0.26.2 uyumlu, UnsafePointer backing)
# Tensor + Transformer + BPE + Inference + CLI

from std.math import sqrt, exp, cos, sin, pow
from std.collections import List, Dict
from std.sys import argv
from std.memory import UnsafePointer, alloc

# ════════════════════════════════════════════════════════════════
# Tensor
# ════════════════════════════════════════════════════════════════
struct Vector(Copyable):
    var data: UnsafePointer[Float32, MutAnyOrigin]
    var _size: Int
    var refs: UnsafePointer[Int, MutAnyOrigin]
    fn __init__(out self, size: Int):
        self._size = size
        var p = alloc[Float32](size + 2)
        self.refs = p.bitcast[Int]()
        self.data = (p.bitcast[Int]() + 1).bitcast[Float32]()
        self.refs[0] = 1
        for i in range(size):
            self.data[i] = 0.0
    fn __copyinit__(out self, copy: Self):
        self._size = copy._size
        self.data = copy.data
        self.refs = copy.refs
        self.refs[0] += 1
    fn __moveinit__(mut self, other: Self):
        self._size = other._size
        self.data = other.data
        self.refs = other.refs
    fn deinit(mut self):
        self.refs[0] -= 1
        if self.refs[0] == 0:
            self.refs.free()
    fn __init__(out self, size: Int, fill: Float32):
        self._size = size
        var p = alloc[Float32](size + 2)
        self.refs = p.bitcast[Int]()
        self.data = (p.bitcast[Int]() + 1).bitcast[Float32]()
        self.refs[0] = 1
        for i in range(size):
            self.data[i] = fill
    fn size(self) -> Int:
        return self._size
    @staticmethod
    fn zeros(size: Int) -> Vector:
        return Vector(size, 0.0)
    @staticmethod
    fn ones(size: Int) -> Vector:
        return Vector(size, 1.0)
    @staticmethod
    fn random(size: Int, std: Float32) -> Vector:
        var v = Vector(size)
        for i in range(size):
            v.data[i] = std * (Float32((i * 7 + 13) % 100)) / 100.0
        return v^
    fn __getitem__(self, idx: Int) -> Float32:
        return self.data[idx]
    fn __setitem__(mut self, idx: Int, val: Float32):
        self.data[idx] = val
    fn __add__(self, other: Vector) -> Vector:
        var r = Vector(self._size)
        for i in range(self._size):
            r.data[i] = self.data[i] + other.data[i]
        return r^
    fn __sub__(self, other: Vector) -> Vector:
        var r = Vector(self._size)
        for i in range(self._size):
            r.data[i] = self.data[i] - other.data[i]
        return r^
    fn __mul__(self, scalar: Float32) -> Vector:
        var r = Vector(self._size)
        for i in range(self._size):
            r.data[i] = self.data[i] * scalar
        return r^
    fn dot(self, other: Vector) -> Float32:
        var s: Float32 = 0.0
        for i in range(self._size):
            s += self.data[i] * other.data[i]
        return s

struct Matrix(Copyable):
    var data: UnsafePointer[Float32, MutAnyOrigin]
    var _rows: Int
    var _cols: Int
    var refs: UnsafePointer[Int, MutAnyOrigin]
    fn __init__(out self, rows: Int, cols: Int):
        self._rows = rows
        self._cols = cols
        var p = alloc[Float32](rows * cols + 2)
        self.refs = p.bitcast[Int]()
        self.data = (p.bitcast[Int]() + 1).bitcast[Float32]()
        self.refs[0] = 1
        for i in range(rows * cols):
            self.data[i] = 0.0
    fn __copyinit__(out self, copy: Self):
        self._rows = copy._rows
        self._cols = copy._cols
        self.data = copy.data
        self.refs = copy.refs
        self.refs[0] += 1
    fn __moveinit__(mut self, other: Self):
        self._rows = other._rows
        self._cols = other._cols
        self.data = other.data
        self.refs = other.refs
    fn deinit(mut self):
        self.refs[0] -= 1
        if self.refs[0] == 0:
            self.refs.free()
    fn shape(self) -> Tuple[Int, Int]:
        return (self._rows, self._cols)
    fn rows(self) -> Int:
        return self._rows
    fn cols(self) -> Int:
        return self._cols
    @staticmethod
    fn zeros(rows: Int, cols: Int) -> Matrix:
        return Matrix(rows, cols)
    @staticmethod
    fn ones(rows: Int, cols: Int) -> Matrix:
        var m = Matrix(rows, cols)
        for i in range(rows * cols):
            m.data[i] = 1.0
        return m^
    @staticmethod
    fn random(rows: Int, cols: Int, std: Float32) -> Matrix:
        var m = Matrix(rows, cols)
        var limit = sqrt(6.0 / Float32(rows + cols))
        for i in range(rows * cols):
            m.data[i] = limit * (Float32((i * 7 + 13) % 1000)) / 1000.0 - limit / 2.0
        return m^
    @staticmethod
    fn eye(n: Int) -> Matrix:
        var m = Matrix(n, n)
        for i in range(n):
            m[i, i] = 1.0
        return m^
    fn __getitem__(self, row: Int, col: Int) -> Float32:
        return self.data[row * self._cols + col]
    fn __setitem__(mut self, row: Int, col: Int, val: Float32):
        self.data[row * self._cols + col] = val
    fn row(self, idx: Int) -> Vector:
        var v = Vector(self._cols)
        for j in range(self._cols):
            v.data[j] = self.data[idx * self._cols + j]
        return v^
    fn set_row(mut self, idx: Int, vec: Vector):
        for j in range(self._cols):
            self.data[idx * self._cols + j] = vec.data[j]
    fn T(self) -> Matrix:
        var r = Matrix(self._cols, self._rows)
        for i in range(self._rows):
            for j in range(self._cols):
                r[j, i] = self[i, j]
        return r^
    fn slice_cols(self, start: Int, end: Int) -> Matrix:
        var r = Matrix(self._rows, end - start)
        for i in range(self._rows):
            for j in range(end - start):
                r[i, j] = self[i, start + j]
        return r^
    fn slice_rows(self, start: Int, end: Int) -> Matrix:
        var r = Matrix(end - start, self._cols)
        for i in range(start, end):
            for j in range(self._cols):
                r[i - start, j] = self[i, j]
        return r^
    fn __matmul__(self, other: Matrix) -> Matrix:
        var M = self._rows
        var K = self._cols
        var N = other._cols
        var r = Matrix(M, N)
        for i in range(M):
            for k in range(K):
                var a = self.data[i * K + k]
                for j in range(N):
                    r.data[i * N + j] += a * other.data[k * N + j]
        return r^
    # self @ other.T  (other transposed okunur, kopya yapılmaz)
    fn matmul_t(self, other: Matrix) -> Matrix:
        var M = self._rows
        var K = self._cols
        var N = other._rows
        var r = Matrix(M, N)
        for i in range(M):
            for j in range(N):
                var acc: Float32 = 0.0
                for k in range(K):
                    acc += self.data[i * K + k] * other.data[j * K + k]
                r.data[i * N + j] = acc
        return r^
    fn __mul__(self, scalar: Float32) -> Matrix:
        var r = Matrix(self._rows, self._cols)
        for i in range(self._rows * self._cols):
            r.data[i] = self.data[i] * scalar
        return r^
    fn __mul__(self, other: Matrix) -> Matrix:
        var r = Matrix(self._rows, self._cols)
        for i in range(self._rows * self._cols):
            r.data[i] = self.data[i] * other.data[i]
        return r^
    fn __add__(self, other: Matrix) -> Matrix:
        var r = Matrix(self._rows, self._cols)
        for i in range(self._rows * self._cols):
            r.data[i] = self.data[i] + other.data[i]
        return r^
    fn sqrt(self) -> Matrix:
        var r = Matrix(self._rows, self._cols)
        for i in range(self._rows * self._cols):
            r.data[i] = sqrt(self.data[i])
        return r^

fn min(a: Int, b: Int) -> Int:
    if a < b:
        return a
    return b

# ════════════════════════════════════════════════════════════════
# Config
# ════════════════════════════════════════════════════════════════
struct InferenceConfig(Copyable):
    var max_new_tokens: Int
    var temperature: Float32
    var top_k: Int
    var top_p: Float32
    var repetition_penalty: Float32
    var do_sample: Bool
    var stream: Bool
    fn __copyinit__(out self, copy: Self):
        self.max_new_tokens = copy.max_new_tokens
        self.temperature = copy.temperature
        self.top_k = copy.top_k
        self.top_p = copy.top_p
        self.repetition_penalty = copy.repetition_penalty
        self.do_sample = copy.do_sample
        self.stream = copy.stream
    fn __init__(
        out self,
        max_new_tokens: Int = 256,
        temperature: Float32 = 0.8,
        top_k: Int = 50,
        top_p: Float32 = 0.95,
        repetition_penalty: Float32 = 1.1,
        do_sample: Bool = True,
        stream: Bool = False,
    ):
        self.max_new_tokens = max_new_tokens
        self.temperature = temperature
        self.top_k = top_k
        self.top_p = top_p
        self.repetition_penalty = repetition_penalty
        self.do_sample = do_sample
        self.stream = stream
    @staticmethod
    fn greedy() -> InferenceConfig:
        return InferenceConfig(temperature=0.0, do_sample=False)
    @staticmethod
    fn creative() -> InferenceConfig:
        return InferenceConfig(temperature=1.2, top_k=100, top_p=0.9)
    @staticmethod
    fn balanced() -> InferenceConfig:
        return InferenceConfig(temperature=0.7, top_k=50, top_p=0.95)

# ════════════════════════════════════════════════════════════════
# Transformer
# ════════════════════════════════════════════════════════════════
struct TransformerConfig(Copyable):
    var vocab_size: Int
    var max_seq_len: Int
    var n_layers: Int
    var n_heads: Int
    var d_model: Int
    var d_ff: Int
    var dropout: Float32
    var bias: Bool
    fn __copyinit__(out self, copy: Self):
        self.vocab_size = copy.vocab_size
        self.max_seq_len = copy.max_seq_len
        self.n_layers = copy.n_layers
        self.n_heads = copy.n_heads
        self.d_model = copy.d_model
        self.d_ff = copy.d_ff
        self.dropout = copy.dropout
        self.bias = copy.bias
    fn __init__(
        out self,
        vocab_size: Int = 32000,
        max_seq_len: Int = 2048,
        n_layers: Int = 12,
        n_heads: Int = 12,
        d_model: Int = 768,
        d_ff: Int = 3072,
        dropout: Float32 = 0.1,
        bias: Bool = True,
    ):
        self.vocab_size = vocab_size
        self.max_seq_len = max_seq_len
        self.n_layers = n_layers
        self.n_heads = n_heads
        self.d_model = d_model
        self.d_ff = d_ff
        self.dropout = dropout
        self.bias = bias
    @staticmethod
    fn tiny() -> TransformerConfig:
        return TransformerConfig(vocab_size=32000, max_seq_len=512, n_layers=4, n_heads=4, d_model=256, d_ff=1024)
    @staticmethod
    fn small() -> TransformerConfig:
        return TransformerConfig(vocab_size=32000, max_seq_len=1024, n_layers=12, n_heads=12, d_model=768, d_ff=3072)
    @staticmethod
    fn medium() -> TransformerConfig:
        return TransformerConfig(vocab_size=32000, max_seq_len=2048, n_layers=24, n_heads=16, d_model=1024, d_ff=4096)
    @staticmethod
    fn large() -> TransformerConfig:
        return TransformerConfig(vocab_size=32000, max_seq_len=4096, n_layers=24, n_heads=32, d_model=2048, d_ff=8192)
    fn param_count(self) -> Int:
        var count = 0
        count += self.vocab_size * self.d_model
        count += self.max_seq_len * self.d_model
        var per = (self.d_model * 3 * self.d_model
            + self.d_model * self.d_model
            + self.d_model * self.d_ff
            + self.d_ff * self.d_model
            + self.d_model * 2 + self.d_model * 2)
        count += per * self.n_layers
        count += self.d_model * 2
        count += self.d_model * self.vocab_size
        return count

struct TransformerLayer(Copyable):
    var attn_qkv: Matrix
    var attn_out: Matrix
    var ff_up: Matrix
    var ff_down: Matrix
    var ln1_gamma: Vector
    var ln1_beta: Vector
    var ln2_gamma: Vector
    var ln2_beta: Vector
    fn __copyinit__(out self, copy: Self):
        self.attn_qkv = copy.attn_qkv.copy()
        self.attn_out = copy.attn_out.copy()
        self.ff_up = copy.ff_up.copy()
        self.ff_down = copy.ff_down.copy()
        self.ln1_gamma = copy.ln1_gamma.copy()
        self.ln1_beta = copy.ln1_beta.copy()
        self.ln2_gamma = copy.ln2_gamma.copy()
        self.ln2_beta = copy.ln2_beta.copy()
    fn __init__(out self, config: TransformerConfig):
        var d = config.d_model
        var d_ff = config.d_ff
        var std = 1.0 / sqrt(Float32(d))
        self.attn_qkv = Matrix.random(d, 3 * d, std)
        self.attn_out = Matrix.random(d, d, std)
        self.ff_up = Matrix.random(d, d_ff, std)
        self.ff_down = Matrix.random(d_ff, d, std)
        self.ln1_gamma = Vector.ones(d)
        self.ln1_beta = Vector.zeros(d)
        self.ln2_gamma = Vector.ones(d)
        self.ln2_beta = Vector.zeros(d)
    fn forward(mut self, x: Matrix, mask: Matrix, freqs_cis: Matrix) -> Matrix:
        var h = x.copy()
        var h1 = layer_norm(h, self.ln1_gamma, self.ln1_beta)
        var attn_out = self._attention(h1, mask, freqs_cis)
        h = h + attn_out
        var h2 = layer_norm(h, self.ln2_gamma, self.ln2_beta)
        var ff_out = self._feed_forward(h2)
        h = h + ff_out
        return h^
    fn _attention(mut self, x: Matrix, mask: Matrix, freqs_cis: Matrix) -> Matrix:
        var sh = x.shape()
        var seq_len = sh[0]
        var d_model = sh[1]
        var n_heads = d_model
        var head_dim = d_model // n_heads
        var qkv = x @ self.attn_qkv
        var q = qkv.slice_cols(0, n_heads * head_dim)
        var k = qkv.slice_cols(n_heads * head_dim, 2 * n_heads * head_dim)
        var v = qkv.slice_cols(2 * n_heads * head_dim, 3 * n_heads * head_dim)
        var q_rope = apply_rope(q, freqs_cis)
        var k_rope = apply_rope(k, freqs_cis)
        var scale = 1.0 / sqrt(Float32(head_dim))
        var scores = (q_rope.matmul_t(k_rope)) * scale
        var masked = scores + mask
        var aw = softmax(masked)
        var ao = aw @ v
        return ao @ self.attn_out
    fn _feed_forward(mut self, x: Matrix) -> Matrix:
        var gate = silu(x @ self.ff_up)
        var up = x @ self.ff_up
        return (gate * up) @ self.ff_down

struct Transformer(Copyable):
    var config: TransformerConfig
    var layers: List[TransformerLayer]
    var token_embedding: Matrix
    var pos_embedding: Matrix
    var final_norm_gamma: Vector
    var final_norm_beta: Vector
    var lm_head: Matrix
    fn __copyinit__(out self, copy: Self):
        self.config = copy.config.copy()
        self.layers = copy.layers.copy()
        self.token_embedding = copy.token_embedding.copy()
        self.pos_embedding = copy.pos_embedding.copy()
        self.final_norm_gamma = copy.final_norm_gamma.copy()
        self.final_norm_beta = copy.final_norm_beta.copy()
        self.lm_head = copy.lm_head.copy()
    fn __init__(out self, config: TransformerConfig):
        self.config = config.copy()
        var std = 1.0 / sqrt(Float32(config.d_model))
        self.token_embedding = Matrix.random(config.vocab_size, config.d_model, std)
        self.pos_embedding = Matrix.zeros(config.max_seq_len, config.d_model)
        self.layers = List[TransformerLayer]()
        for i in range(config.n_layers):
            self.layers.append(TransformerLayer(config))
        self.final_norm_gamma = Vector.ones(config.d_model)
        self.final_norm_beta = Vector.zeros(config.d_model)
        self.lm_head = Matrix.random(config.d_model, config.vocab_size, std)
    fn forward(mut self, tokens: List[Int]) -> Matrix:
        var seq_len = len(tokens)
        var d = self.config.d_model
        var x = Matrix.zeros(seq_len, d)
        for i in range(seq_len):
            var emb = self.token_embedding.row(tokens[i])
            var pos = self.pos_embedding.row(i)
            x.set_row(i, emb + pos)
        var mask = causal_mask(seq_len)
        var freqs_cis = precompute_freqs_cis(d // self.config.n_heads, seq_len)
        for i in range(len(self.layers)):
            x = self.layers[i].forward(x, mask, freqs_cis)
        x = layer_norm(x, self.final_norm_gamma, self.final_norm_beta)
        return x @ self.lm_head
    fn param_count(self) -> Int:
        return self.config.param_count()

fn layer_norm(x: Matrix, gamma: Vector, beta: Vector) -> Matrix:
    var sh = x.shape()
    var rows = sh[0]
    var cols = sh[1]
    var r = Matrix.zeros(rows, cols)
    for i in range(rows):
        # Welford tek-pass: mean + variance aynı döngüde
        var mean: Float32 = 0.0
        var m2: Float32 = 0.0
        for j in range(cols):
            var val = x[i, j]
            var d = val - mean
            mean += d / Float32(j + 1)
            m2 += d * (val - mean)
        var var_ = m2 / Float32(cols)
        var std = sqrt(var_ + 1e-5)
        for j in range(cols):
            r[i, j] = (x[i, j] - mean) / std * gamma[j] + beta[j]
    return r^

fn silu(x: Matrix) -> Matrix:
    var r = Matrix.zeros(x.rows(), x.cols())
    for i in range(x.rows()):
        for j in range(x.cols()):
            var val = x[i, j]
            r[i, j] = val / (1.0 + exp(-val))
    return r^

fn softmax(x: Matrix) -> Matrix:
    var r = Matrix.zeros(x.rows(), x.cols())
    for i in range(x.rows()):
        var mx = x[i, 0]
        for j in range(1, x.cols()):
            if x[i, j] > mx:
                mx = x[i, j]
        var se: Float32 = 0.0
        for j in range(x.cols()):
            r[i, j] = exp(x[i, j] - mx)
            se += r[i, j]
        for j in range(x.cols()):
            r[i, j] /= se
    return r^

fn causal_mask(seq_len: Int) -> Matrix:
    var m = Matrix.zeros(seq_len, seq_len)
    for i in range(seq_len):
        for j in range(i + 1, seq_len):
            m[i, j] = -1e9
    return m^

# query (seq_len satır) x key (start_pos + seq_len sütun); sadece geçmişe ve kendine erişim
fn causal_mask_offset(seq_len: Int, start_pos: Int) -> Matrix:
    var total = start_pos + seq_len
    var m = Matrix.zeros(seq_len, total)
    for i in range(seq_len):
        var q_pos = start_pos + i
        for j in range(total):
            if j > q_pos:
                m[i, j] = -1e9
    return m^

fn precompute_freqs_cis(dim: Int, seq_len: Int) -> Matrix:
    var f = Matrix.zeros(seq_len, dim)
    var theta = 10000.0
    for i in range(seq_len):
        for j in range(0, dim, 2):
            var freq: Float32 = Float32(pow(Float64(theta), Float64(j) / Float64(dim)))
            f[i, j] = Float32(i) * freq
            f[i, j + 1] = Float32(i) * freq
    return f^

fn apply_rope(x: Matrix, freqs_cis: Matrix) -> Matrix:
    var sh = x.shape()
    var seq_len = sh[0]
    var dim = sh[1]
    var r = Matrix.zeros(seq_len, dim)
    for i in range(seq_len):
        for j in range(0, dim, 2):
            var cv = cos(freqs_cis[i, j])
            var sv = sin(freqs_cis[i, j])
            r[i, j] = x[i, j] * cv - x[i, j + 1] * sv
            r[i, j + 1] = x[i, j] * sv + x[i, j + 1] * cv
    return r^

# ════════════════════════════════════════════════════════════════
# BPE Tokenizer
# ════════════════════════════════════════════════════════════════
struct BPETokenizer(Copyable):
    var vocab: Dict[String, Int]
    var inv_vocab: Dict[Int, String]
    var merges: List[String]
    var vocab_size: Int
    fn __copyinit__(out self, copy: Self):
        self.vocab = copy.vocab.copy()
        self.inv_vocab = copy.inv_vocab.copy()
        self.merges = copy.merges.copy()
        self.vocab_size = copy.vocab_size
    fn __init__(out self):
        self.vocab = Dict[String, Int]()
        self.inv_vocab = Dict[Int, String]()
        self.merges = List[String]()
        self.vocab_size = 0
    fn tokenize(mut self, text: String) raises -> List[Int]:
        var tokens = List[Int]()
        var chars = List[String]()
        for cp in text.codepoints():
            chars.append(String(cp))
        while len(chars) > 1:
            var best_rank = -1
            var best_idx = 0
            for i in range(len(chars) - 1):
                var pair = String(chars[i]) + String(chars[i + 1])
                var r = self._find_rank(pair)
                if r != -1 and (best_rank == -1 or r < best_rank):
                    best_rank = r
                    best_idx = i
            if best_rank == -1:
                break
            var merged = String(chars[best_idx]) + String(chars[best_idx + 1])
            chars[best_idx] = merged
            var nc = List[String]()
            for i in range(len(chars)):
                if i != best_idx + 1:
                    nc.append(chars[i])
            chars = nc^
        for i in range(len(chars)):
            tokens.append(self._get_id(chars[i]))
        return tokens^
    fn detokenize(self, tokens: List[Int]) raises -> String:
        var r = ""
        for i in range(len(tokens)):
            if tokens[i] in self.inv_vocab:
                r += self.inv_vocab[tokens[i]]
        return r^
    fn _find_rank(self, pair: String) -> Int:
        for i in range(len(self.merges)):
            if self.merges[i] == pair:
                return i
        return -1
    fn _get_id(mut self, token: String) raises -> Int:
        if token in self.vocab:
            return self.vocab[token]
        var nid = self.vocab_size
        self.vocab[token] = nid
        self.inv_vocab[nid] = token
        self.vocab_size += 1
        return nid

# ════════════════════════════════════════════════════════════════
# Inference
# ════════════════════════════════════════════════════════════════
struct InferenceResult:
    var tokens: List[Int]
    var text: String
    var logits: Matrix
    var prompt_tokens: Int
    var generated_tokens: Int
    var total_time_ms: Float32
    var tokens_per_second: Float32
    fn __init__(
        out self,
        tokens: List[Int],
        text: String,
        logits: Matrix,
        prompt_tokens: Int,
        generated_tokens: Int,
        total_time_ms: Float32,
        tokens_per_second: Float32,
    ):
        self.tokens = tokens.copy()
        self.text = text.copy()
        self.logits = logits.copy()
        self.prompt_tokens = prompt_tokens
        self.generated_tokens = generated_tokens
        self.total_time_ms = total_time_ms
        self.tokens_per_second = tokens_per_second

struct InferenceEngine:
    var model: Transformer
    var tokenizer: BPETokenizer
    var config: InferenceConfig
    fn __init__(out self, model: Transformer, tokenizer: BPETokenizer, config: InferenceConfig):
        self.model = model.copy()
        self.tokenizer = tokenizer.copy()
        self.config = config.copy()
    fn generate(mut self, prompt: String, max_tokens: Int = 256, temperature: Float32 = 0.8, top_k: Int = 50, top_p: Float32 = 0.95) raises -> InferenceResult:
        var tokens = self.tokenizer.tokenize(prompt)
        var prompt_len = len(tokens)
        var generated = List[Int]()
        var logits = Matrix.zeros(1, 1)
        for i in range(max_tokens):
            logits = self.model.forward(tokens)
            var last = logits.row(logits.rows() - 1)
            var nt = self._sample(last, temperature, top_k, top_p)
            if nt == 0:
                break
            generated.append(nt)
            tokens.append(nt)
            if len(tokens) > self.model.config.max_seq_len:
                var keep = len(tokens) - self.model.config.max_seq_len
                var nt = List[Int]()
                for i in range(keep, len(tokens)):
                    nt.append(tokens[i])
                tokens = nt^
        var all = List[Int]()
        for i in range(prompt_len):
            all.append(tokens[i])
        for i in range(len(generated)):
            all.append(generated[i])
        var text = self.tokenizer.detokenize(all)
        return InferenceResult(
            tokens=all, text=text, logits=logits^, prompt_tokens=prompt_len,
            generated_tokens=len(generated), total_time_ms=0.0, tokens_per_second=0.0)
    fn _sample(mut self, logits: Vector, temperature: Float32, top_k: Int, top_p: Float32) -> Int:
        var size = logits.size()
        var probs = Vector.zeros(size)
        var mx = logits[0]
        for i in range(1, size):
            if logits[i] > mx:
                mx = logits[i]
        var se: Float32 = 0.0
        for i in range(size):
            probs[i] = exp(logits[i] / temperature - mx)
            se += probs[i]
        for i in range(size):
            probs[i] /= se
        if top_k > 0 and top_k < size:
            var idx = List[Int]()
            for i in range(size):
                idx.append(i)
            for i in range(min(top_k, size)):
                var mi = i
                for j in range(i + 1, size):
                    if probs[idx[j]] > probs[idx[mi]]:
                        mi = j
                var t = idx[i]
                idx[i] = idx[mi]
                idx[mi] = t
            var np = Vector.zeros(size)
            var ns: Float32 = 0.0
            for i in range(min(top_k, size)):
                np[idx[i]] = probs[idx[i]]
                ns += probs[idx[i]]
            if ns > 0:
                for i in range(size):
                    np[i] /= ns
            probs = np^
        if top_p < 1.0:
            var sp = List[Float32]()
            for i in range(size):
                sp.append(probs[i])
            for i in range(size):
                for j in range(size - 1 - i):
                    if sp[j] < sp[j + 1]:
                        var t = sp[j]
                        sp[j] = sp[j + 1]
                        sp[j + 1] = t
            var cs = Float32(0.0)
            var co = Float32(0.0)
            for i in range(size):
                cs += sp[i]
                if cs >= top_p:
                    co = sp[i]
                    break
            var ns: Float32 = 0.0
            for i in range(size):
                if probs[i] < co:
                    probs[i] = 0.0
                else:
                    ns += probs[i]
            if ns > 0:
                for i in range(size):
                    probs[i] /= ns
        var r = Float32(0.42)
        var cs = Float32(0.0)
        for i in range(size):
            cs += probs[i]
            if cs >= r:
                return i
        return 0

# ════════════════════════════════════════════════════════════════
# CLI
# ════════════════════════════════════════════════════════════════
fn atoi(s: String) -> Int:
    var result = 0
    var neg = False
    var started = False
    for i in range(len(s)):
        var c = s.unsafe_ptr()[i]
        if c == UInt8(ord("-")) and not started:
            neg = True
            started = True
        elif c >= UInt8(ord("0")) and c <= UInt8(ord("9")):
            result = result * 10 + (Int(c) - Int(ord("0")))
            started = True
        elif started:
            break
    if neg:
        return -result
    return result

fn atof(s: String) -> Float32:
    var result: Float32 = 0.0
    var frac: Float32 = 0.0
    var div: Float32 = 1.0
    var neg = False
    var dot = False
    var started = False
    for i in range(len(s)):
        var c = s.unsafe_ptr()[i]
        if c == UInt8(ord("-")) and not started:
            neg = True
            started = True
        elif c == UInt8(ord(".")):
            dot = True
            started = True
        elif c >= UInt8(ord("0")) and c <= UInt8(ord("9")):
            var d = Float32(Int(c) - Int(ord("0")))
            if dot:
                div = div * 10.0
                frac = frac * 10.0 + d
            else:
                result = result * 10.0 + d
            started = True
        elif started:
            break
    var val = result + frac / div
    if neg:
        val = -val
    return val

fn _get_model_config(size: String) -> TransformerConfig:
    if size == "tiny":
        return TransformerConfig.tiny()
    elif size == "small":
        return TransformerConfig.small()
    elif size == "medium":
        return TransformerConfig.medium()
    elif size == "large":
        return TransformerConfig.large()
    return TransformerConfig.tiny()

fn _get_quant_savings(quant: String) -> Float32:
    if quant == "fp16":
        return 0.5
    elif quant == "int8":
        return 0.25
    elif quant == "int4":
        return 0.125
    elif quant == "nf4":
        return 0.125
    return 1.0

fn _print_usage():
    print(
        """
=== mojo-llm v0.3.0 (tek dosya, UnsafePointer) ===
Kullanim: mojo run main.mojo <komut> [secenekler]
Komutlar: info, infer, quantize, benchmark, help
"""
    )

fn main() raises:
    var args = List[String]()
    for a in argv():
        args.append(a)
    if len(args) < 2:
        _print_usage()
        return
    var command = args[1]
    if command == "info":
        var ms = "tiny"
        if len(args) > 2:
            ms = args[2]
        var cfg = _get_model_config(ms)
        print("Model: " + ms)
        print("d_model: " + String(cfg.d_model))
        print("katman: " + String(cfg.n_layers))
        print("head: " + String(cfg.n_heads))
        print("vocab: " + String(cfg.vocab_size))
        print("parametre: " + String(cfg.param_count()))
        print("fp32 MB: " + String(cfg.param_count() * 4 / 1024 / 1024))
    elif command == "infer" or command == "inference":
        var ms = "tiny"
        var prompt = "Merhaba"
        var max_t = 64
        var temp: Float32 = 0.8
        var tk = 50
        var tp: Float32 = 0.95
        var i = 2
        while i < len(args):
            if args[i] == "--model" and i + 1 < len(args):
                ms = args[i + 1]; i += 2
            elif args[i] == "--prompt" and i + 1 < len(args):
                prompt = args[i + 1]; i += 2
            elif args[i] == "--max-tokens" and i + 1 < len(args):
                max_t = atoi(args[i + 1]); i += 2
            elif args[i] == "--temperature" and i + 1 < len(args):
                temp = atof(args[i + 1]); i += 2
            elif args[i] == "--top-k" and i + 1 < len(args):
                tk = atoi(args[i + 1]); i += 2
            elif args[i] == "--top-p" and i + 1 < len(args):
                tp = Float32(atof(args[i + 1])); i += 2
            else:
                i += 1
        var cfg = _get_model_config(ms)
        var model = Transformer(cfg)
        var tok = BPETokenizer()
        var icfg = InferenceConfig(max_new_tokens=max_t)
        var engine = InferenceEngine(model, tok, icfg)
        print("Model: " + ms + " | Prompt: " + prompt)
        print("-" * 50)
        var res = engine.generate(prompt, max_t, temp, tk, tp)
        print(res.text)
        print("-" * 50)
        print("Uretilen: " + String(res.generated_tokens) + " token")
    elif command == "quantize":
        var ms = "tiny"
        var qt = "int8"
        var i = 2
        while i < len(args):
            if args[i] == "--model" and i + 1 < len(args):
                ms = args[i + 1]; i += 2
            elif args[i] == "--quant" and i + 1 < len(args):
                qt = args[i + 1]; i += 2
            else:
                i += 1
        var cfg = _get_model_config(ms)
        var ob = cfg.param_count() * 4
        var sv = _get_quant_savings(qt)
        print("Model: " + ms + " | quant: " + qt)
        print("Orijinal: " + String(ob / 1024 / 1024) + " MB")
        print("Sikistirilmis: " + String(Int(Float32(ob) * sv) / 1024 / 1024) + " MB")
    elif command == "benchmark":
        var ms = "tiny"
        var prompt = "Test"
        var max_t = 32
        var temp: Float32 = 0.8
        var tp: Float32 = 0.95
        var i = 2
        while i < len(args):
            if args[i] == "--model" and i + 1 < len(args):
                ms = args[i + 1]; i += 2
            elif args[i] == "--prompt" and i + 1 < len(args):
                prompt = args[i + 1]; i += 2
            elif args[i] == "--max-tokens" and i + 1 < len(args):
                max_t = atoi(args[i + 1]); i += 2
            else:
                i += 1
        var cfg = _get_model_config(ms)
        var model = Transformer(cfg)
        var tok = BPETokenizer()
        var icfg = InferenceConfig(max_new_tokens=max_t)
        var engine = InferenceEngine(model, tok, icfg)
        print("Warmup...")
        for i in range(3):
            _ = engine.generate(prompt, 10)
        print("Benchmark...")
        var total = 0
        for i in range(5):
            var r = engine.generate(prompt, max_t)
            total += r.generated_tokens
            print("  Run " + String(i + 1) + ": " + String(r.generated_tokens))
        print("Toplam: " + String(total))
    else:
        _print_usage()
