import SwiftUI
import Foundation

@main
struct ConorApp: App {
    @StateObject private var store = ModelStore()
    var body: some Scene {
        WindowGroup {
            AppShell().environmentObject(store).preferredColorScheme(.dark)
                .frame(minWidth: 980, minHeight: 650)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1180, height: 760)
    }
}

enum ModelSkill: String, CaseIterable, Codable, Identifiable {
    case conversation = "Conversation", coding = "Code", image = "Image"
    case vision = "Vision", writing = "Writing", research = "Research"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .conversation: "bubble.left.and.bubble.right"
        case .coding: "chevron.left.forwardslash.chevron.right"
        case .image: "photo"
        case .vision: "eye"
        case .writing: "text.alignleft"
        case .research: "sparkle.magnifyingglass"
        }
    }
    var description: String {
        switch self {
        case .conversation: "Chat naturally and follow instructions"
        case .coding: "Write, explain, and debug code"
        case .image: "Generate images with a connected image engine"
        case .vision: "Understand images and visual inputs"
        case .writing: "Draft, rewrite, and summarize content"
        case .research: "Explore topics and synthesize information"
        }
    }
}

struct AIModel: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var baseModel: String
    var skills: [ModelSkill]
    var systemPrompt: String
    var epochs: Int
    var datasetPath: String?
    var createdAt: Date = Date()
    var status: String = "Draft"
}

@MainActor
final class ModelStore: ObservableObject {
    @Published var models: [AIModel] = [] { didSet { save() } }
    @Published var ollamaAvailable = false
    @Published var installedOllamaModels: [String] = []
    private var storageURL: URL {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Conor", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("models.json")
    }
    init() { load(); Task { await refreshOllama() } }
    func add(_ model: AIModel) { models.insert(model, at: 0) }
    func update(_ model: AIModel) {
        guard let index = models.firstIndex(where: { $0.id == model.id }) else { return }
        models[index] = model
    }
    func delete(_ model: AIModel) { models.removeAll { $0.id == model.id } }
    func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([AIModel].self, from: data) else { return }
        models = decoded
    }
    private func save() {
        guard let data = try? JSONEncoder().encode(models) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }
    func refreshOllama() async {
        guard let url = URL(string: "http://localhost:11434/api/tags") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
            installedOllamaModels = response.models.map(\.name).sorted()
            ollamaAvailable = true
        } catch {
            ollamaAvailable = false
            installedOllamaModels = []
        }
    }
}

struct OllamaTagsResponse: Decodable {
    struct Entry: Decodable { let name: String }
    let models: [Entry]
}
struct OllamaChatResponse: Decodable {
    struct Message: Decodable { let role: String; let content: String }
    let message: Message
}

@MainActor
final class ChatSession: ObservableObject {
    struct Message: Identifiable {
        let id = UUID()
        let role: String
        let content: String
    }
    @Published var messages: [Message] = []
    @Published var isSending = false
    @Published var error: String?
    func send(_ prompt: String, model: String, systemPrompt: String) async {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        messages.append(Message(role: "user", content: prompt))
        isSending = true
        error = nil
        defer { isSending = false }
        guard let url = URL(string: "http://localhost:11434/api/chat") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var conversation = messages.map { ["role": $0.role, "content": $0.content] }
        if !systemPrompt.isEmpty { conversation.insert(["role": "system", "content": systemPrompt], at: 0) }
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: ["model": model, "messages": conversation, "stream": false])
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw URLError(.badServerResponse)
            }
            let decoded = try JSONDecoder().decode(OllamaChatResponse.self, from: data)
            messages.append(Message(role: "assistant", content: decoded.message.content))
        } catch {
            self.error = "Couldn't reach Ollama. Check that Ollama is running and the selected model is installed."
        }
    }
}

