//
//  DocumentsDirectory.swift
//  SpeakLifePersistence
//

import Foundation

/// Where the legacy on-disk files live, resolved through a closure so tests can
/// point at a temporary directory instead of the real one.
///
/// Three call sites used to resolve this independently, and they did not agree
/// on whether it could fail: `FavoritesMigrationService` and
/// `AudioFavoritesManager` force-unwrapped it, while
/// `DataMigrationManager.cleanUpLegacyData` guarded and reported a
/// `documents_directory_not_found` analytics failure. It cannot fail on either
/// platform this ships to, so this settles it as non-optional — and settles it
/// in one place rather than spreading a force-unwrap to a third.
///
/// The reason this matters beyond tidiness: the migration tests wrote
/// `declarations.json` and `audioFavorites.txt` into the *real* documents
/// directory of whatever machine ran them, deleting whatever was already there.
/// `FavoritesMigrationServiceTests` even built itself a temp directory in
/// `setUp` and then could not use it, because the service reached past it.
public enum DocumentsDirectory {

    /// The real documents directory.
    ///
    /// Falls back to the temporary directory rather than trapping. A `nil` here
    /// would mean the platform has no documents directory at all, in which case
    /// failing a legacy-file cleanup is the right outcome — not bringing down
    /// the process, which is what the previous `!` would have done.
    public static func system() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    }
}
