import OSLog

enum Logger {
    private static let subsystem = AppConstants.bundleIdentifier

    static let database = os.Logger(subsystem: subsystem, category: "database")
    static let indexing = os.Logger(subsystem: subsystem, category: "indexing")
    static let search = os.Logger(subsystem: subsystem, category: "search")
    static let ml = os.Logger(subsystem: subsystem, category: "ml")
    static let organize = os.Logger(subsystem: subsystem, category: "organize")
    static let filesystem = os.Logger(subsystem: subsystem, category: "filesystem")
    static let ui = os.Logger(subsystem: subsystem, category: "ui")
    static let general = os.Logger(subsystem: subsystem, category: "general")
}
