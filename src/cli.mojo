# mojo-llm/src/cli.mojo
# mojo-llm CLI — Tüm modüllere erişim.
# learn, verify, recall, agent, serve, gguf, flash-info ...

from std.collections import List, Dict
from std.sys import argv

struct Command:
    var name: String
    var description: String
    var usage: String

    fn __init__(out self, name: String, description: String, usage: String = ""):
        self.name = name
        self.description = description
        self.usage = usage

struct CLI:
    var commands: List[Command]
    var version: String

    fn __init__(out self):
        self.commands = List[Command]()
        self.version = "0.4.0"
        self._register()

    fn _register(mut self):
        self.commands.append(Command("help", "Yardim goster"))
        self.commands.append(Command("version", "Surum bilgisi"))
        self.commands.append(Command("info", "Model bilgisi", "info [tiny|small|medium|large]"))
        self.commands.append(Command("infer", "Tahmin yap", "infer --model tiny --prompt 'text'"))
        self.commands.append(Command("benchmark", "Performans testi", "benchmark --model tiny"))
        self.commands.append(Command("learn", "Tecrube ekle", "learn --input 'soru' --output 'cevap' --score 0.8"))
        self.commands.append(Command("recall", "Tecrube hatirla", "recall --query 'sorgu'"))
        self.commands.append(Command("stats", "Ogrenme istatistikleri"))
        self.commands.append(Command("verify", "Ciktisini dogrula", "verify --prompt 'soru' --response 'cevap'"))
        self.commands.append(Command("memory", "Bellek islemleri", "memory [remember|recall|stats]"))
        self.commands.append(Command("remember", "Bellige kaydet", "remember --key 'anahtar' --content 'icerik'"))
        self.commands.append(Command("agent", "Ajan baslat", "agent --task 'gorev'"))
        self.commands.append(Command("serve", "API sunucusu baslat", "serve --port 8080"))
        self.commands.append(Command("save", "Modeli kaydet", "save --model tiny --output model.bin"))
        self.commands.append(Command("load", "Model yukle", "load --input model.bin"))
        self.commands.append(Command("gguf-info", "GGUF dosyasi bilgisi", "gguf-info --file model.gguf"))
        self.commands.append(Command("flash-info", "Flash Attention bilgisi", "flash-info --seq-len 2048"))

    fn print_help(self):
        print("\n===========================================================")
        print("  mojo-llm v" + self.version + " — Agentic Ogrenen Sistem")
        print("===========================================================\n")
        print("Kullanim: mojo run src/cli.mojo <komut> [secenekler]\n")
        print("Komutlar:")
        for cmd in self.commands:
            var padded = cmd.name
            for i in range(len(cmd.name), 18):
                padded += " "
            print("  " + padded + cmd.description)

    fn print_version(self):
        print("mojo-llm v" + self.version)
        print("Moduller: transformer, bpe, inference, verification, experience,")
        print("          memory, agent, self_learning, tool_use, multi_agent,")
        print("          web_browser, api_server, save_load, gguf, flash_attention")
