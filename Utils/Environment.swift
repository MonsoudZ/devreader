import Foundation
import os.log

/// Environment configuration for DevReader
/// Handles different environments: Dev, Beta, and Production
@MainActor
class Environment: ObservableObject {
    static let shared = Environment()
    
    // MARK: - Environment Types
    
    enum AppEnvironment: String, CaseIterable {
        case dev = "dev"
        case beta = "beta"
        case prod = "prod"
        
        var displayName: String {
            switch self {
            case .dev: return "Development"
            case .beta: return "Beta"
            case .prod: return "Production"
            }
        }
        
        var bundleIdentifier: String {
            switch self {
            case .dev: return "com.monsoud.devreader.dev"
            case .beta: return "com.monsoud.devreader.beta"
            case .prod: return "com.monsoud.devreader"
            }
        }
        
        var appName: String {
            switch self {
            case .dev: return "DevReader Dev"
            case .beta: return "DevReader Beta"
            case .prod: return "DevReader"
            }
        }
    }
    
    enum LogLevel: String, CaseIterable {
        case debug = "debug"
        case info = "info"
        case warning = "warning"
        case error = "error"
        
        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            }
        }
    }
    
    // MARK: - Properties
    
    @Published var currentEnvironment: AppEnvironment
    @Published var logLevel: LogLevel
    @Published var isDebugMode: Bool
    @Published var crashReportingDSN: String
    @Published var analyticsAPIKey: String
    @Published var telemetryEnabled: Bool
    @Published var sparkleFeedURL: String
    @Published var autoUpdateEnabled: Bool
    @Published var updateCheckInterval: TimeInterval
    @Published var apiBaseURL: String
    @Published var databaseName: String
    @Published var memoryWarningThreshold: Int
    @Published var performanceMonitoringEnabled: Bool
    
    // MARK: - Feature Flags
    
    @Published var featureFlagsEnabled: Bool
    @Published var featureExperimentalUI: Bool
    @Published var featureBetaFeatures: Bool
    @Published var featureDebugMenu: Bool
    @Published var featurePerformanceMonitoring: Bool
    
    private let logger = OSLog(subsystem: "dev.local.chace.DevReader", category: "Environment")
    
    private init() {
        // Initialize with default values
        self.currentEnvironment = .prod
        self.logLevel = .error
        self.isDebugMode = false
        self.crashReportingDSN = ""
        self.analyticsAPIKey = ""
        self.telemetryEnabled = false
        self.sparkleFeedURL = ""
        self.autoUpdateEnabled = true
        self.updateCheckInterval = 86400
        self.apiBaseURL = ""
        self.databaseName = "DevReader.sqlite"
        self.memoryWarningThreshold = 300
        self.performanceMonitoringEnabled = false
        
        // Feature flags
        self.featureFlagsEnabled = false
        self.featureExperimentalUI = false
        self.featureBetaFeatures = false
        self.featureDebugMenu = false
        self.featurePerformanceMonitoring = false
        
        loadConfiguration()
    }
    
    // MARK: - Configuration Loading
    
    private func loadConfiguration() {
        // Load environment from Info.plist
        if let envString = Bundle.main.object(forInfoDictionaryKey: "APP_ENV") as? String,
           let environment = AppEnvironment(rawValue: envString) {
            self.currentEnvironment = environment
        }
        
        // Load log level
        if let logLevelString = Bundle.main.object(forInfoDictionaryKey: "LOG_LEVEL") as? String,
           let logLevel = LogLevel(rawValue: logLevelString) {
            self.logLevel = logLevel
        }
        
        // Load debug mode
        if let debugMode = Bundle.main.object(forInfoDictionaryKey: "DEBUG_MODE") as? String {
            self.isDebugMode = debugMode.lowercased() == "yes"
        }
        
        // Load crash reporting DSN
        if let dsn = Bundle.main.object(forInfoDictionaryKey: "CRASH_REPORTING_DSN") as? String {
            self.crashReportingDSN = dsn
        }
        
        // Load analytics API key
        if let apiKey = Bundle.main.object(forInfoDictionaryKey: "ANALYTICS_API_KEY") as? String {
            self.analyticsAPIKey = apiKey
        }
        
        // Load telemetry settings
        if let telemetry = Bundle.main.object(forInfoDictionaryKey: "TELEMETRY_ENABLED") as? String {
            self.telemetryEnabled = telemetry.lowercased() == "yes"
        }
        
        // Load Sparkle feed URL
        if let feedURL = Bundle.main.object(forInfoDictionaryKey: "SPARKLE_FEED_URL") as? String {
            self.sparkleFeedURL = feedURL
        }
        
        // Load auto-update settings
        if let autoUpdate = Bundle.main.object(forInfoDictionaryKey: "AUTO_UPDATE_ENABLED") as? String {
            self.autoUpdateEnabled = autoUpdate.lowercased() == "yes"
        }
        
        // Load update check interval
        if let interval = Bundle.main.object(forInfoDictionaryKey: "UPDATE_CHECK_INTERVAL") as? String,
           let intervalValue = TimeInterval(interval) {
            self.updateCheckInterval = intervalValue
        }
        
        // Load API base URL
        if let baseURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String {
            self.apiBaseURL = baseURL
        }
        
        // Load database name
        if let dbName = Bundle.main.object(forInfoDictionaryKey: "DATABASE_NAME") as? String {
            self.databaseName = dbName
        }
        
        // Load memory warning threshold
        if let threshold = Bundle.main.object(forInfoDictionaryKey: "MEMORY_WARNING_THRESHOLD") as? String,
           let thresholdValue = Int(threshold) {
            self.memoryWarningThreshold = thresholdValue
        }
        
        // Load performance monitoring
        if let perfMonitoring = Bundle.main.object(forInfoDictionaryKey: "PERFORMANCE_MONITORING") as? String {
            self.performanceMonitoringEnabled = perfMonitoring.lowercased() == "yes"
        }
        
        // Load feature flags
        if let flagsEnabled = Bundle.main.object(forInfoDictionaryKey: "FEATURE_FLAGS_ENABLED") as? String {
            self.featureFlagsEnabled = flagsEnabled.lowercased() == "yes"
        }
        
        if let experimentalUI = Bundle.main.object(forInfoDictionaryKey: "FEATURE_EXPERIMENTAL_UI") as? String {
            self.featureExperimentalUI = experimentalUI.lowercased() == "yes"
        }
        
        if let betaFeatures = Bundle.main.object(forInfoDictionaryKey: "FEATURE_BETA_FEATURES") as? String {
            self.featureBetaFeatures = betaFeatures.lowercased() == "yes"
        }
        
        if let debugMenu = Bundle.main.object(forInfoDictionaryKey: "FEATURE_DEBUG_MENU") as? String {
            self.featureDebugMenu = debugMenu.lowercased() == "yes"
        }
        
        if let perfMonitoring = Bundle.main.object(forInfoDictionaryKey: "FEATURE_PERFORMANCE_MONITORING") as? String {
            self.featurePerformanceMonitoring = perfMonitoring.lowercased() == "yes"
        }
        
        os_log("Environment loaded: %{public}@", log: logger, type: .info, currentEnvironment.displayName)
        os_log("Log level: %{public}@", log: logger, type: .info, logLevel.rawValue)
        os_log("Debug mode: %{public}@", log: logger, type: .info, isDebugMode ? "enabled" : "disabled")
    }
    
    // MARK: - Environment-Specific Methods
    
    /// Returns true if running in development environment
    var isDevelopment: Bool {
        return currentEnvironment == .dev
    }
    
    /// Returns true if running in beta environment
    var isBeta: Bool {
        return currentEnvironment == .beta
    }
    
    /// Returns true if running in production environment
    var isProduction: Bool {
        return currentEnvironment == .prod
    }
    
    /// Returns the appropriate log level for the current environment
    var effectiveLogLevel: LogLevel {
        switch currentEnvironment {
        case .dev:
            return .debug
        case .beta:
            return .info
        case .prod:
            return .error
        }
    }
    
    /// Returns the appropriate update check interval for the current environment
    var effectiveUpdateInterval: TimeInterval {
        switch currentEnvironment {
        case .dev:
            return 0 // No auto-updates in dev
        case .beta:
            return 604800 // Weekly updates
        case .prod:
            return 86400 // Daily updates
        }
    }
    
    /// Returns the appropriate memory warning threshold for the current environment
    var effectiveMemoryThreshold: Int {
        switch currentEnvironment {
        case .dev:
            return 100 // Lower threshold for dev
        case .beta:
            return 200 // Medium threshold for beta
        case .prod:
            return 300 // Higher threshold for prod
        }
    }
    
    // MARK: - Feature Flag Methods
    
    /// Checks if a feature is enabled based on the current environment
    func isFeatureEnabled(_ feature: FeatureFlag) -> Bool {
        switch feature {
        case .experimentalUI:
            return featureExperimentalUI
        case .betaFeatures:
            return featureBetaFeatures
        case .debugMenu:
            return featureDebugMenu
        case .performanceMonitoring:
            return featurePerformanceMonitoring
        }
    }
    
    /// Sets a feature flag value
    func setFeatureFlag(_ feature: FeatureFlag, enabled: Bool) {
        switch feature {
        case .experimentalUI:
            featureExperimentalUI = enabled
        case .betaFeatures:
            featureBetaFeatures = enabled
        case .debugMenu:
            featureDebugMenu = enabled
        case .performanceMonitoring:
            featurePerformanceMonitoring = enabled
        }
    }
    
    // MARK: - Logging
    
    /// Logs a message with the appropriate level for the current environment
    func log(_ message: String, level: LogLevel = .info, category: String = "General") {
        let log = OSLog(subsystem: "dev.local.chace.DevReader", category: category)
        os_log("%{public}@", log: log, type: level.osLogType, message)
    }
    
    /// Logs a debug message (only in dev/beta)
    func logDebug(_ message: String, category: String = "Debug") {
        guard !isProduction else { return }
        log(message, level: .debug, category: category)
    }
    
    /// Logs an info message
    func logInfo(_ message: String, category: String = "Info") {
        log(message, level: .info, category: category)
    }
    
    /// Logs a warning message
    func logWarning(_ message: String, category: String = "Warning") {
        log(message, level: .warning, category: category)
    }
    
    /// Logs an error message
    func logError(_ message: String, category: String = "Error") {
        log(message, level: .error, category: category)
    }
}

