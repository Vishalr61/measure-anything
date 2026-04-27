/// Thin wrapper around Firebase Crashlytics.
///
/// ## Setup steps (one-time, done in Xcode / Firebase Console)
///
/// 1. Go to https://console.firebase.google.com → create or open your iOS project.
/// 2. Register bundle ID `com.vishal.MeasureAnything`, download `GoogleService-Info.plist`.
/// 3. Drag `GoogleService-Info.plist` into Xcode → MeasureAnything target (copy if needed).
/// 4. In Xcode → File → Add Package Dependencies → search:
///    `https://github.com/firebase/firebase-ios-sdk`
///    Add products: **FirebaseCrashlytics** (and optionally FirebaseAnalytics).
/// 5. In the MeasureAnything target → Build Phases → add a new Run Script phase
///    (after "Compile Sources") with:
///    ```
///    "${BUILD_DIR%Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"
///    ```
///    Input files: `$(SRCROOT)/$(BUILT_PRODUCTS_DIR)/$(INFOPLIST_PATH)`
/// 6. Re-run the app — crashes will surface in Firebase Console → Crashlytics.
///
/// Once Firebase is added, the `#if canImport(FirebaseCrashlytics)` blocks below
/// compile automatically; no other changes are needed.

import Foundation

#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

enum CrashlyticsManager {
    /// Call once at app startup (after `FirebaseApp.configure()`).
    static func configure() {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        #endif
    }

    /// Log a non-fatal error for investigation in the Firebase console.
    static func record(_ error: Error, userInfo: [String: Any] = [:]) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().record(error: error, userInfo: userInfo)
        #else
        #if DEBUG
        print("[Crashlytics stub] error:", error, userInfo)
        #endif
        #endif
    }

    /// Attach a key-value pair to all subsequent crash reports.
    static func set(key: String, value: String) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
        #endif
    }
}