struct AppShell: View {
    @EnvironmentObject private var store: ModelStore
    @State private var selection = "Overview"
    @State private var showingCreator = false
    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 9) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10).fill(Color.white)
                        Image(systemName: "circle.hexagongrid.fill").font(.system(size: 17, weight: .semibold)).foregroundStyle(.black)
                    }.frame(width: 34, height: 34)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("conor").font(.system(size: 18, weight: .bold, design: .rounded))
                        Text("AI MODEL STUDIO").font(.system(size: 8, weight: .semibold)).tracking(1.5).foregroundStyle(.secondary)
                    }
                }.padding(.horizontal, 12).padding(.top, 18).padding(.bottom, 22)
                sidebarItem("Overview", icon: "square.grid.2x2")
                sidebarItem("My Models", icon: "cube.transparent")
                sidebarItem("Playground", icon: "bubble.left.and.bubble.right")
                sidebarItem("Training", icon: "waveform.path.ecg")
                Spacer()
                HStack(spacing: 8) {
                    Circle().fill(store.ollamaAvailable ? .green : .gray).frame(width: 7, height: 7)
                    Text(store.ollamaAvailable ? "Ollama connected" : "Local engine offline").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                    Spacer()
                    Button { Task { await store.refreshOllama() } } label: { Image(systemName: "arrow.clockwise").font(.system(size: 11)) }.buttonStyle(.plain)
                }.padding(12)
            }
            .frame(minWidth: 205).background(Color(nsColor: .controlBackgroundColor))
            .navigationSplitViewColumnWidth(min: 205, ideal: 225, max: 250)
        } detail: {
            Group {
                switch selection {
                case "My Models": ModelsView(showingCreator: $showingCreator)
                case "Playground": PlaygroundView()
                case "Training": TrainingView()
                default: OverviewView(selection: $selection, showingCreator: $showingCreator)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(nsColor: .windowBackgroundColor))
        }
        .sheet(isPresented: $showingCreator) { CreateModelView() }
    }
    private func sidebarItem(_ title: String, icon: String) -> some View {
        Button { selection = title } label: {
            HStack(spacing: 11) {
                Image(systemName: icon).frame(width: 18)
                Text(title)
                Spacer()
                if title == "My Models" && !store.models.isEmpty {
                    Text("\(store.models.count)").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .font(.system(size: 13, weight: selection == title ? .semibold : .medium))
            .padding(.horizontal, 12).padding(.vertical, 9).contentShape(RoundedRectangle(cornerRadius: 8))
            .background(selection == title ? Color.primary.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain).padding(.horizontal, 8)
    }
}

struct PageHeader: View {
    let title: String
    let subtitle: String
    var trailing: AnyView? = nil
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 27, weight: .bold, design: .rounded))
                Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            if let trailing { trailing }
        }.padding(.bottom, 22)
    }
}

struct OverviewView: View {
    @EnvironmentObject private var store: ModelStore
    @Binding var selection: String
    @Binding var showingCreator: Bool
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(title: "Good to see you.", subtitle: "Your workspace for creating and shaping AI models.",
                    trailing: AnyView(Button { showingCreator = true } label: {
                        Label("Create model", systemImage: "plus").font(.system(size: 12, weight: .semibold))
                    }.buttonStyle(.borderedProminent).tint(.primary).foregroundStyle(.black)))
                HStack(spacing: 12) {
                    metricCard("Your models", value: "\(store.models.count)", note: "Created in this workspace", icon: "cube.transparent")
                    metricCard("Local engine", value: store.ollamaAvailable ? "Ready" : "Offline", note: store.ollamaAvailable ? "\(store.installedOllamaModels.count) models available" : "Connect Ollama to chat", icon: "cpu")
                    metricCard("Training jobs", value: "0", note: "No active jobs", icon: "waveform.path.ecg")
                }
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Your models").font(.system(size: 16, weight: .semibold))
                        Spacer()
                        Button("View all") { selection = "My Models" }.buttonStyle(.plain).font(.system(size: 11, weight: .medium))
                    }
                    if store.models.isEmpty {
                        EmptyState(icon: "cube.transparent", title: "Your model space is empty", message: "Create your first model to start shaping its skills and behavior.", action: "Create your first model") { showingCreator = true }
                    } else {
                        ForEach(store.models.prefix(4)) { model in ModelRow(model: model) }
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("A simple workflow").font(.system(size: 16, weight: .semibold))
                    HStack(spacing: 10) {
                        workflowStep("01", "Create", "Name your model and choose its capabilities.")
                        workflowStep("02", "Configure", "Choose a base model and behavior.")
                        workflowStep("03", "Train & test", "Prepare data, train adapters, and evaluate.")
                    }
                }
            }.padding(28).frame(maxWidth: 1050, alignment: .leading)
        }
    }
    private func metricCard(_ title: String, value: String, note: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Image(systemName: icon).foregroundStyle(.secondary); Spacer(); Text(title).font(.system(size: 11)).foregroundStyle(.secondary) }
            Text(value).font(.system(size: 24, weight: .bold, design: .rounded))
            Text(note).font(.system(size: 10)).foregroundStyle(.secondary)
        }.padding(15).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.07)))
    }
    private func workflowStep(_ number: String, _ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(number).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
            Text(title).font(.system(size: 13, weight: .semibold))
            Text(text).font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.padding(14).frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct ModelsView: View {
    @EnvironmentObject private var store: ModelStore
    @Binding var showingCreator: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(title: "My Models", subtitle: "All the models in your Conor workspace.",
                trailing: AnyView(Button { showingCreator = true } label: { Label("New model", systemImage: "plus") }.buttonStyle(.borderedProminent).tint(.primary).foregroundStyle(.black)))
            if store.models.isEmpty {
                EmptyState(icon: "cube.transparent", title: "Nothing here yet", message: "Your models will appear here after you create them.", action: "Create model") { showingCreator = true }
                Spacer()
            } else {
                ScrollView { LazyVStack(spacing: 9) { ForEach(store.models) { model in ModelRow(model: model) } } }
            }
        }.padding(28)
    }
}

