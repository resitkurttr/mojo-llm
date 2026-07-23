# mojo-llm/src/config.mojo
# Sistem konfigürasyonu.
# Tüm ayarlar tek yerden yönetilir.

struct SystemConfig:
    # Model
    var model_size: String        # tiny, small, medium, large
    var max_seq_len: Int
    var temperature: Float32
    var top_k: Int
    var top_p: Float32

    # Öğrenme
    var learning_rate: Float32
    var max_experiences: Int
    var compression_threshold: Float32
    var verification_threshold: Float32

    # Bellek
    var working_memory_size: Int
    var episodic_memory_size: Int
    var semantic_memory_enabled: Bool

    # Ajan
    var max_iterations: Int
    var max_concurrent_tasks: Int
    var auto_verify: Bool

    # API
    var api_host: String
    var api_port: Int

    # Web
    var web_user_agent: String
    var web_timeout_ms: Int

    # Kaydetme
    var auto_save: Bool
    var save_interval: Int        # Her N etkileşimde bir

    # Logging
    var log_level: String         # debug, info, warn, error
    var log_file: String

    fn __init__(out self):
        self.model_size = "tiny"
        self.max_seq_len = 512
        self.temperature = 0.7
        self.top_k = 50
        self.top_p = 0.95

        self.learning_rate = 0.01
        self.max_experiences = 10000
        self.compression_threshold = 0.7
        self.verification_threshold = 0.6

        self.working_memory_size = 20
        self.episodic_memory_size = 500
        self.semantic_memory_enabled = True

        self.max_iterations = 50
        self.max_concurrent_tasks = 3
        self.auto_verify = True

        self.api_host = "0.0.0.0"
        self.api_port = 8080

        self.web_user_agent = "mojo-llm/0.4.0"
        self.web_timeout_ms = 30000

        self.auto_save = True
        self.save_interval = 10

        self.log_level = "info"
        self.log_file = "mojo-llm.log"

    @staticmethod
    fn mobile() -> SystemConfig:
        """Mobil cihaz için optimize edilmiş konfigürasyon."""
        var cfg = SystemConfig()
        cfg.model_size = "tiny"
        cfg.max_seq_len = 256
        cfg.working_memory_size = 10
        cfg.episodic_memory_size = 100
        cfg.max_iterations = 20
        cfg.auto_save = True
        cfg.save_interval = 5
        return cfg^

    @staticmethod
    fn server() -> SystemConfig:
        """Sunucu için optimize edilmiş konfigürasyon."""
        var cfg = SystemConfig()
        cfg.model_size = "medium"
        cfg.max_seq_len = 4096
        cfg.working_memory_size = 50
        cfg.episodic_memory_size = 2000
        cfg.max_concurrent_tasks = 10
        cfg.api_port = 8080
        return cfg^

    @staticmethod
    fn research() -> SystemConfig:
        """Araştırma/keşif için konfigürasyon."""
        var cfg = SystemConfig()
        cfg.model_size = "large"
        cfg.max_seq_len = 2048
        cfg.learning_rate = 0.005
        cfg.compression_threshold = 0.8
        cfg.verification_threshold = 0.7
        cfg.auto_verify = True
        return cfg^

    fn to_json(self) -> String:
        """JSON formatında konfigürasyon."""
        var j = "{\n"
        j += '  "model_size": "' + self.model_size + '",\n'
        j += '  "max_seq_len": ' + String(self.max_seq_len) + ",\n"
        j += '  "temperature": ' + String(Int(self.temperature * 100)) + ",\n"
        j += '  "learning_rate": ' + String(Int(self.learning_rate * 1000)) + ",\n'
        j += '  "max_experiences": ' + String(self.max_experiences) + ",\n"
        j += '  "working_memory_size": ' + String(self.working_memory_size) + ",\n'
        j += '  "episodic_memory_size": ' + String(self.episodic_memory_size) + ",\n"
        j += '  "api_port": ' + String(self.api_port) + ",\n"
        j += '  "log_level": "' + self.log_level + '"\n'
        j += "}"
        return j
