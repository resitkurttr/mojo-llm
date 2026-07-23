# mojo-llm/src/engine/gguf.mojo
# GGUF (GPT-Generated Unified Format) desteği.
# GGML tabanlı, llama.cpp ile uyumlu.
# GGUF okuma/yazma, metadata parsing.

from std.collections import List, Dict

# ─── GGUF Magic ───
let GGUF_MAGIC: Int = 0x46554747  # "GGUF" little-endian
let GGUF_VERSION: Int = 3

# ─── GGUF ValueType ───
enum GGUFValueType:
    UINT8 = 0
    INT8 = 1
    UINT16 = 2
    INT16 = 3
    UINT32 = 4
    INT32 = 5
    FLOAT32 = 6
    BOOL = 7
    STRING = 8
    ARRAY = 9
    UINT64 = 10
    INT64 = 11
    FLOAT64 = 12

# ─── GGUF Metadata Entry ───
struct GGUFMetadataEntry:
    var key: String
    var value_type: GGUFValueType
    var value_str: String
    var value_int: Int
    var value_float: Float32
    var value_bool: Bool

    fn __init__(out self, key: String):
        self.key = key
        self.value_type = GGUFValueType.STRING
        self.value_str = ""
        self.value_int = 0
        self.value_float = 0.0
        self.value_bool = False

# ─── GGUF Tensor Info ───
struct GGUFTensorInfo:
    var name: String
    var n_dims: Int
    var shape: List[Int]
    var dtype: Int
    var offset: Int

    fn __init__(out self, name: String):
        self.name = name
        self.n_dims = 0
        self.shape = List[Int]()
        self.dtype = 0
        self.offset = 0

# ─── GGUF Dosyası ───
struct GGUFFile:
    var version: Int
    var n_tensors: Int
    var n_kv: Int
    var metadata: List[GGUFMetadataEntry]
    var tensors: List[GGUFTensorInfo]
    var data_offset: Int

    fn __init__(out self):
        self.version = 0
        self.n_tensors = 0
        self.n_kv = 0
        self.metadata = List[GGUFMetadataEntry]()
        self.tensors = List[GGUFTensorInfo]()
        self.data_offset = 0

    fn get_metadata(self, key: String) -> String:
        """Metadata değerini getir."""
        for i in range(len(self.metadata)):
            if self.metadata[i].key == key:
                return self.metadata[i].value_str
        return ""

    fn get_metadata_int(self, key: String) -> Int:
        """Metadata int değerini getir."""
        for i in range(len(self.metadata)):
            if self.metadata[i].key == key:
                return self.metadata[i].value_int
        return 0

    fn get_tensor_info(self, name: String) -> GGUFTensorInfo:
        """Tensor bilgisini getir."""
        for i in range(len(self.tensors)):
            if self.tensors[i].name == name:
                return self.tensors[i]
        return GGUFTensorInfo("")

    fn summary(self) -> String:
        """Dosya özeti."""
        var s = "GGUF Dosyası:\n"
        s += "  Versiyon: " + String(self.version) + "\n"
        s += "  Tensor: " + String(self.n_tensors) + "\n"
        s += "  Metadata: " + String(self.n_kv) + "\n"
        s += "  Data offset: " + String(self.data_offset) + "\n"

        # Önemli metadata'ları göster
        for i in range(len(self.metadata)):
            var key = self.metadata[i].key
            if key == "general.architecture" or key == "general.name" or key == "context_length":
                s += "  " + key + ": " + self.metadata[i].value_str + "\n"

        return s

