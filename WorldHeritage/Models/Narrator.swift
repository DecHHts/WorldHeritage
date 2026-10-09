import Foundation
import AVFoundation

/// 语音讲解：用系统语音朗读遗产简介
final class Narrator: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var speakingID: Int? = nil

    private let synth = AVSpeechSynthesizer()

    override init() {
        super.init()
        synth.delegate = self
    }

    private var voiceCode: String {
        switch L10n.lang {
        case .hans: return "zh-CN"
        case .hant: return "zh-TW"
        case .en: return "en-US"
        case .ja: return "ja-JP"
        case .ko: return "ko-KR"
        }
    }

    func toggle(_ site: Site) {
        if speakingID == site.id {
            stop()
            return
        }
        synth.stopSpeaking(at: .immediate)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        let u = AVSpeechUtterance(string: site.name + "。" + site.summary)
        u.voice = AVSpeechSynthesisVoice(language: voiceCode)
        u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.96
        speakingID = site.id
        synth.speak(u)
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
        speakingID = nil
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.speakingID = nil }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { if !synthesizer.isSpeaking { self.speakingID = nil } }
    }
}
