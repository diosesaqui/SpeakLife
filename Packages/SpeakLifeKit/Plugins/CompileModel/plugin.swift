import PackagePlugin
import Foundation

// PR2 spike (scripts/spike-coredata-spm-v2.sh, Variant A) verified: SwiftPM's
// native build system does NOT run `momc` on a `.xcdatamodeld` resource — it
// just copies the source directory, and `Bundle.module` then has no `.momd` for
// `NSPersistentContainer` to load. Solution: this prebuild plugin invokes
// `xcrun momc` explicitly and emits the compiled `.momd` into the plugin work
// directory, which SwiftPM includes in the resource bundle.
//
// The model must be `exclude`d from the target so the naive resource processor
// does not copy the source form alongside the compiled one.
@main
struct CompileModel: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        guard let target = target as? SourceModuleTarget else { return [] }

        let input = target.directory.appending(subpath: "Resources/SpeakLife.xcdatamodeld")
        let outDir = context.pluginWorkDirectory.appending(subpath: "CoreDataModels")
        try? FileManager.default.createDirectory(
            atPath: outDir.string, withIntermediateDirectories: true)

        // `xcrun momc` rather than `context.tool(named:)` — momc lives inside
        // Xcode and is not on the plugin's default tool search path.
        return [
            .prebuildCommand(
                displayName: "momc SpeakLife.xcdatamodeld",
                executable: Path("/usr/bin/xcrun"),
                arguments: [
                    "momc",
                    "--sdkroot", "/",
                    input.string,
                    outDir.appending(subpath: "SpeakLife.momd").string,
                ],
                outputFilesDirectory: outDir
            )
        ]
    }
}
