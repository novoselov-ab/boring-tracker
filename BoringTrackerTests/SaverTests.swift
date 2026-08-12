import Foundation
import Testing
@testable import BoringTracker

/// The saver is the one place where something genuinely runs off the main
/// actor, so its promises — coalesce, never go backwards, never lose the last
/// edit — are worth checking rather than trusting.
@Suite("Saving")
struct SaverTests {

    private func document(_ count: Int) -> StoreDocument {
        StoreDocument(entries: (0..<count).map {
            Entry(trackerID: UUID(), value: Double($0), date: time($0), modified: time($0))
        })
    }

    @Test("Fifty edits in a burst become one write")
    func editsCoalesce() async throws {
        let file = temporaryStoreFile()
        defer { file.removeDirectory() }
        let saver = StoreSaver(file: file, window: .seconds(30))

        for index in 1...50 {
            await saver.save(document(index), revision: UInt64(index))
        }
        await saver.flush(document(50), revision: 50)

        #expect(await saver.writeCount == 1)
        #expect(try file.read(file.url).entries.count == 50)
    }

    @Test("The window puts a change on disk without anyone asking")
    func windowElapses() async throws {
        let file = temporaryStoreFile()
        defer { file.removeDirectory() }
        let saver = StoreSaver(file: file, window: .milliseconds(20))

        await saver.save(document(3), revision: 1)

        try await confirmEventually("the window to elapse") {
            await saver.writeCount == 1
        }
        #expect(try file.read(file.url).entries.count == 3)
    }

    @Test("A document that arrives late does not overwrite a newer one")
    func staleDocumentsAreIgnored() async throws {
        let file = temporaryStoreFile()
        defer { file.removeDirectory() }
        let saver = StoreSaver(file: file, window: .seconds(30))

        // Two mutations whose hand-offs to the actor arrive in the wrong order,
        // which unstructured tasks are entitled to do.
        await saver.save(document(9), revision: 2)
        await saver.save(document(1), revision: 1)
        await saver.flush(document(9), revision: 2)

        #expect(try file.read(file.url).entries.count == 9)
    }

    @Test("Flushing an unchanged document does not rewrite the file")
    func idleFlushIsFree() async throws {
        let file = temporaryStoreFile()
        defer { file.removeDirectory() }
        let saver = StoreSaver(file: file, window: .seconds(30))

        await saver.save(document(2), revision: 1)
        await saver.flush(document(2), revision: 1)
        await saver.flush(document(2), revision: 1)
        await saver.flush(document(2), revision: 1)

        #expect(await saver.writeCount == 1)
    }

    @Test("A failed write is remembered and retried, not silently dropped")
    func failedWritesAreRetried() async throws {
        let file = temporaryStoreFile()
        defer { file.removeDirectory() }
        // A file where the directory should be: creating the store directory
        // will fail, and so will the write.
        try Data("in the way".utf8).write(to: file.directory)
        let saver = StoreSaver(file: file, window: .seconds(30))

        await saver.flush(document(2), revision: 1)
        #expect(await saver.lastError != nil)
        #expect(await saver.writeCount == 0)

        try FileManager.default.removeItem(at: file.directory)
        await saver.flush(document(2), revision: 1)

        #expect(await saver.lastError == nil)
        #expect(try file.read(file.url).entries.count == 2)
    }
}
