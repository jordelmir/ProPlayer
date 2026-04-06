import Foundation
import AVFoundation

@MainActor
public protocol PlayerEngineProtocol: AnyObject {
    var isPlaying: Bool { get }
    var currentTime: Double { get }
    var duration: Double { get }
    var volume: Double { get set }
    var isMuted: Bool { get set }
    var playbackSpeed: Double { get set }
    var isLooping: Bool { get }
    var loopA: Double? { get }
    var loopB: Double? { get }
    var matrixIntensity: Double { get set }
    
    func loadFile(url: URL)
    func play()
    func pause()
    func togglePlayPause()
    func stop()
    func seek(to seconds: Double)
    func seekRelative(_ seconds: Double)
    func seekToPercent(_ percent: Double)
    func adjustVolume(by delta: Double)
    func toggleMute()
    func cycleSpeedUp()
    func cycleSpeedDown()
    func toggleLoop()
    func captureScreenshot(savePath: URL?)
    func setupPiP(with layer: AVPlayerLayer)
    func togglePiP()
}