struct ModelRow: View {
    @EnvironmentObject private var store: ModelStore
    let model: AIModel
    var body: some View {
        HStack(spacing: 13) {
            RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.08)).frame(width: 42, height: 42)
                .overlay(Image(systemName: "cube.transparent").font(.system(size: 17)))
            VStack(alignment: .leading, spacing: 4) {
                Text(model.name).font(.system(size: 13, weight: .semibold))
                Text(model.baseModel).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                HStack(spacing: 5) {
                    ForEach(model.skills) { skill in
                        Label(skill.rawValue, systemImage: skill.symbol).font(.system(size: 9))
                            .padding(.horizontal, 7).padding(.vertical, 4).background(Color.primary.opacity(0.06), in: Capsule())
                    }
                }
            }
            Spacer()
            Text(model.status).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
            Button(role: .destructive) { store.delete(model) } label: { Image(systemName: "trash").font(.system(size: 11)) }.buttonStyle(.plain)
        }.padding(13).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color.primary.opacity(0.06)))
    }
}

struct CreateModelView: View {
    @EnvironmentObject private var store: ModelStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var baseModel = "llama3.2"
    @State private var selectedSkills: Set<ModelSkill> = [.conversation]
    @State private var systemPrompt = "You are a helpful, thoughtful AI assistant."
    @State private var epochs = 3
    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Create a model").font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("Start with an identity, a base model, and a set of skills.").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark").foregroundStyle(.secondary) }.buttonStyle(.plain)
            }
            Divider()
            VStack(alignment: .leading, spacing: 6) { fieldLabel("MODEL NAME"); TextField("e.g. Conor Assistant", text: $name).textFieldStyle(.roundedBorder) }
            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("BASE MODEL")
                TextField("Ollama model tag, e.g. llama3.2", text: $baseModel).textFieldStyle(.roundedBorder)
                Text("This is the local model identifier used by the Ollama playground.").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 9) {
                fieldLabel("CAPABILITIES · SELECT MULTIPLE")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(ModelSkill.allCases) { skill in
                        let selected = selectedSkills.contains(skill)
                        Button {
                            if selected { selectedSkills.remove(skill) } else { selectedSkills.insert(skill) }
                        } label: {
                            HStack(spacing: 9) {
                                Image(systemName: skill.symbol).frame(width: 17)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(skill.rawValue).font(.system(size: 11, weight: .semibold))
                                    Text(skill.description).font(.system(size: 8)).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer(minLength: 0)
                                if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(.primary) }
                            }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
                                .background(selected ? Color.primary.opacity(0.1) : Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9))
                                .overlay(RoundedRectangle(cornerRadius: 9).stroke(selected ? Color.primary.opacity(0.35) : Color.primary.opacity(0.07)))
                        }.buttonStyle(.plain)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("SYSTEM INSTRUCTIONS")
                TextEditor(text: $systemPrompt).font(.system(size: 11)).frame(height: 65)
                    .padding(4).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
            }
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    fieldLabel("TRAINING EPOCHS")
                    Text("Can be changed later").font(.system(size: 9)).foregroundStyle(.secondary)
                }
                Spacer()
                Stepper("\(epochs)", value: $epochs, in: 1...100).frame(width: 110)
            }
            Text("Creating a workspace does not train model weights. Training requires a compatible local training backend and dataset.")
                .font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Create model") {
                    let model = AIModel(name: name.trimmingCharacters(in: .whitespacesAndNewlines), baseModel: baseModel.trimmingCharacters(in: .whitespacesAndNewlines), skills: Array(selectedSkills).sorted { $0.rawValue < $1.rawValue }, systemPrompt: systemPrompt, epochs: epochs)
                    store.add(model)
                    dismiss()
                }.buttonStyle(.borderedProminent).tint(.primary).foregroundStyle(.black)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || baseModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedSkills.isEmpty)
            }
        }.padding(22).frame(width: 570, height: 690)
    }
    private func fieldLabel(_ value: String) -> some View {
        Text(value).font(.system(size: 9, weight: .bold)).tracking(1.1).foregroundStyle(.secondary)
    }
}

