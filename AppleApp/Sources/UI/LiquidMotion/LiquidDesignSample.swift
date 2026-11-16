import SwiftUI

/// Nur die gekennzeichnete Beispielgalerie aktiviert diesen gemeinsamen Wert.
private struct LiquidDesignSampleKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var liquidDesignSample: Bool {
        get { self[LiquidDesignSampleKey.self] }
        set { self[LiquidDesignSampleKey.self] = newValue }
    }
}
