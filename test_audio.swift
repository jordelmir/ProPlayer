import AVFoundation

let file = CommandLine.arguments[1]
let url = URL(fileURLWithPath: file)
print("Playing \(url)...")
let player = AVQueuePlayer()

let item = AVPlayerItem(url: url)
player.insert(item, after: nil)
player.play()

let observer = item.observe(\.status, options: [.new]) { item, _ in
    print("Status: \(item.status.rawValue), Error: \(String(describing: item.error))")
}
RunLoop.main.run(until: Date(timeIntervalSinceNow: 5))