// MARK: - Feature Flags

enum FeatureFlag: String, CaseIterable {
    case experimentalUI = "experimental_ui"
    case betaFeatures = "beta_features"
    case debugMenu = "debug_menu"
    case performanceMonitoring = "performance_monitoring"
    
    var displayName: String {
        switch self {
        case .experimentalUI: return "Experimental UI"
        case .betaFeatures: return "Beta Features"
        case .debugMenu: return "Debug Menu"
        case .performanceMonitoring: return "Performance Monitoring"
        }
    }
    
    var description: String {
        switch self {
        case .experimentalUI: return "Enable experimental user interface features"
        case .betaFeatures: return "Enable beta features for testing"
        case .debugMenu: return "Show debug menu and tools"
        case .performanceMonitoring: return "Enable performance monitoring and metrics"
        }
    }
}

// MARK: - Environment Extensions

extension Environment {
    /// Returns the current environment as a string for display
    var environmentString: String {
        return currentEnvironment.displayName
    }
    
    /// Returns the app name for the current environment
    var appName: String {
        return currentEnvironment.appName
    }
    
    /// Returns the bundle identifier for the current environment
    var bundleIdentifier: String {
        return currentEnvironment.bundleIdentifier
    }
    
    /// Returns true if telemetry should be enabled
    var shouldEnableTelemetry: Bool {
        return telemetryEnabled && !isDevelopment
    }
    
    /// Returns true if debug features should be available
    var shouldShowDebugFeatures: Bool {
        return isDevelopment || (isBeta && featureDebugMenu)
    }
    
    /// Returns true if beta features should be available
    var shouldShowBetaFeatures: Bool {
        return isDevelopment || (isBeta && featureBetaFeatures)
    }
}
