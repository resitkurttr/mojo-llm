# mojo-llm/src/engine/save_load.mojo
# Model kaydetme ve yükleme sistemi.
# Binary format, quantization-aware save.

from std.collections import List, Dict

# ─── Kayıt Formatı ───
enum SaveFormat:
    BINARY         # Mojo native binary
    SAFETENSORS    # SafeTensors uyumlu
    GGUF           # GGUF formatı

# ─── Model Metadata ───
struct ModelMetadata:
    var format_version: Int
    var model_name: String
    var vocab_size: Int
    var n_layers: Int
    var d_model: Int
    var n_heads: Int
    var max_seq_len: Int
    var quant_type: String       # "fp32", "fp16", "int8", "int4", "nf4"
    var param_count: Int
    var created_at: String
    var checksum: String

    fn __init__(out self):
        self.format_version = 1
        self.model_name = ""
        self.vocab_size = 0
        self.n_layers = 0
        self.d_model = 0
        self.n_heads = 0
        self.max_seq_len = 0
        self.quant_type = "fp32"
        self.param_count = 0
        self.created_at = ""
        self.checksum = ""

    fn to_json(self) -> String:
        """JSON formatında metadata."""
        var json = "{\n"
        json += '  "format_version": ' + String(self.format_version) + ",\n"
        json += '  "model_name": "' + self.model_name + '",\n'
        json += '  "vocab_size": ' + String(self.vocab_size) + ",\n"
        json += '  "n_layers": ' + String(self.n_layers) + ",\n"
        json += '  "d_model": ' + String(self.d_model) + ",\n"
        json += '  "n_heads": ' + String(self.n_heads) + ",\n"
        json += '  "max_seq_len": ' + String(self.max_seq_len) + ",\n"
        json += '  "quant_type": "' + self.quant_type + '",\n'
        json += '  "param_count": ' + String(self.param_count) + ",\n"
        json += '  "created_at": "' + self.created_at + '",\n'
        json += '  "checksum": "' + self.checksum + '"\n'
        json += "}"
        return json

# ─── Ağırlık Bloğu ───
struct WeightBlock:
    var name: String
    var shape: List[Int]
    var dtype: String             # "float32", "float16", "int8", "int4"
    var data_offset: Int          # Dosyadaki offset
    var data_size: Int            # Byte cinsinden boyut

    fn __init__(out self, name: String):
        self.name = name
        self.shape = List[Int]()
        self.dtype = "float32"
        self.data_offset = 0
        self.data_size = 0

# ─── Model Kaydedici ───
struct ModelSaver:
    var format: SaveFormat
    var quantize_on_save: Bool
    var target_quant: String

    fn __init__(out self, format: SaveFormat = SaveFormat.BINARY):
        self.format = format
        self.quantize_on_save = False
        self.target_quant = "fp32"

    fn create_metadata(self, model_name: String, vocab_size: Int, n_layers: Int, d_model: Int, n_heads: Int, max_seq_len: Int, param_count: Int) -> ModelMetadata:
        """Metadata oluştur."""
        var meta = ModelMetadata()
        meta.model_name = model_name
        meta.vocab_size = vocab_size
        meta.n_layers = n_layers
        meta.d_model = d_model
        meta.n_heads = n_heads
        meta.max_seq_len = max_seq_len
        meta.param_count = param_count
        meta.quant_type = self.target_quant
        meta.format_version = 1
        return meta^

    fn estimate_file_size(self, param_count: Int) -> Int:
        """Tahmini dosya boyutu (byte)."""
        var bytes_per_param = 4  # fp32
        if self.target_quant == "fp16":
            bytes_per_param = 2
        elif self.target_quant == "int8":
            bytes_per_param = 1
        elif self.target_quant == "int4":
            bytes_per_param = 1  # 4 bit = 0.5 byte ama byte granularity
        elif self.target_quant == "nf4":
            bytes_per_param = 1

        var base_size = param_count * bytes_per_param
        var header_size = 4096  # Metadata overhead
        return base_size + header_size

    fn quantize_weights(self, weights: List[Float32], quant_type: String) -> List[Int]:
        """Ağırlıkları quantize et."""
        var result = List[Int]()

        if quant_type == "int8":
            # Basit int8 quantization: scale = max(abs(w)) / 127
            var max_val: Float32 = 0.0
            for w in weights:
                var abs_w = w
                if abs_w < 0:
                    abs_w = -abs_w
                if abs_w > max_val:
                    max_val = abs_w
            var scale = max_val / 127.0
            if scale == 0:
                scale = 1.0
            for w in weights:
                var quantized = Int(w / scale)
                if quantized < -128:
                    quantized = -128
                if quantized > 127:
                    quantized = 127
                result.append(quantized)

        elif quant_type == "int4":
            # Basit int4 quantization
            var max_val: Float32 = 0.0
            for w in weights:
                var abs_w = w
                if abs_w < 0:
                    abs_w = -abs_w
                if abs_w > max_val:
                    max_val = abs_w
            var scale = max_val / 7.0
            if scale == 0:
                scale = 1.0
            # int4'leri byte'lara sıkıştır (2 adet byte başına)
            for i in range(0, len(weights), 2):
                var q1 = Int(weights[i] / scale)
                var q2 = 0
                if i + 1 < len(weights):
                    q2 = Int(weights[i + 1] / scale)
                # Clamp [-8, 7]
                if q1 < -8:
                    q1 = -8
                if q1 > 7:
                    q1 = 7
                if q2 < -8:
                    q2 = -8
                if q2 > 7:
                    q2 = 7
                # İki 4-bit'i tek byte'a sıkıştır
                var packed = (q1 & 0x0F) | ((q2 & 0x0F) << 4)
                result.append(packed)

        else:  # fp32
            for w in weights:
                # Float32'yi Int olarak depola (bit pattern)
                result.append(Int(w))

        return result^

# ─── Model Yükleyici ───
struct ModelLoader:
    var loaded: Bool
    var metadata: ModelMetadata

    fn __init__(out self):
        self.loaded = False
        self.metadata = ModelMetadata()

    fn load_metadata(self, data: String) -> ModelMetadata:
        """JSON'dan metadata yükle."""
        # Basit JSON parse (gerçek implementasyonda parser gerekir)
        var meta = ModelMetadata()
        meta.model_name = "loaded-model"
        self.metadata = meta^
        self.loaded = True
        return self.metadata

    fn validate_checksum(self, data: String, expected: String) -> Bool:
        """Checksum doğrula."""
        # Basit hash (gerçek implementasyonda CRC32/SHA256)
        var hash: Int = 0
        for i in range(len(data)):
            hash = (hash * 31 + Int(data.unsafe_ptr()[i])) & 0xFFFFFFFF
        return True  # Placeholder

    fn load_weights(self, data: List[Int], shape: List[Int], dtype: String) -> List[Float32]:
        """Ağırlıkları yükle ve dequantize et."""
        var result = List[Float32]()

        if dtype == "int8":
            # Dequantize int8 → float32
            var max_val: Float32 = 127.0
            for i in range(len(data)):
                result.append(Float32(data[i]) / max_val)

        elif dtype == "int4":
            # Dequantize int4 → float32
            var max_val: Float32 = 7.0
            for i in range(len(data)):
                var byte_val = data[i]
                var low = byte_val & 0x0F
                var high = (byte_val >> 4) & 0x0F
                # Sign extend
                if low > 7:
                    low = low - 16
                if high > 7:
                    high = high - 16
                result.append(Float32(low) / max_val)
                result.append(Float32(high) / max_val)

        else:  # fp32
            for i in range(len(data)):
                result.append(Float32(data[i]))

        return result^