struct PlaygroundView: View {
    @EnvironmentObject private var store: ModelStore
    @StateObject private var session = ChatSession()
    @State private var selectedModelID: UUID?
    @State private var selectedOllamaModel = ""
    @State private var input = ""
    private var selectedModel: AIModel? { store.models.first { $0.id == selectedModelID } }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PageHeader(title: "Playground", subtitle: "Try your model in a live local conversation.")
            HStack {
                Text("CONOR MODEL").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
                Picker("Conor model", selection: $selectedModelID) {
                    Text("Select a model").tag(Optional<UUID>.none)
                    ForEach(store.models) { model in Text(model.name).tag(Optional(model.id)) }
                }.frame(maxWidth: 180)
                Text("OLLAMA ENGINE").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
                Picker("Runtime model", selection: $selectedOllamaModel) {
                    Text("Choose runtime").tag("")
                    ForEach(store.installedOllamaModels, id: \.self) { Text($0).tag($0) }
                }.frame(maxWidth: 190)
                Spacer()
                Button { Task { await store.refreshOllama() } } label: { Image(systemName: "arrow.clockwise") }
            }.padding(10).background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
            if !store.ollamaAvailable {
                EmptyState(icon: "cpu", title: "Local runtime not found", message: "Install and launch Ollama, then refresh the connection. Conor sends chat requests to its local API at localhost:11434.", action: "Open Ollama website") {
                    NSWorkspace.shared.open(URL(string: "https://ollama.com")!)
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if session.messages.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "bubble.left.and.bubble.right").font(.system(size: 27)).foregroundStyle(.secondary)
                                Text("Start a conversation").font(.system(size: 16, weight: .semibold))
                                Text("Responses are generated locally by the selected Ollama model.").font(.system(size: 10)).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity).padding(.top, 65)
                        }
                        ForEach(session.messages) { message in
                            HStack {
                                if message.role == "assistant" { messageBubble(message.content, assistant: true); Spacer(minLength: 70) }
                                else { Spacer(minLength: 70); messageBubble(message.content, assistant: false) }
                            }
                        }
                        if let error = session.error { Text(error).font(.system(size: 11)).foregroundStyle(.red).padding(10) }
                    }.padding(.vertical, 12)
                }
                Spacer(minLength: 0)
                HStack(alignment: .bottom, spacing: 10) {
                    TextField("Message your model...", text: $input, axis: .vertical)
                        .textFieldStyle(.plain).lineLimit(1...5).padding(12)
                        .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
                        .onSubmit { send() }
                    Button { send() } label: {
                        Image(systemName: session.isSending ? "hourglass" : "arrow.up").font(.system(size: 13, weight: .bold)).foregroundStyle(.black)
                            .frame(width: 39, height: 39).background(Color.white, in: RoundedRectangle(cornerRadius: 10))
                    }.buttonStyle(.plain).disabled(session.isSending || selectedOllamaModel.isEmpty || input.isEmpty)
                }
            }
        }.padding(28)
            .onChange(of: store.installedOllamaModels) { _, models in if selectedOllamaModel.isEmpty { selectedOllamaModel = models.first ?? "" } }
            .onChange(of: store.models) { _, models in if selectedModelID == nil { selectedModelID = models.first?.id } }
    }
    private func send() {
        let prompt = input
        input = ""
        Task { await session.send(prompt, model: selectedOllamaModel, systemPrompt: selectedModel?.systemPrompt ?? "") }
    }
    private func messageBubble(_ text: String, assistant: Bool) -> some View {
        Text(text).font(.system(size: 12)).textSelection(.enabled).padding(12)
            .background(assistant ? Color.primary.opacity(0.055) : Color.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            .frame(maxWidth: 620, alignment: .leading)
    }
}

