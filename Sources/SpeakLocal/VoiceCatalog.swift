import Foundation

struct VoiceOption: Identifiable, Hashable {
    let id: String
    let name: String
    let group: String

    var displayName: String { name }
}

enum VoiceCatalog {
    static let curated: [VoiceOption] = [
        VoiceOption(id: "af_heart", name: "Heart (warm, default)", group: "American English — Female"),
        VoiceOption(id: "af_bella", name: "Bella", group: "American English — Female"),
        VoiceOption(id: "af_nicole", name: "Nicole", group: "American English — Female"),
        VoiceOption(id: "af_sarah", name: "Sarah", group: "American English — Female"),
        VoiceOption(id: "am_michael", name: "Michael", group: "American English — Male"),
        VoiceOption(id: "am_adam", name: "Adam", group: "American English — Male"),
        VoiceOption(id: "am_echo", name: "Echo", group: "American English — Male"),
        VoiceOption(id: "bf_emma", name: "Emma", group: "British English — Female"),
        VoiceOption(id: "bm_george", name: "George", group: "British English — Male"),
        VoiceOption(id: "ff_siwis", name: "Siwis", group: "French"),
        VoiceOption(id: "jf_alpha", name: "Alpha", group: "Japanese"),
    ]

    static var grouped: [(String, [VoiceOption])] {
        let groups = Dictionary(grouping: curated, by: \.group)
        return groups.keys.sorted().map { ($0, groups[$0]!.sorted { $0.name < $1.name }) }
    }
}
