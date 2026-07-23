# mojo-llm/src/core/flash_attention.mojo
# Flash Attention V2 — bellek-verimli dikkat hesaplama.
# Tile-based, online softmax. O(N²) bellek → O(N) bellek.

from std.math import sqrt, exp

struct FlashConfig:
    var block_size: Int
    var num_heads: Int
    var head_dim: Int
    var scale: Float32

    fn __init__(out self, num_heads: Int = 12, head_dim: Int = 64, block_size: Int = 128):
        self.num_heads = num_heads
        self.head_dim = head_dim
        self.block_size = block_size
        self.scale = 1.0 / sqrt(Float32(head_dim))

    @staticmethod
    fn from_d_model(d_model: Int, n_heads: Int, block_size: Int = 128) -> FlashConfig:
        return FlashConfig(n_heads, d_model // n_heads, block_size)

struct OnlineSoftmaxState:
    var row_max: Float32
    var row_sum: Float32
    var correction: Float32

    fn __init__(out self):
        self.row_max = -1e30
        self.row_sum = 0.0
        self.correction = 1.0

    fn update(mut self, new_max: Float32):
        var old_max = self.row_max
        if new_max > old_max:
            self.correction = exp(old_max - new_max)
            self.row_sum = self.row_sum * self.correction + 1.0
            self.row_max = new_max
        else:
            self.row_sum += exp(new_max - old_max)

struct FlashAttention:
    var config: FlashConfig

    fn __init__(out self, config: FlashConfig):
        self.config = config

    fn forward(self, Q: Matrix, K: Matrix, V: Matrix) -> Matrix:
        var seq_len = Q.rows()
        var head_dim = Q.cols()
        var bs = self.config.block_size
        var O = Matrix.zeros(seq_len, head_dim)
        var num_blocks = (seq_len + bs - 1) // bs

        for i_blk in range(num_blocks):
            var i_s = i_blk * bs
            var i_e = _min(i_s + bs, seq_len)
            var state = OnlineSoftmaxState()

            for j_blk in range(num_blocks):
                var j_s = j_blk * bs
                var j_e = _min(j_s + bs, seq_len)
                var Qb = Q.slice_rows(i_s, i_e)
                var Kb = K.slice_rows(j_s, j_e)
                var Vb = V.slice_rows(j_s, j_e)

                var S = Qb.matmul_t(Kb) * self.config.scale
                # Causal mask
                for ii in range(i_e - i_s):
                    for jj in range(j_e - j_s):
                        if (j_s + jj) > (i_s + ii):
                            S[ii, jj] = -1e30

                var local_max = self._row_max(S)
                state.update(local_max)
                var P = self._exp_shifted(S, state.row_max)
                var PV = P @ Vb
                O = O + PV * state.correction
                state.row_sum += self._row_sum(P)

            for i in range(i_e - i_s):
                if state.row_sum > 0:
                    for j in range(head_dim):
                        O[i_s + i, j] /= state.row_sum
        return O^

    fn _row_max(self, m: Matrix) -> Float32:
        var mx: Float32 = -1e30
        for i in range(m.rows()):
            for j in range(m.cols()):
                if m[i, j] > mx:
                    mx = m[i, j]
        return mx

    fn _row_sum(self, m: Matrix) -> Float32:
        var s: Float32 = 0.0
        for i in range(m.rows()):
            for j in range(m.cols()):
                s += m[i, j]
        return s

    fn _exp_shifted(self, m: Matrix, shift: Float32) -> Matrix:
        var r = Matrix.zeros(m.rows(), m.cols())
        for i in range(m.rows()):
            for j in range(m.cols()):
                r[i, j] = exp(m[i, j] - shift)
        return r^

    fn memory_bytes(self, seq_len: Int) -> Int:
        var bs = self.config.block_size
        var nb = (seq_len + bs - 1) // bs
        return nb * bs * self.config.head_dim * 4 * 3

    fn vs_naive(self, seq_len: Int) -> String:
        var naive = seq_len * seq_len * 4
        var flash = self.memory_bytes(seq_len)
        return "Naif: " + String(naive // 1024) + " KB | Flash: " + String(flash // 1024) + " KB | " + String(naive // max(flash, 1)) + "x kazanç"

fn _min(a: Int, b: Int) -> Int:
    if a < b: return a
    return b

fn max(a: Int, b: Int) -> Int:
    if a > b: return a
    return b