struct TrainingView: View {
    @EnvironmentObject private var store: ModelStore
    @State private var selectedID: UUID?
    @State private var datasetURL: URL?
    @State private var epochs = 3
    private var selectedModel: AIModel? { store.models.first { $0.id == selectedID } }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(title: "Training", subtitle: "Prepare datasets and configure a future fine-tuning run.")
            if store.models.isEmpty {
                EmptyState(icon: "waveform.path.ecg", title: "Create a model first", message: "Training configuration is attached to a model workspace.", action: "Go to My Models") {}
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("TRAINING CONFIGURATION").font(.system(size: 9, weight: .bold)).tracking(1.1).foregroundStyle(.secondary)
                    Picker("Model", selection: $selectedID) {
                        ForEach(store.models) { Text($0.name).tag(Optional($0.id)) }
                    }.onAppear { if selectedID == nil { selectedID = store.models.first?.id } }
                    .onChange(of: selectedID) { _, value in if let model = store.models.first(where: { $0.id == value }) { epochs = model.epochs } }
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Epochs").font(.system(size: 12, weight: .semibold))
                            Text("One epoch is one full pass through the training dataset.").font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Stepper("\(epochs)", value: $epochs, in: 1...100)
                    }.padding(13).background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TRAINING DATASET").font(.system(size: 9, weight: .bold)).tracking(1.1).foregroundStyle(.secondary)
                        HStack {
                            Image(systemName: "doc.text").foregroundStyle(.secondary)
                            Text(datasetURL?.lastPathComponent ?? "No dataset selected").font(.system(size: 11)).lineLimit(1)
                            Spacer()
                            Button("Choose file") { chooseDataset() }.buttonStyle(.bordered)
                        }.padding(12).background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
                    }
                    if let selectedModel {
                        Button("Save training settings") {
                            var updated = selectedModel
                            updated.epochs = epochs
                            updated.datasetPath = datasetURL?.path ?? updated.datasetPath
                            store.update(updated)
                        }.buttonStyle(.borderedProminent).tint(.primary).foregroundStyle(.black)
                    }
                }.padding(16).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 9) {
                    Label("Training engine not connected", systemImage: "info.circle").font(.system(size: 13, weight: .semibold))
                    Text("This build saves model settings and dataset selection, but it does not modify model weights or display simulated training progress. A real training backend (for example, MLX fine-tuning with LoRA on Apple Silicon) must be installed and integrated before a run can start.")
                        .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Text("Planned next: MLX-LM runner · live epoch and loss metrics · pause/cancel · checkpoint management.")
                        .font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                }.padding(16).background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
                Spacer()
            }
        }.padding(28)
    }
    private func chooseDataset() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json, .plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK { datasetURL = panel.url }
    }
}

struct EmptyState: View {
    let icon: String
    let title: String
    let message: String
    let action: String
    let onAction: () -> Void
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 28, weight: .light)).foregroundStyle(.secondary)
            Text(title).font(.system(size: 15, weight: .semibold))
            Text(message).font(.system(size: 11)).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 360)
            Button(action, action: onAction).buttonStyle(.bordered).tint(.primary).padding(.top, 5)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(24)
    }
}
