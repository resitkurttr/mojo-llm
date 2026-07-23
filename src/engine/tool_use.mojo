# mojo-llm/src/engine/tool_use.mojo
# Tool registry ve execution sistemi.
# Araç tanımlama, kaydetme, çalıştırma.

from std.collections import List, Dict

# ─── Tool Parametresi ───
struct ToolParam:
    var name: String
    var param_type: String       # "string", "int", "float", "bool"
    var description: String
    var required: Bool
    var default_value: String

    fn __init__(out self, name: String, param_type: String, description: String, required: Bool = True, default_value: String = ""):
        self.name = name
        self.param_type = param_type
        self.description = description
        self.required = required
        self.default_value = default_value

# ─── Tool Tanımı ───
struct ToolDef:
    var name: String
    var description: String
    var category: String          # "file", "web", "code", "data"
    var params: List[ToolParam]
    var examples: List[String]

    fn __init__(out self, name: String, description: String, category: String):
        self.name = name
        self.description = description
        self.category = category
        self.params = List[ToolParam]()
        self.examples = List[String]()

    fn add_param(mut self, name: String, param_type: String, description: String, required: Bool = True, default_value: String = ""):
        """Parametre ekle."""
        self.params.append(ToolParam(name, param_type, description, required, default_value))

    fn to_openai_schema(self) -> String:
        """OpenAI function calling formatında schema döndür."""
        var schema = "{\n"
        schema += '  "name": "' + self.name + '",\n'
        schema += '  "description": "' + self.description + '",\n'
        schema += '  "parameters": {\n'
        schema += '    "type": "object",\n'
        schema += '    "properties": {\n'

        for i in range(len(self.params)):
            schema += '      "' + self.params[i].name + '": {\n'
            schema += '        "type": "' + self.params[i].param_type + '",\n'
            schema += '        "description": "' + self.params[i].description + '"\n'
            schema += "      }"
            if i < len(self.params) - 1:
                schema += ","
            schema += "\n"

        schema += "    },\n"
        schema += '    "required": ['
        var first = True
        for p in self.params:
            if p.required:
                if not first:
                    schema += ", "
                schema += '"' + p.name + '"'
                first = False
        schema += "]\n"
        schema += "  }\n"
        schema += "}"
        return schema

# ─── Tool Çalıştırma Sonucu ───
struct ToolResult:
    var tool_name: String
    var output: String
    var success: Bool
    var error: String
    var execution_time_ms: Float32

    fn __init__(out self, tool_name: String, output: String, success: Bool):
        self.tool_name = tool_name
        self.output = output
        self.success = success
        self.error = ""
        self.execution_time_ms = 0.0

# ─── Tool Registry ───
struct ToolRegistry:
    var tools: Dict[String, ToolDef]
    var categories: Dict[String, List[String]]
    var execution_count: Dict[String, Int]

    fn __init__(out self):
        self.tools = Dict[String, ToolDef]()
        self.categories = Dict[String, List[String]]()
        self.execution_count = Dict[String, Int]()

    fn register(mut self, tool: ToolDef):
        """Tool kaydet."""
        self.tools[tool.name] = tool^
        self.execution_count[tool.name] = 0

        # Kategorilere ekle
        if tool.category in self.categories:
            self.categories[tool.category].append(tool.name)
        else:
            self.categories[tool.category] = List[String]()
            self.categories[tool.category].append(tool.name)

    fn get_tool(self, name: String) -> ToolDef:
        """Tool getir."""
        if name in self.tools:
            return self.tools[name]
        return ToolDef("", "", "")

    def list_tools(self) -> List[ToolDef]:
        """Tüm tool'ları listele."""
        var result = List[ToolDef]()
        for name in self.tools:
            result.append(self.tools[name])
        return result^

    fn list_by_category(self, category: String) -> List[ToolDef]:
        """Kategorideki tool'ları listele."""
        var result = List[ToolDef]()
        if category in self.categories:
            for name in self.categories[category]:
                if name in self.tools:
                    result.append(self.tools[name])
        return result^

    fn tool_exists(self, name: String) -> Bool:
        """Tool var mı?"""
        return name in self.tools

    fn record_execution(mut self, name: String):
        """Çalıştırma kaydı tut."""
        if name in self.execution_count:
            self.execution_count[name] += 1

    fn stats(self) -> String:
        """İstatistikler."""
        var s = "Tool Registry:\n"
        s += "  Toplam tool: " + String(len(self.tools)) + "\n"
        s += "  Kategoriler: " + String(len(self.categories)) + "\n"
        for name in self.tools:
            var count = 0
            if name in self.execution_count:
                count = self.execution_count[name]
            s += "    " + name + ": " + String(count) + " çalıştırma\n"
        return s

