import SwiftUI
import Foundation
import AppKit
import UniformTypeIdentifiers
import Sparkle

@main
struct ConorApp: App {
    @StateObject private var store = ModelStore()
    private let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    var body: some Scene {
        WindowGroup {
            AppShell(onCheckForUpdates: { updaterController.checkForUpdates(nil) }).environmentObject(store).preferredColorScheme(.dark)
                .frame(minWidth: 980, minHeight: 650)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1180, height: 760)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") { updaterController.checkForUpdates(nil) }
            }
        }
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
    let onCheckForUpdates: () -> Void
    @EnvironmentObject private var store: ModelStore
    @State private var selection = "Overview"
    @State private var showingCreator = false
    private let tabs: [(String, String)] = [
        ("Overview", "square.grid.2x2"),
        ("Models", "cube.transparent"),
        ("Training", "waveform.path.ecg"),
        ("Playground", "bubble.left.and.bubble.right"),
        ("Settings", "gearshape")
    ]
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9).fill(Color.white)
                    Image(systemName: "circle.hexagongrid.fill").font(.system(size: 16, weight: .semibold)).foregroundStyle(.black)
                }.frame(width: 30, height: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text("conor").font(.system(size: 17, weight: .bold, design: .rounded))
                    Text("AI MODEL STUDIO").font(.system(size: 8, weight: .semibold)).tracking(1.4).foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 7) {
                    Circle().fill(store.ollamaAvailable ? .green : .gray).frame(width: 7, height: 7)
                    Text(store.ollamaAvailable ? "Ollama connected" : "Ollama offline")
                        .font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                }
                Button { Task { await store.refreshOllama() } } label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 11))
                }.buttonStyle(.plain).help("Refresh local runtime")
            }
            .padding(.horizontal, 24).padding(.vertical, 13)
            Divider().opacity(0.5)
            Group {
                switch selection {
                case "Models": ModelsView(showingCreator: $showingCreator)
                case "Training": TrainingView()
                case "Playground": PlaygroundView()
                case "Settings": SettingsView(onCheckForUpdates: onCheckForUpdates)
                default: OverviewView(selection: $selection, showingCreator: $showingCreator)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
            Divider().opacity(0.6)
            HStack(spacing: 8) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { item in
                    let tab = item.element
                    Button { selection = tab.0 } label: {
                        VStack(spacing: 5) {
                            Image(systemName: tab.1).font(.system(size: 15, weight: selection == tab.0 ? .semibold : .regular))
                            Text(tab.0).font(.system(size: 10, weight: selection == tab.0 ? .semibold : .medium))
                        }
                        .foregroundStyle(selection == tab.0 ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(selection == tab.0 ? Color.primary.opacity(0.075) : .clear, in: RoundedRectangle(cornerRadius: 9))
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 7)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .sheet(isPresented: $showingCreator) { CreateModelView() }
    }
}

struct SettingsView: View {
    let onCheckForUpdates: () -> Void
    private var updatesConfigured: Bool {
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
        return key.count >= 40
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(title: "Settings", subtitle: "Manage local runtimes, training tools, and application updates.")
            VStack(alignment: .leading, spacing: 8) {
                Label("Training runtime", systemImage: "cpu").font(.system(size: 14, weight: .semibold))
                Text("Conor uses MLX-LM for local LoRA fine-tuning on Apple Silicon. Install the engine from the Training tab to run jobs on your Mac.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 8) {
                Label("Automatic application updates", systemImage: "arrow.down.circle").font(.system(size: 14, weight: .semibold))
                Text(updatesConfigured
                     ? "Sparkle is configured. Conor checks the signed release feed automatically and can install updates without a manual GitHub download."
                     : "Sparkle is integrated, but secure updates are waiting for the public signing key to be configured in the build. The private signing key must stay in GitHub Actions secrets.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                HStack {
                    Button("Check for Updates…", action: onCheckForUpdates).buttonStyle(.borderedProminent).tint(.primary).foregroundStyle(.black)
                    if !updatesConfigured {
                        Text("Signing setup required").font(.system(size: 10, weight: .medium)).foregroundStyle(.orange)
                    }
                }
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
            Spacer()
        }.padding(28)
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
    @State private var baseModel = "mlx-community/Qwen2.5-0.5B-Instruct-4bit"
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
            .onChange(of: store.installedOllamaModels) { models in if selectedOllamaModel.isEmpty { selectedOllamaModel = models.first ?? "" } }
            .onChange(of: store.models) { models in if selectedModelID == nil { selectedModelID = models.first?.id } }
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
    @State private var epochs = 100
    @State private var batchSize = 1
    @State private var learningRate = "0.0001"
    @State private var adapterPath = ""
    @State private var isInstalling = false
    @State private var isTraining = false
    @State private var logs = "Choose a dataset folder containing train.jsonl to begin."
    @State private var process: Process?
    @State private var installProcess: Process?
    @State private var exitCode: Int32?
    private var selectedModel: AIModel? { store.models.first { $0.id == selectedID } }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(title: "Training", subtitle: "Fine-tune real model weights locally with MLX-LM and LoRA.")
            if store.models.isEmpty {
                EmptyState(icon: "waveform.path.ecg", title: "Create a model first", message: "Create a workspace and set its base model to a compatible MLX or Hugging Face model.", action: "Create a model") {}
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("TRAINING SETUP").font(.system(size: 9, weight: .bold)).tracking(1.1).foregroundStyle(.secondary)
                            Picker("Model workspace", selection: $selectedID) {
                                Text("Select model").tag(Optional<UUID>.none)
                                ForEach(store.models) { Text($0.name).tag(Optional($0.id)) }
                            }
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Base model").font(.system(size: 11, weight: .semibold))
                                TextField("mlx-community/Qwen2.5-0.5B-Instruct-4bit", text: baseModelBinding)
                                    .textFieldStyle(.roundedBorder)
                                Text("Use a compatible MLX model repository or a local MLX model directory. A small 0.5B quantized model is a sensible starting point on an 8 GB Mac.")
                                    .font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Dataset folder").font(.system(size: 11, weight: .semibold))
                                    Text(datasetURL?.path ?? "Expected: train.jsonl, optional valid.jsonl")
                                        .font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary).lineLimit(2)
                                }
                                Spacer()
                                Button("Choose folder") { chooseDataset() }.buttonStyle(.bordered)
                            }.padding(11).background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 9))
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Iterations").font(.system(size: 10, weight: .semibold))
                                    Stepper("\(epochs)", value: $epochs, in: 1...10000, step: 10).frame(width: 145)
                                }
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Batch size").font(.system(size: 10, weight: .semibold))
                                    Stepper("\(batchSize)", value: $batchSize, in: 1...8).frame(width: 120)
                                }
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Learning rate").font(.system(size: 10, weight: .semibold))
                                    TextField("0.0001", text: $learningRate).textFieldStyle(.roundedBorder).frame(width: 110)
                                }
                            }
                            HStack(spacing: 8) {
                                Button { installMLX() } label: {
                                    if isInstalling { ProgressView().controlSize(.small); Text("Installing MLX-LM…") }
                                    else { Label("Install training engine", systemImage: "shippingbox") }
                                }.buttonStyle(.bordered).disabled(isInstalling || isTraining)
                                Spacer()
                                Button { startTraining() } label: {
                                    Label(isTraining ? "Training…" : "Start real training", systemImage: isTraining ? "waveform" : "play.fill")
                                }.buttonStyle(.borderedProminent).tint(.primary).foregroundStyle(.black)
                                    .disabled(isTraining || isInstalling || datasetURL == nil || selectedModel == nil)
                                if isTraining {
                                    Button("Stop", role: .destructive) { stopTraining() }.buttonStyle(.bordered)
                                }
                            }
                        }.padding(16).background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 13))
                        VStack(alignment: .leading, spacing: 9) {
                            HStack {
                                Label("Live training output", systemImage: "terminal").font(.system(size: 13, weight: .semibold))
                                Spacer()
                                if isTraining { Text("RUNNING").font(.system(size: 9, weight: .bold)).foregroundStyle(.green) }
                                else if let exitCode { Text(exitCode == 0 ? "COMPLETED" : "EXIT \(exitCode)").font(.system(size: 9, weight: .bold)).foregroundStyle(exitCode == 0 ? .green : .red) }
                            }
                            ScrollView {
                                Text(logs).font(.system(size: 10, design: .monospaced)).textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                            }.frame(minHeight: 190, maxHeight: 300).background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                        }.padding(15).background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
                        Text("MLX-LM performs actual LoRA/QLoRA fine-tuning and writes adapter checkpoints to disk. Training runs locally and may use substantial unified memory. Keep the Mac plugged in and start with a small quantized model, batch size 1, and a small dataset.")
                            .font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }.padding(28)
        .onAppear { if selectedID == nil { selectedID = store.models.first?.id } }
        .onChange(of: selectedID) { newID in
            if let model = store.models.first(where: { $0.id == newID }) { epochs = max(10, model.epochs * 10) }
        }
        .onDisappear { if isTraining { stopTraining() } }
    }
    private var baseModelBinding: Binding<String> {
        Binding(get: { selectedModel?.baseModel ?? "" }, set: { value in
            guard var model = selectedModel else { return }; model.baseModel = value; store.update(model)
        })
    }
    private func chooseDataset() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            datasetURL = url
            logs = FileManager.default.fileExists(atPath: url.appendingPathComponent("train.jsonl").path)
                ? "Dataset selected: \(url.lastPathComponent)\nFound train.jsonl. Ready to train."
                : "ERROR: This folder does not contain train.jsonl. MLX-LM expects a directory with train.jsonl and optional valid.jsonl."
        }
    }
    private func installMLX() {
        isInstalling = true; logs = "Installing mlx-lm[train] with the system Python…\n"
        let task = Process(); let pipe = Pipe()
        let venv = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Conor/mlx-venv", isDirectory: true)
        let command = "python3 -m venv '\(venv.path)' && '\(venv.appendingPathComponent("bin/pip").path)' install 'mlx-lm[train]'"
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["bash", "-lc", command]
        task.standardOutput = pipe; task.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let chunk = String(data: data, encoding: .utf8) {
                Task { @MainActor in logs += chunk }
            }
        }
        task.terminationHandler = { p in
            pipe.fileHandleForReading.readabilityHandler = nil
            Task { @MainActor in
                isInstalling = false
                logs += "\nMLX-LM installation finished (exit \(p.terminationStatus))."
                if p.terminationStatus != 0 { logs += "\nIf installation fails, check that Python 3.10+ is installed and that this Mac is Apple Silicon." }
            }
        }
        do { try task.run(); installProcess = task } catch {
            isInstalling = false; logs += "\nCould not start Python: \(error.localizedDescription)"
        }
    }
    private func startTraining() {
        guard let model = selectedModel, let datasetURL else { return }
        let trainFile = datasetURL.appendingPathComponent("train.jsonl")
        guard FileManager.default.fileExists(atPath: trainFile.path) else {
            logs = "Training stopped: train.jsonl was not found in the selected folder."; return
        }
        guard let rate = Double(learningRate), rate > 0 else { logs = "Learning rate must be a positive number."; return }
        let output = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Conor/Training/\(model.id.uuidString)", isDirectory: true)
        do { try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true) }
        catch { logs = "Cannot create adapter output folder: \(error.localizedDescription)"; return }
        let task = Process(); let pipe = Pipe()
        let trainer = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Conor/mlx-venv/bin/mlx_lm.lora")
        guard FileManager.default.isExecutableFile(atPath: trainer.path) else {
            logs = "MLX-LM is not installed in Conor's isolated environment. Click Install training engine first."; return
        }
        task.executableURL = URL(fileURLWithPath: trainer.path)
        task.arguments = ["--model", model.baseModel, "--train", "--data", datasetURL.path,
                          "--iters", String(epochs), "--batch-size", String(batchSize), "--learning-rate", String(rate),
                          "--adapter-path", output.path, "--steps-per-report", "1", "--save-every", "10", "--grad-checkpoint"]
        task.standardOutput = pipe; task.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let chunk = String(data: data, encoding: .utf8) {
                Task { @MainActor in logs += chunk }
            }
        }
        task.terminationHandler = { p in
            pipe.fileHandleForReading.readabilityHandler = nil
            Task { @MainActor in
                isTraining = false; exitCode = p.terminationStatus; process = nil
                logs += "\n\nTraining process ended with exit code \(p.terminationStatus)."
                if p.terminationStatus == 0, var updated = store.models.first(where: { $0.id == model.id }) {
                    updated.status = "LoRA trained"; store.update(updated)
                }
            }
        }
        do {
            logs = "Starting MLX-LM LoRA training…\nBase: \(model.baseModel)\nDataset: \(datasetURL.path)\nIterations: \(epochs)\nAdapter output: \(output.path)\n\n"
            exitCode = nil; isTraining = true; try task.run(); process = task
        } catch { isTraining = false; logs += "Could not launch mlx_lm.lora: \(error.localizedDescription)\nInstall MLX-LM first." }
    }
    private func stopTraining() {
        process?.terminate(); logs += "\nStop requested by user."
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
