import Foundation
import PackagePlugin

enum TestedTargetFinder {
    /// Search for testedTarget
    /// - Parameters:
    ///   - target: Test target
    ///   - packageDirectory: Directory of the package, where `prefire` looks for `.prefire.yml` last
    ///   - environment: The variables the plugin replaces in `.prefire.yml`
    /// - Returns: Tested Target object
    static func findTestedTarget(for target: Target, packageDirectory: URL, environment: [String: String]) throws -> SwiftSourceModuleTarget? {
        let swiftTarget = target as? SwiftSourceModuleTarget

        guard swiftTarget?.kind == .test else {
            throw NSError(domain: "`PrefireTestsPlugin` must be connected to the test target. \(target.name) is not a test target.", code: 0)
        }

        let targetDependencies: [SwiftSourceModuleTarget] = swiftTarget?.dependencies
            .compactMap { dependency in
                if case let .target(target) = dependency {
                    return target as? SwiftSourceModuleTarget
                } else {
                    return nil
                }
            } ?? []

        func configuredName(in directory: URL) -> String? {
            PrefireConfigFile.first(in: [directory])?.value(of: "target", in: "test_configuration", environment: environment)
        }

        // `prefire` reads `target` from the first `.prefire.yml` of the test target, the tested target and the
        // package. The tested target is what this looks for, so a dependency counts when its own names it.
        let testTargetURL = URL(filePath: String(describing: target.directory))
        let name: String?
        if PrefireConfigFile.first(in: [testTargetURL]) != nil {
            name = configuredName(in: testTargetURL)
        } else if let dependency = targetDependencies.first(where: { configuredName(in: $0.directoryURL) == $0.name }) {
            return dependency
        } else {
            name = configuredName(in: packageDirectory)
        }

        let targetName = name ?? target.name.replacingOccurrences(of: "Tests", with: "")

        return targetDependencies.first(where: { $0.name == targetName }) ?? targetDependencies.first(where: { $0.kind == .generic })
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension TestedTargetFinder {
    /// Search for testedTarget
    /// - Parameters:
    ///   - target: Test Target
    ///   - name: The `target` of `.prefire.yml`, if any
    ///   - project: Current Xcode Project
    /// - Returns: Tested Xcode Target
    static func findTestedTarget(for target: XcodeTarget, named name: String?, project: XcodeProject) throws -> XcodeTarget? {
        guard target.isTestKind else {
            throw NSError(domain: "`PrefireTestsPlugin` must be connected to the test target. \(target.displayName) is not a test target.", code: 0)
        }

        let targetName = name ?? target.displayName.replacingOccurrences(of: "Tests", with: "")

        let testedTargets = project.targets.filter { !$0.isTestKind }
        return testedTargets.first(where: { $0.displayName == targetName }) ?? testedTargets.first
    }
}

extension XcodeTarget {
    var isTestKind: Bool {
        guard let kind = product?.kind
        else { return false }

        switch kind {
        case .other("com.apple.product-type.bundle.unit-test"),
             .other("com.apple.product-type.bundle.ui-testing"):
            return true
        default:
            return false
        }
    }
}
#endif
