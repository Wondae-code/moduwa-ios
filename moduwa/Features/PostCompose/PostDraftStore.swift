import SwiftUI

/// 게시글 임시저장 — 시안 헤더의 "임시저장"(642:2783).
///
/// **기기에만 남긴다.** 서버에 초안 테이블을 두지 않는 이유는 초안이 남에게 보일 것이 아니고,
/// 로그인이 없어 지금은 기기가 곧 사람이기 때문이다. 로그인이 붙으면 계정으로 옮길 수 있다.
///
/// 본문·장소는 `UserDefaults` 에, **사진은 파일로** 둔다 — 다운스케일된 JPEG 이라도 장당
/// 수백 KB 라 `UserDefaults` 에 담으면 앱 실행마다 그만큼을 읽어 들이게 된다.
enum PostDraftStore {
    private static let key = "postComposeDraft"
    /// 사진을 두는 곳. 캐시가 아니라 Documents 다 — 캐시는 iOS 가 임의로 비운다.
    private static var photoDirectory: URL {
        URL.documentsDirectory.appending(path: "post-draft", directoryHint: .isDirectory)
    }

    /// 저장된 초안. 사진은 파일에서 다시 읽어 온다.
    struct Draft {
        var body: String
        var places: [PostPlace]
        /// 무장애 정보 코드. 앱이 모르는 코드는 읽는 쪽이 버린다.
        var accessFeatures: [String]
        /// 저장 당시의 사진 바이트. 순서를 지킨다.
        var photos: [Data]
    }

    private struct Stored: Codable {
        var body: String
        var places: [PostPlace]
        /// 나중에 추가된 필드다 — 이 키가 없는 옛 초안도 읽혀야 한다.
        var accessFeatures: [String]?
        /// 사진 파일 이름(확장자 포함). 순서가 곧 사진 순서다.
        var photoNames: [String]
        var savedAt: Date
    }

    /// 초안이 있는지. 화면이 열릴 때 물어보는 용도라 파일을 읽지 않는다.
    static var hasDraft: Bool {
        guard let stored = decoded() else { return false }
        return !stored.body.isEmpty || !stored.places.isEmpty || !stored.photoNames.isEmpty
            || !(stored.accessFeatures ?? []).isEmpty
    }

    static func save(body: String, places: [PostPlace], accessFeatures: [String], photos: [Data]) {
        // 이전 초안의 사진을 남겨 두면 파일이 계속 쌓인다 — 매번 갈아 치운다.
        clearPhotos()
        var names: [String] = []
        do {
            try FileManager.default.createDirectory(at: photoDirectory, withIntermediateDirectories: true)
            for (index, data) in photos.enumerated() {
                let name = "\(index).jpg"
                try data.write(to: photoDirectory.appending(path: name), options: .atomic)
                names.append(name)
            }
        } catch {
            // 사진을 못 써도 글은 남긴다 — 글이 더 아깝다.
            names = []
        }

        let stored = Stored(body: body, places: places, accessFeatures: accessFeatures,
                            photoNames: names, savedAt: .now)
        UserDefaults.standard.set(try? JSONEncoder().encode(stored), forKey: key)
    }

    static func load() -> Draft? {
        guard let stored = decoded() else { return nil }
        let photos = stored.photoNames.compactMap {
            try? Data(contentsOf: photoDirectory.appending(path: $0))
        }
        let draft = Draft(body: stored.body, places: stored.places,
                          accessFeatures: stored.accessFeatures ?? [], photos: photos)
        guard !draft.body.isEmpty || !draft.places.isEmpty || !draft.photos.isEmpty
                || !draft.accessFeatures.isEmpty else { return nil }
        return draft
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
        clearPhotos()
    }

    private static func decoded() -> Stored? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Stored.self, from: data)
    }

    private static func clearPhotos() {
        try? FileManager.default.removeItem(at: photoDirectory)
    }
}
