//
//  SpeakLifeCoreExports.swift
//  SpeakLife
//
//  PR6 moved the domain models, EnforcementAssembler, EnforcementCurator, and
//  the checklist/streak types into the Foundation-only `SpeakLifeCore` package.
//  The app has 123 files that reach for those types (BurstDeclaration,
//  DeclarationCategory, StreakStats, etc.), and every one of them would
//  otherwise need `import SpeakLifeCore` at the top. Re-exporting once here
//  means the boundary shows up in exactly one place, and the file tree stays
//  quiet.
//
//  When PR8 pulls the service tier out into its own Core-dependent target,
//  add `@_exported import SpeakLifeServices` alongside these lines.
//

@_exported import SpeakLifeCore
@_exported import SpeakLifePersistence
