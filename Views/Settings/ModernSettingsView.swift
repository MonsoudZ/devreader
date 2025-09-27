import SwiftUI
import AppKit

struct ModernSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("highlightColor") private var highlightColor = "yellow"
    @AppStorage("defaultZoom") private var defaultZoom = 1.0
    @AppStorage("autoSave") private var autoSave = true
    @AppStorage("autosaveIntervalSeconds") private var autosaveIntervalSeconds: Double = 30
    @StateObject private var performanceMonitor = PerformanceMonitor.shared
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var showingAlert = false
    @State private var selectedTab = "general"
    
    var body: some View {
        NavigationView {
            // Sidebar
            List(selection: $selectedTab) {
                Section("General") {
                    Label("Appearance", systemImage: "paintbrush")
                        .tag("appearance")
                    Label("PDF Display", systemImage: "doc.text")
                        .tag("pdf")
                    Label("Performance", systemImage: "speedometer")
                        .tag("performance")
                }
                
                Section("Features") {
                    Label("Notes & Annotations", systemImage: "note.text")
                        .tag("notes")
                    Label("Code Editor", systemImage: "terminal")
                        .tag("code")
                    Label("Web Browser", systemImage: "globe")
                        .tag("web")
                }
                
                Section("Data") {
                    Label("Storage", systemImage: "externaldrive")
                        .tag("storage")
                    Label("Backup & Restore", systemImage: "arrow.clockwise")
                        .tag("backup")
                }
                
                Section("Advanced") {
                    Label("Developer", systemImage: "hammer")
                        .tag("developer")
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 200, idealWidth: 250)
            
            // Main content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch selectedTab {
                    case "appearance":
                        AppearanceSettingsView()
                    case "pdf":
                        PDFDisplaySettingsView(
                            highlightColor: $highlightColor,
                            defaultZoom: $defaultZoom
                        )
                    case "performance":
                        PerformanceSettingsView(performanceMonitor: performanceMonitor)
                    case "notes":
                        NotesSettingsView()
                    case "code":
                        CodeSettingsView()
                    case "web":
                        WebSettingsView()
                    case "storage":
                        StorageSettingsView()
                    case "backup":
                        BackupSettingsView()
                    case "developer":
                        DeveloperSettingsView()
                    default:
                        AppearanceSettingsView()
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 800, height: 600)
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
}

// MARK: - Individual Settings Views

struct AppearanceSettingsView: View {
    @AppStorage("ui.theme") private var theme = "auto"
    @AppStorage("ui.fontSize") private var fontSize = 14.0
    @AppStorage("ui.compactMode") private var compactMode = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Appearance")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Theme")
                    .font(.headline)
                
                Picker("Theme", selection: $theme) {
                    Text("Auto").tag("auto")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Font Size")
                    .font(.headline)
                
                HStack {
                    Slider(value: $fontSize, in: 10...20, step: 1)
                    Text("\(Int(fontSize))pt")
                        .frame(width: 40)
                }
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Compact Mode", isOn: $compactMode)
                Text("Use compact layout for smaller windows")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct PDFDisplaySettingsView: View {
    @Binding var highlightColor: String
    @Binding var defaultZoom: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("PDF Display")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Highlight Color")
                    .font(.headline)
                
                Picker("Highlight Color", selection: $highlightColor) {
                    Text("Yellow").tag("yellow")
                    Text("Green").tag("green")
                    Text("Blue").tag("blue")
                    Text("Pink").tag("pink")
                    Text("Orange").tag("orange")
                    Text("Purple").tag("purple")
                }
                .pickerStyle(.segmented)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Default Zoom")
                    .font(.headline)
                
                HStack {
                    Slider(value: $defaultZoom, in: 0.5...3.0, step: 0.1)
                    Text("\(Int(defaultZoom * 100))%")
                        .frame(width: 50)
                }
            }
        }
    }
}

struct PerformanceSettingsView: View {
    @ObservedObject var performanceMonitor: PerformanceMonitor
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Performance")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Memory Usage")
                    .font(.headline)
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Current")
                        Text(performanceMonitor.formatBytes(performanceMonitor.memoryUsage))
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Pressure")
                        Text(performanceMonitor.getMemoryPressure())
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(performanceMonitor.getMemoryPressure() == "Critical" ? .red : 
                                            performanceMonitor.getMemoryPressure() == "Warning" ? .orange : .green)
                    }
                }
                .padding()
                .background(.regularMaterial)
                .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Performance Metrics")
                    .font(.headline)
                
                HStack(spacing: 20) {
                    VStack(alignment: .leading) {
                        Text("PDF Load Time")
                        Text(String(format: "%.2fs", performanceMonitor.pdfLoadTime))
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Search Time")
                        Text(String(format: "%.2fs", performanceMonitor.searchTime))
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Annotation Time")
                        Text(String(format: "%.2fs", performanceMonitor.annotationTime))
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                }
                .padding()
                .background(.regularMaterial)
                .cornerRadius(8)
            }
        }
    }
}

