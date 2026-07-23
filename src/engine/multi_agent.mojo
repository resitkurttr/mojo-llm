# mojo-llm/src/engine/multi_agent.mojo
# Çoklu ajan sistemi — Orchestrator/Worker pattern.
# Görev dağıtma, koordinasyon, sonuç birleştirme.

from std.collections import List, Dict

# ─── Ajan Rolü ───
enum AgentRole:
    ORCHESTRATOR
    CODER
    RESEARCHER
    CRITIC
    WRITER
    WORKER

# ─── Ajan Yapılandırması ───
struct AgentConfig:
    var role: AgentRole
    var name: String
    var description: String
    var max_iterations: Int
    var temperature: Float32

    fn __init__(out self, role: AgentRole, name: String, description: String):
        self.role = role
        self.name = name
        self.description = description
        self.max_iterations = 20
        self.temperature = 0.7

# ─── Görev ───
struct WorkerTask:
    var id: Int
    var description: String
    var assigned_to: String
    var status: String            # "pending", "running", "done", "failed"
    var result: String
    var score: Float32

    fn __init__(out self, id: Int, description: String):
        self.id = id
        self.description = description
        self.assigned_to = ""
        self.status = "pending"
        self.result = ""
        self.score = 0.0

# ─── Ajan ───
struct WorkerAgent:
    var config: AgentConfig
    var completed_tasks: Int
    var total_score: Float32

    fn __init__(out self, config: AgentConfig):
        self.config = config
        self.completed_tasks = 0
        self.total_score = 0.0

    fn execute(self, task: WorkerTask) -> String:
        """Görevi yürüt."""
        self.completed_tasks += 1
        # Gerçek yürütme model tarafından yapılacak
        return "Worker " + self.config.name + " executed: " + task.description

# ─── Task Delegator ───
struct TaskDelegator:
    var workers: List[WorkerAgent]
    var tasks: List[WorkerTask]
    var results: List[String]
    var next_task_id: Int

    fn __init__(out self):
        self.workers = List[WorkerAgent]()
        self.tasks = List[WorkerTask]()
        self.results = List[String]()
        self.next_task_id = 1

    fn add_worker(mut self, worker: WorkerAgent):
        """Worker ekle."""
        self.workers.append(worker^)

    fn create_task(mut self, description: String) -> Int:
        """Yeni görev oluştur."""
        var task = WorkerTask(self.next_task_id, description)
        var id = self.next_task_id
        self.tasks.append(task^)
        self.next_task_id += 1
        return id

    fn assign_tasks(mut self):
        """Görevleri worker'lara dağıt."""
        var pending = List[Int]()
        for i in range(len(self.tasks)):
            if self.tasks[i].status == "pending":
                pending.append(i)

        if len(pending) == 0 or len(self.workers) == 0:
            return

        # Round-robin dağıtma
        for i in range(len(pending)):
            var worker_idx = i % len(self.workers)
            self.tasks[pending[i]].assigned_to = self.workers[worker_idx].config.name
            self.tasks[pending[i]].status = "running"

    fn execute_all(mut self) -> List[String]:
        """Tüm görevleri çalıştır."""
        var results = List[String]()
        for i in range(len(self.tasks)):
            if self.tasks[i].status == "running":
                # Uygun worker'ı bul
                for j in range(len(self.workers)):
                    if self.workers[j].config.name == self.tasks[i].assigned_to:
                        var result = self.workers[j].execute(self.tasks[i])
                        self.tasks[i].result = result
                        self.tasks[i].status = "done"
                        self.tasks[i].score = 0.8  # Varsayılan skor
                        results.append(result^)
                        break
        return results^

    fn get_best_result(self) -> String:
        """En iyi sonucu getir."""
        var best_score: Float32 = -1.0
        var best_result = ""
        for i in range(len(self.tasks)):
            if self.tasks[i].status == "done" and self.tasks[i].score > best_score:
                best_score = self.tasks[i].score
                best_result = self.tasks[i].result
        return best_result

    fn stats(self) -> String:
        """İstatistikler."""
        var s = "Çoklu Ajan Sistemi:\n"
        s += "  Worker: " + String(len(self.workers)) + "\n"
        s += "  Görev: " + String(len(self.tasks)) + "\n"

        var pending = 0
        var running = 0
        var done = 0
        var failed = 0
        for t in self.tasks:
            if t.status == "pending":
                pending += 1
            elif t.status == "running":
                running += 1
            elif t.status == "done":
                done += 1
            elif t.status == "failed":
                failed += 1

        s += "  Bekleyen: " + String(pending) + "\n"
        s += "  Devam eden: " + String(running) + "\n"
        s += "  Tamamlanan: " + String(done) + "\n"
        s += "  Başarısız: " + String(failed)
        return s

# ─── Varsayılan Ajanlar ───
fn create_default_agents() -> List[WorkerAgent]:
    """Varsayılan ajan seti oluştur."""
    var agents = List[WorkerAgent]()

    var orchestrator_config = AgentConfig(AgentRole.ORCHESTRATOR, "Orchestrator", "Görevleri planla ve koordine et")
    agents.append(WorkerAgent(orchestrator_config)^)

    var coder_config = AgentConfig(AgentRole.CODER, "Coder", "Kod yaz ve test et")
    agents.append(WorkerAgent(coder_config)^)

    var researcher_config = AgentConfig(AgentRole.RESEARCHER, "Researcher", "Araştırma yap ve analiz et")
    agents.append(WorkerAgent(researcher_config)^)

    var critic_config = AgentConfig(AgentRole.CRITIC, "Critic", "Sonuçları değerlendir")
    agents.append(WorkerAgent(critic_config)^)

    return agents^