# ─── Tool Executor ───
struct ToolExecutor:
    var registry: ToolRegistry

    fn __init__(out self, registry: ToolRegistry):
        self.registry = registry

    fn execute(self, tool_name: String, args: String) -> ToolResult:
        """Tool çalıştır."""
        if not self.registry.tool_exists(tool_name):
            var r = ToolResult(tool_name, "", False)
            r.error = "Tool bulunamadı: " + tool_name
            return r^

        self.registry.record_execution(tool_name)

        # Gerçek yürütme — model tarafından yapılacak
        # Bu sadece iskelet
        var r = ToolResult(tool_name, "Tool executed: " + tool_name + " with args: " + args, True)
        return r^

    fn execute_batch(self, calls: List[String]) -> List[ToolResult]:
        """Toplu çalıştırma."""
        var results = List[ToolResult]()
        for call in calls:
            # Basit parse: "tool_name:args"
            var colon_idx = -1
            for i in range(len(call)):
                if call.unsafe_ptr()[i] == 58:  # ':'
                    colon_idx = i
                    break

            if colon_idx > 0:
                var tool_name = _substring(call, 0, colon_idx)
                var args = _substring(call, colon_idx + 1, len(call))
                results.append(self.execute(tool_name, args)^)
            else:
                results.append(self.execute(call, "")^)

        return results^

# ─── Varsayılan Tool'lar ───
fn create_default_tools() -> ToolRegistry:
    """Varsayılan tool seti oluştur."""
    var registry = ToolRegistry()

    # Dosya oku
    var read_file = ToolDef("read_file", "Bir dosyanın içeriğini oku", "file")
    read_file.add_param("path", "string", "Dosya yolu")
    registry.register(read_file^)

    # Dosya yaz
    var write_file = ToolDef("write_file", "Bir dosyaya yaz", "file")
    write_file.add_param("path", "string", "Dosya yolu")
    write_file.add_param("content", "string", "Yazılacak içerik")
    registry.register(write_file^)

    # Dosya listele
    var list_files = ToolDef("list_files", "Dizindeki dosyaları listele", "file")
    list_files.add_param("path", "string", "Dizin yolu", False, ".")
    registry.register(list_files^)

    # Dosya ara
    var search_files = ToolDef("search_files", "Dosya adında ara", "file")
    search_files.add_param("pattern", "string", "Arama deseni")
    registry.register(search_files^)

    # İçerik ara
    var grep = ToolDef("grep", "Dosya içeriğinde ara", "file")
    grep.add_param("pattern", "string", "Regex deseni")
    grep.add_param("path", "string", "Aranacak dosya/dizin")
    registry.register(grep^)

    # Web ara
    var web_search = ToolDef("web_search", "İnternette ara", "web")
    web_search.add_param("query", "string", "Arama sorgusu")
    registry.register(web_search^)

    # Web sayfası oku
    var web_fetch = ToolDef("web_fetch", "Bir web sayfasının içeriğini oku", "web")
    web_fetch.add_param("url", "string", "Sayfa URL'i")
    registry.register(web_fetch^)

    # Kod çalıştır
    var run_code = ToolDef("run_code", "Python kodu çalıştır", "code")
    run_code.add_param("code", "string", "Çalıştırılacak kod")
    registry.register(run_code^)

    # Shell komutu
    var run_shell = ToolDef("run_shell", "Shell komutu çalıştır", "code")
    run_shell.add_param("command", "string", "Shell komutu")
    registry.register(run_shell^)

    # JSON ayrıştır
    var json_parse = ToolDef("json_parse", "JSON metni ayrıştır", "data")
    json_parse.add_param("text", "string", "JSON metni")
    registry.register(json_parse^)

    # CSV oku
    var csv_read = ToolDef("csv_read", "CSV dosyası oku", "data")
    csv_read.add_param("path", "string", "CSV dosya yolu")
    registry.register(csv_read^)

    return registry^

fn _substring(s: String, start: Int, end: Int) -> String:
    """String'den alt dizeyi çıkar."""
    var result = ""
    for i in range(start, min(end, len(s))):
        result += String(s.unsafe_ptr()[i])
    return result

fn min(a: Int, b: Int) -> Int:
    if a < b:
        return a
    return b