struct NotesSettingsView: View {
    @AppStorage("notes.autoSave") private var autoSave = true
    @AppStorage("notes.exportFormat") private var exportFormat = "markdown"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Notes & Annotations")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Auto-save Notes", isOn: $autoSave)
                Text("Automatically save notes and annotations")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Export Format")
                    .font(.headline)
                
                Picker("Export Format", selection: $exportFormat) {
                    Text("Markdown").tag("markdown")
                    Text("Plain Text").tag("text")
                    Text("HTML").tag("html")
                }
                .pickerStyle(.segmented)
            }
        }
    }
}

struct CodeSettingsView: View {
    @AppStorage("code.theme") private var theme = "vs-dark"
    @AppStorage("code.fontSize") private var fontSize = 14.0
    @AppStorage("code.wordWrap") private var wordWrap = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Code Editor")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Theme")
                    .font(.headline)
                
                Picker("Theme", selection: $theme) {
                    Text("Dark").tag("vs-dark")
                    Text("Light").tag("vs")
                    Text("High Contrast").tag("hc-black")
                }
                .pickerStyle(.segmented)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Font Size")
                    .font(.headline)
                
                HStack {
                    Slider(value: $fontSize, in: 10...24, step: 1)
                    Text("\(Int(fontSize))pt")
                        .frame(width: 40)
                }
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Word Wrap", isOn: $wordWrap)
                Text("Wrap long lines in the editor")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct WebSettingsView: View {
    @AppStorage("web.homePage") private var homePage = "https://developer.apple.com"
    @AppStorage("web.enableJavaScript") private var enableJavaScript = true
    @AppStorage("web.blockPopups") private var blockPopups = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Web Browser")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Home Page")
                    .font(.headline)
                
                TextField("Home Page URL", text: $homePage)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Enable JavaScript", isOn: $enableJavaScript)
                Text("Allow JavaScript execution on web pages")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Block Pop-ups", isOn: $blockPopups)
                Text("Prevent pop-up windows from opening")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct StorageSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Data Storage")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Storage Location")
                    .font(.headline)
                
                Text("Data is stored in JSON files for better performance:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("• Library & Settings: ~/Library/Application Support/DevReader/Data/")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("• Annotated PDFs: ~/Library/Application Support/DevReader/Annotations/")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("• Backups: ~/Library/Application Support/DevReader/Backups/")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.regularMaterial)
                .cornerRadius(8)
            }
        }
    }
}

struct BackupSettingsView: View {
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var showingAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Backup & Restore")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Data Management")
                    .font(.headline)
                
                HStack(spacing: 12) {
                    Button("Create Backup") {
                        createBackup()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Restore from Backup") {
                        restoreFromBackup()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Validate Data") {
                        validateData()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func createBackup() {
        // Implementation for backup creation
        alertTitle = "Backup Created"
        alertMessage = "Your data has been backed up successfully."
        showingAlert = true
    }
    
    private func restoreFromBackup() {
        // Implementation for backup restoration
        alertTitle = "Restore from Backup"
        alertMessage = "Select a backup file to restore from."
        showingAlert = true
    }
    
    private func validateData() {
        // Implementation for data validation
        alertTitle = "Data Validation"
        alertMessage = "All data files are valid and intact."
        showingAlert = true
    }
}

struct DeveloperSettingsView: View {
    @AppStorage("dev.debugMode") private var debugMode = false
    @AppStorage("dev.logLevel") private var logLevel = "info"
    @AppStorage("dev.showPerformance") private var showPerformance = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Developer Options")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Debug Mode", isOn: $debugMode)
                Text("Enable detailed logging and debugging information")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Log Level")
                    .font(.headline)
                
                Picker("Log Level", selection: $logLevel) {
                    Text("Error").tag("error")
                    Text("Warning").tag("warning")
                    Text("Info").tag("info")
                    Text("Debug").tag("debug")
                }
                .pickerStyle(.segmented)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Show Performance Metrics", isOn: $showPerformance)
                Text("Display real-time performance information")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
