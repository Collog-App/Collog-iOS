import Foundation
import Testing
@testable import collog_ios

@MainActor
struct ProfileCompletionTests {
    @Test
    func completedProfileCanHaveNoConditions() {
        let profile = ProfileDTO(parentId: "parent", conditions: [], isCompleted: true, updatedAt: nil)
        #expect(profile.hasCompletedSetup)
    }

    @Test
    func explicitIncompleteStatusOverridesLegacyFields() {
        let profile = ProfileDTO(
            parentId: "parent", conditions: ["HYPERTENSION"], isCompleted: false, updatedAt: Date()
        )
        #expect(!profile.hasCompletedSetup)
    }

    @Test
    func legacySavedEmptyProfileIsComplete() {
        let profile = ProfileDTO(parentId: "parent", conditions: [], isCompleted: nil, updatedAt: Date())
        #expect(profile.hasCompletedSetup)
    }

    @Test
    func untouchedProfileNeedsSetup() {
        let profile = ProfileDTO(parentId: "parent", conditions: [], isCompleted: nil, updatedAt: nil)
        #expect(!profile.hasCompletedSetup)
    }
}
