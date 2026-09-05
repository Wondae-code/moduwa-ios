import AVFoundation
import SwiftUI

/// 화면의 **내용**을 소리로 읽어 주는 하나뿐인 낭독기.
///
/// **왜 만드는가**: iOS 에 이미 VoiceOver 와 "화면 읽어주기"가 있다. 그런데 그 둘의 사용자는
/// 스크린리더를 켤 줄 아는 사람이고, 이 기능이 겨냥하는 사람은 **VoiceOver 를 켜지 않는
/// 저시력·고령·난독 사용자와 이동 중이라 화면을 못 보는 사람**이다. 그들은 두 손가락으로
/// 위에서 쓸어내리는 제스처를 모른다 — 화면에 보이는 버튼이라야 닿는다.
///
/// **OS 기능보다 나은 단 하나의 지점은 "무엇을 어떤 순서로 읽는가"다.** 화면 읽어주기는 탭 바와
/// 버튼 라벨까지 순서대로 읽지만, 우리는 무장애 정보를 먼저 읽을 수 있다. 그래서 이 타입은
/// 화면을 훑지 않고 **호출부가 골라 준 조각들**(`speak(_:id:)`)만 읽는다.
///
/// `@MainActor` 를 붙이지 않는다 — `AVSpeechSynthesizerDelegate` 콜백이 액터 바깥에서 오고,
/// 이 앱의 다른 공유 상태들도 같은 판단을 했다(`AccessibilitySettings` 주석). 읽고 쓰는 실제
/// 시점은 뷰(메인 액터)와 메인 큐 콜백이라 경합은 없다.
@Observable
final class SpeechReader: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = SpeechReader()

    /// 지금 읽고 있는 화면의 식별자(장소 contentId 등). 화면마다 버튼이 있으므로 이 값으로
    /// "내가 읽는 중인가"를 가른다 — 다른 장소로 넘어가서 누르면 앞의 낭독은 멈춘다.
    private(set) var readingID: String?
    /// 지금 읽는 조각의 번호. 화면이 이 값으로 어느 문단을 강조할지 정한다.
    private(set) var segment: Int?
    /// 그 조각 안에서 지금 읽는 글자 범위. 강조 표시에 쓴다.
    private(set) var range: NSRange?

    private let synthesizer = AVSpeechSynthesizer()
    /// 말할 차례를 기다리는 발화들. 콜백이 준 `utterance` 로 조각 번호를 되찾는다.
    ///
    /// ⚠️ 번호를 **함께 들고 다닌다.** 빈 조각을 걸러 내면 배열 위치가 밀려서, 화면이 아는
    /// 번호(설명은 몇 번째인가)와 어긋난다 — 엉뚱한 문단이 강조된다.
    private var utterances: [(index: Int, utterance: AVSpeechUtterance)] = []

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    func isReading(_ id: String) -> Bool { readingID == id }

    /// 누르면 읽고, 읽는 중에 다시 누르면 멈춘다. 버튼 하나로 두 동작을 다 하는 편이
    /// 재생·정지 버튼 둘을 두는 것보다 손이 덜 간다.
    func toggle(_ texts: [String], id: String) {
        if isReading(id) {
            stop()
        } else {
            speak(texts, id: id)
        }
    }

    func speak(_ texts: [String], id: String) {
        stop()

        let cleaned = texts.enumerated()
            .map { (index: $0.offset, text: SpeechText.cleaned($0.element)) }
            .filter { !$0.text.isEmpty }
        guard !cleaned.isEmpty else { return }

        // ⚠️ **`.playback` 으로 열지 않으면 무음 스위치를 내린 기기에서 소리가 나지 않는다.**
        //  접근성 기능이 "어떤 사람에게는 그냥 안 되는" 상태가 되는 가장 흔한 원인이다.
        //  `.duckOthers` 는 남의 음악을 끊지 않고 잠깐 줄인다 — 길 찾는 중에 듣는 경우가 있다.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)

        readingID = id
        utterances = cleaned.map { piece in
            let utterance = AVSpeechUtterance(string: piece.text)
            utterance.voice = AVSpeechSynthesisVoice(language: "ko-KR")
            utterance.rate = AccessibilitySettings.shared.speechRate.value
            // 조각 사이에 숨을 둔다 — 이름과 주소가 한 문장처럼 붙어 들리지 않게.
            utterance.postUtteranceDelay = 0.35
            return (piece.index, utterance)
        }
        utterances.forEach { synthesizer.speak($0.utterance) }
    }

    func stop() {
        guard readingID != nil else { return }
        synthesizer.stopSpeaking(at: .immediate)
        finish()
    }

    /// 화면을 떠날 때 부른다. **다른 화면이 읽고 있으면 건드리지 않는다.**
    func stop(ifReading id: String) {
        if isReading(id) { stop() }
    }

    private func finish() {
        readingID = nil
        segment = nil
        range = nil
        utterances = []
        // 남의 음악을 다시 키워 준다. 이 알림 없이 끄면 볼륨이 줄어든 채로 남는다.
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        segment = utterances.first { $0.utterance === utterance }?.index
        range = characterRange
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // 마지막 조각까지 끝났을 때만 정리한다 — 중간 조각의 완료는 아직 읽는 중이다.
        guard utterances.last?.utterance === utterance else { return }
        finish()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        // `stop()` 이 이미 정리했다. 여기서 또 부르면 다음 낭독의 상태를 지울 수 있다.
    }
}

/// 읽기 전에 글을 다듬는다.
///
/// 눈으로 읽을 때는 아무렇지 않은 기호가 소리로는 잡음이 된다 — 관광공사 원문에 흔한
/// `※`, 가운뎃점, 줄바꿈이 그렇다.
///
/// ⚠️ **글자 수를 바꾸지 않는다.** 한 글자를 한 글자로만 바꾼다(지우거나 합치지 않는다).
/// 낭독기가 알려 주는 위치(`willSpeakRangeOfSpeechString`)는 **읽는 글 기준의 UTF-16
/// 오프셋**인데, 화면은 원문을 그리고 있다. 여기서 길이가 달라지면 강조가 몇 글자씩 밀려
/// 엉뚱한 자리를 덮는다. 공백을 줄이거나 줄을 합치고 싶어지지만, 그 대가가 이것이다.
enum SpeechText {
    static func cleaned(_ raw: String) -> String {
        var text = raw

        // 가운뎃점은 쉼표로 — "천안·아산" 이 "천안아산" 으로 붙어 들리는 것을 막는다.
        text = text.replacingOccurrences(of: "·", with: ",")
        // 읽으면 잡음이 되는 장식 기호는 공백으로 지운다.
        text = text.replacingOccurrences(of: "[※▶▸■□◆●*#_~|]", with: " ",
                                         options: .regularExpression)
        // 줄바꿈을 마침표로 — 앞 줄과 뒷 줄이 한 문장처럼 이어 들리는 것을 막는다.
        //  이미 마침표로 끝난 줄이면 ".." 이 되는데, 그건 잠깐 쉬는 소리라 해롭지 않다.
        text = text.replacingOccurrences(of: "[\n\r]", with: ".", options: .regularExpression)

        return text
    }
}
