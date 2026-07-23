# mojo-llm/src/engine/api_server.mojo
# OpenAI-uyumlu API sunucusu.
# /v1/chat/completions, /v1/models, /v1/completions

from std.collections import List, Dict

# ─── API İsteği ───
struct ChatMessage:
    var role: String              # "system", "user", "assistant"
    var content: String

    fn __init__(out self, role: String, content: String):
        self.role = role
        self.content = content

struct ChatCompletionRequest:
    var model: String
    var messages: List[ChatMessage]
    var temperature: Float32
    var max_tokens: Int
    var top_p: Float32
    var stream: Bool

    fn __init__(out self):
        self.model = "mojo-llm"
        self.messages = List[ChatMessage]()
        self.temperature = 0.7
        self.max_tokens = 256
        self.top_p = 0.95
        self.stream = False

# ─── API Yanıtı ───
struct ChatCompletionResponse:
    var id: String
    var model: String
    var content: String
    var finish_reason: String     # "stop", "length"
    var prompt_tokens: Int
    var completion_tokens: Int
    var total_tokens: Int

    fn __init__(out self):
        self.id = "chatcmpl-mojo"
        self.model = "mojo-llm"
        self.content = ""
        self.finish_reason = "stop"
        self.prompt_tokens = 0
        self.completion_tokens = 0
        self.total_tokens = 0

    fn to_json(self) -> String:
        """JSON formatında yanıt oluştur."""
        var json = "{\n"
        json += '  "id": "' + self.id + '",\n'
        json += '  "object": "chat.completion",\n'
        json += '  "model": "' + self.model + '",\n'
        json += '  "choices": [{\n'
        json += '    "index": 0,\n'
        json += '    "message": {\n'
        json += '      "role": "assistant",\n'
        json += '      "content": "' + self._escape_json(self.content) + '"\n'
        json += "    },\n"
        json += '    "finish_reason": "' + self.finish_reason + '"\n'
        json += "  }],\n"
        json += '  "usage": {\n'
        json += '    "prompt_tokens": ' + String(self.prompt_tokens) + ",\n"
        json += '    "completion_tokens": ' + String(self.completion_tokens) + ",\n"
        json += '    "total_tokens": ' + String(self.total_tokens) + "\n"
        json += "  }\n"
        json += "}"
        return json

    fn _escape_json(self, s: String) -> String:
        """JSON string escaping."""
        var result = ""
        for i in range(len(s)):
            var c = s.unsafe_ptr()[i]
            if c == 34:  # "
                result += "\\\""
            elif c == 92:  # \
                result += "\\\\"
            elif c == 10:  # newline
                result += "\\n"
            elif c == 13:  # carriage return
                result += "\\r"
            elif c == 9:  # tab
                result += "\\t"
            else:
                result += String(c)
        return result

# ─── Model Bilgisi ───
struct ModelInfo:
    var id: String
    var owned_by: String
    var created: Int

    fn __init__(out self, id: String):
        self.id = id
        self.owned_by = "mojo-llm"
        self.created = 0

    fn to_json(self) -> String:
        var json = "{\n"
        json += '  "id": "' + self.id + '",\n'
        json += '  "object": "model",\n'
        json += '  "owned_by": "' + self.owned_by + '",\n'
        json += '  "created": ' + String(self.created) + "\n"
        json += "}"
        return json

# ─── API Sunucusu ───
struct APIServer:
    var models: List[ModelInfo]
    var request_count: Int
    var total_tokens: Int

    fn __init__(out self):
        self.models = List[ModelInfo]()
        self.request_count = 0
        self.total_tokens = 0

        # Varsayılan modelleri ekle
        self.models.append(ModelInfo("mojo-tiny")^)
        self.models.append(ModelInfo("mojo-small")^)
        self.models.append(ModelInfo("mojo-medium")^)
        self.models.append(ModelInfo("mojo-large")^)

    fn handle_chat_completion(self, request: ChatCompletionRequest) -> ChatCompletionResponse:
        """Chat completion isteğini işle."""
        self.request_count += 1

        var response = ChatCompletionResponse()
        response.model = request.model
        response.prompt_tokens = self._estimate_tokens(request)
        response.completion_tokens = 0  # Model tarafından doldurulacak
        response.total_tokens = response.prompt_tokens

        # Gerçek inference model tarafından yapılacak
        response.content = "API response for: " + request.model
        response.id = "chatcmpl-" + String(self.request_count)

        self.total_tokens += response.total_tokens
        return response^

    fn list_models(self) -> String:
        """Mevcut modelleri listele."""
        var json = "{\n"
        json += '  "object": "list",\n'
        json += '  "data": [\n'
        for i in range(len(self.models)):
            json += "    " + self.models[i].to_json()
            if i < len(self.models) - 1:
                json += ","
            json += "\n"
        json += "  ]\n"
        json += "}"
        return json

    fn health_check(self) -> String:
        """Sağlık kontrolü."""
        var json = "{\n"
        json += '  "status": "ok",\n'
        json += '  "model_count": ' + String(len(self.models)) + ",\n"
        json += '  "request_count": ' + String(self.request_count) + ",\n"
        json += '  "total_tokens": ' + String(self.total_tokens) + "\n"
        json += "}"
        return json

    fn _estimate_tokens(self, request: ChatCompletionRequest) -> Int:
        """Token sayısını tahmin et."""
        var total_chars = 0
        for msg in request.messages:
            total_chars += len(msg.content)
        # Basit tahmin: ~4 karakter = 1 token
        return total_chars // 4 + 10

    fn stats(self) -> String:
        """İstatistikler."""
        var s = "API Sunucusu:\n"
        s += "  Model: " + String(len(self.models)) + "\n"
        s += "  İstek: " + String(self.request_count) + "\n"
        s += "  Toplam token: " + String(self.total_tokens)
        return s
