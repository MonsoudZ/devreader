import SwiftUI

final class AppDependencies: ObservableObject {
    let persistence = PersistenceService.self
    let file = FileService.self
    let annotation = AnnotationService.self
}

private struct DependenciesKey: EnvironmentKey {
    static let defaultValue = AppDependencies()
}

extension EnvironmentValues {
    var deps: AppDependencies {
        get { self[DependenciesKey.self] }
        set { self[DependenciesKey.self] = newValue }
    }
}