# ─── GGUF Reader ───
struct GGUFReader:
    var file: GGUFFile
    var loaded: Bool

    fn __init__(out self):
        self.file = GGUFFile()
        self.loaded = False

    fn parse_header(self, data: List[Int]) -> Bool:
        """GGUF başlığını ayrıştır."""
        if len(data) < 12:
            return False

        # Magic number kontrolü (basit: ilk 4 byte)
        var magic = data[0] | (data[1] << 8) | (data[2] << 16) | (data[3] << 24)

        # Versiyon
        self.file.version = data[4] | (data[5] << 8) | (data[6] << 16) | (data[7] << 24)

        # Tensor sayısı
        self.file.n_tensors = data[8] | (data[9] << 8) | (data[10] << 16) | (data[11] << 24)

        self.loaded = True
        return True

    fn read_tensor_data(self, data: List[Int], offset: Int, size: Int) -> List[Int]:
        """Tensor verisini oku."""
        var result = List[Int]()
        for i in range(offset, min(offset + size, len(data))):
            result.append(data[i])
        return result^

    fn validate(self) -> Bool:
        """GGUF dosyasını doğrula."""
        if not self.loaded:
            return False
        if self.file.version < 1 or self.file.version > 3:
            return False
        return True

# ─── GGUF Writer ───
struct GGUFWriter:
    var metadata: List[GGUFMetadataEntry]
    var tensors: List[GGUFTensorInfo]

    fn __init__(out self):
        self.metadata = List[GGUFMetadataEntry]()
        self.tensors = List[GGUFTensorInfo]()

    fn add_metadata_string(mut self, key: String, value: String):
        """String metadata ekle."""
        var entry = GGUFMetadataEntry(key)
        entry.value_type = GGUFValueType.STRING
        entry.value_str = value
        self.metadata.append(entry^)

    fn add_metadata_int(mut self, key: String, value: Int):
        """Int metadata ekle."""
        var entry = GGUFMetadataEntry(key)
        entry.value_type = GGUFValueType.INT32
        entry.value_int = value
        self.metadata.append(entry^)

    fn add_metadata_float(mut self, key: String, value: Float32):
        """Float metadata ekle."""
        var entry = GGUFMetadataEntry(key)
        entry.value_type = GGUFValueType.FLOAT32
        entry.value_float = value
        self.metadata.append(entry^)

    fn add_tensor(mut self, name: String, shape: List[Int], dtype: Int, offset: Int):
        """Tensor ekle."""
        var info = GGUFTensorInfo(name)
        info.n_dims = len(shape)
        info.shape = shape.copy()
        info.dtype = dtype
        info.offset = offset
        self.tensors.append(info^)

    fn build_header(self) -> List[Int]:
        """GGUF başlık bayt dizisi oluştur."""
        var header = List[Int]()

        # Magic (4 byte)
        header.append(GGUF_MAGIC & 0xFF)
        header.append((GGUF_MAGIC >> 8) & 0xFF)
        header.append((GGUF_MAGIC >> 16) & 0xFF)
        header.append((GGUF_MAGIC >> 24) & 0xFF)

        # Version (4 byte)
        header.append(GGUF_VERSION & 0xFF)
        header.append((GGUF_VERSION >> 8) & 0xFF)
        header.append((GGUF_VERSION >> 16) & 0xFF)
        header.append((GGUF_VERSION >> 24) & 0xFF)

        # N tensors (4 byte)
        var n_tensors = len(self.tensors)
        header.append(n_tensors & 0xFF)
        header.append((n_tensors >> 8) & 0xFF)
        header.append((n_tensors >> 16) & 0xFF)
        header.append((n_tensors >> 24) & 0xFF)

        # N KV pairs (4 byte)
        var n_kv = len(self.metadata)
        header.append(n_kv & 0xFF)
        header.append((n_kv >> 8) & 0xFF)
        header.append((n_kv >> 16) & 0xFF)
        header.append((n_kv >> 24) & 0xFF)

        return header^

    fn estimate_size(self, param_count: Int) -> Int:
        """Tahmini dosya boyutu."""
        var header_size = 16 + len(self.metadata) * 64 + len(self.tensors) * 128
        var data_size = param_count * 4  # fp32 varsayalım
        return header_size + data_size
