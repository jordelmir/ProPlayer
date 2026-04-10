import SwiftUI

struct MatrixRainView: View {
    @State private var columns: [MatrixColumn] = []
    let themeColor: Color
    
    struct MatrixColumn {
        var x: CGFloat
        var y: CGFloat
        var speed: CGFloat
        var characters: [String]
        var length: Int
        var depth: CGFloat // 0.0 (back) to 1.0 (front)
        var flickers: [Double] // Per-character flicker state
    }
    
    // Katakana + Latin characters
    let characters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789$+-*/=%\"'#&_(),.;:?!\\|{}<>[]^~ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ")
    
    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    
                    // Group by depth to draw back to front
                    let sortedColumns = columns.sorted { $0.depth < $1.depth }
                    
                    for i in 0..<sortedColumns.count {
                        var col = sortedColumns[i]
                        let depthScale = 0.5 + (col.depth * 0.5) // Scale from 0.5 to 1.0
                        let fontSize: CGFloat = 16 * depthScale
                        let brightness = 0.4 + (col.depth * 0.6) // Darker in back
                        
                        // Breathing effect (pulsing trail)
                        let breathing = (sin(time * 2 + Double(i)) * 0.2) + 0.8
                        
                        // Draw individual characters in the column
                        for j in 0..<col.length {
                            let yPos = col.y - CGFloat(j * 20) * depthScale
                            
                            // Optimization: Skip off-screen
                            if yPos < -fontSize || yPos > size.height + fontSize { continue }
                            
                            let char = col.characters[j]
                            var color = themeColor
                            
                            // Flicker effect for this character
                            let flicker = (sin(time * 10 + Double(i * j)) * 0.3) + 0.7
                            let individualBrightness = col.flickers[j] * flicker
                            
                            // Head of the column is white/brighter with glow
                            if j == 0 {
                                color = .white
                                
                                // Draw glow for the head using a copy of the context
                                var glowContext = context
                                glowContext.addFilter(.shadow(color: color.opacity(0.8), radius: 8 * depthScale, x: 0, y: 0))
                                glowContext.draw(
                                    Text(char)
                                        .font(.system(size: fontSize, weight: .bold, design: .monospaced))
                                        .foregroundColor(color),
                                    at: CGPoint(x: col.x, y: yPos)
                                )
                            } else {
                                let trailFactor = 1.0 - (Double(j) / Double(col.length))
                                color = themeColor.opacity(trailFactor * breathing * individualBrightness * brightness)
                                
                                context.draw(
                                    Text(char)
                                        .font(.system(size: fontSize, weight: .bold, design: .monospaced))
                                        .foregroundColor(color),
                                    at: CGPoint(x: col.x, y: yPos)
                                )
                            }
                        }
                    }
                    
                    // Logic update (since we can't mutate @State in Canvas easily without a workaround,
                    // we'll use a hidden view or just update in background, but SwiftUI Canvas 
                    // is designed for immediate draw. To move objects, we update state elsewhere).
                }
            }
            .onAppear {
                setupColumns(for: geo.size)
            }
            .onChange(of: geo.size) { newSize in
                setupColumns(for: newSize)
            }
            .onReceive(Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()) { _ in
                updateColumns()
            }
        }
        .drawingGroup() 
    }
    
    private func updateColumns() {
        for i in 0..<columns.count {
            columns[i].y += columns[i].speed
            
            // Reached bottom
            if columns[i].y - CGFloat(columns[i].length * 20) > 2000 { // Large threshold to handle depth
                resetColumn(at: i)
            }
            
            // Randomly swap characters
            if Int.random(in: 0...100) < 5 {
                let charIdx = Int.random(in: 0..<columns[i].length)
                columns[i].characters[charIdx] = String(characters.randomElement()!)
                columns[i].flickers[charIdx] = .random(in: 0.5...1.0)
            }
        }
    }
    
    private func setupColumns(for size: CGSize) {
        let colWidth: CGFloat = 20
        let numCols = Int(size.width / colWidth)
        
        columns = (0..<numCols).map { i in
            let length = Int.random(in: 12...35)
            let depth = CGFloat.random(in: 0...1)
            return MatrixColumn(
                x: CGFloat(i) * colWidth + (colWidth / 2),
                y: .random(in: -size.height...size.height),
                speed: .random(in: 2...6) * (0.5 + depth * 1.5), // Faster if closer
                characters: (0..<length).map { _ in String(characters.randomElement()!) },
                length: length,
                depth: depth,
                flickers: (0..<length).map { _ in .random(in: 0.6...1.0) }
            )
        }
    }
    
    private func resetColumn(at i: Int) {
        let length = Int.random(in: 12...35)
        let depth = CGFloat.random(in: 0...1)
        columns[i].y = -CGFloat(length * 20)
        columns[i].speed = .random(in: 2...6) * (0.5 + depth * 1.5)
        columns[i].length = length
        columns[i].depth = depth
        columns[i].characters = (0..<length).map { _ in String(characters.randomElement()!) }
        columns[i].flickers = (0..<length).map { _ in .random(in: 0.6...1.0) }
    }
}
