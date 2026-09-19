//
//  ContentView.swift
//  pigment
//
//  Created by Jack on 2026/9/19.
//

import SwiftUI

enum Pigment {
    case red, yellow, blue
}

struct Cell {
    var pigments: Set<Pigment> = []
    var source: Pigment? = nil
    var target: Set<Pigment>? = nil
}

struct Position: Equatable {
    var row: Int
    var col: Int
}

enum GameState: Equatable {
    case playing, won, failed
}

struct Snapshot {
    var board: [[Cell]]
    var playerPos: Position
    var held: Pigment?
}

enum LevelCategory: String {
    case tutorial = "教學"
    case formal = "正式關卡"
}

struct Level {
    let name: String
    let category: LevelCategory
    let rows: [String]
    let start: Position
    let par: Int

    var board: [[Cell]] {
        let lengths = Set(rows.map { $0.count })
        if lengths.count > 1 {
            assertionFailure("Level \"\(name)\" rows must all have the same length")
        }
        return rows.map { row in
            row.map { character in
                var cell = Cell()
                switch character {
                case "R": cell.source = .red
                case "Y": cell.source = .yellow
                case "B": cell.source = .blue
                case "r": cell.target = [.red]
                case "y": cell.target = [.yellow]
                case "b": cell.target = [.blue]
                case "o": cell.target = [.red, .yellow]
                case "g": cell.target = [.yellow, .blue]
                case "p": cell.target = [.red, .blue]
                default: break
                }
                return cell
            }
        }
    }
}

func pigmentColor(_ pigment: Pigment) -> Color {
    switch pigment {
    case .red: return .red
    case .yellow: return .yellow
    case .blue: return .blue
    }
}

func mixedColor(for pigments: Set<Pigment>) -> Color {
    switch pigments {
    case []: return Color(white: 0.9)
    case [.red]: return .red
    case [.yellow]: return .yellow
    case [.blue]: return .blue
    case [.red, .yellow]: return .orange
    case [.yellow, .blue]: return .green
    case [.red, .blue]: return .purple
    case [.red, .yellow, .blue]: return .black
    default: return Color(white: 0.9)
    }
}

struct ContentView: View {
    static let tutorialLevels: [Level] = [
        Level(name: "移動", category: .tutorial, rows: ["R..r"],
              start: Position(row: 0, col: 0), par: 3),
        Level(name: "沾色", category: .tutorial, rows: ["R..o", "....", "....", "Y..."],
              start: Position(row: 3, col: 0), par: 12),
        Level(name: "汙染", category: .tutorial, rows: ["R..p", "....", "....", "Yg.B"],
              start: Position(row: 3, col: 0), par: 16),
    ]

    // 正式關卡，待設計
    static let formalLevels: [Level] = []

    static let levels: [Level] = tutorialLevels + formalLevels

    @State var levelIndex: Int = 0
    @State var board: [[Cell]] = ContentView.levels[0].board
    @State var playerPos: Position = ContentView.levels[0].start
    @State var held: Pigment? = ContentView.levels[0].board[
        ContentView.levels[0].start.row
    ][ContentView.levels[0].start.col].source

    @State var gameState: GameState = .playing
    @State var history: [Snapshot] = []
    @State var moveCount: Int = 0

    var currentLevel: Level {
        ContentView.levels[levelIndex]
    }

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 4) {
                Text("\(currentLevel.category.rawValue) · \(currentLevel.name)").font(.title2).bold()
                Text("第 \(levelIndex + 1) 關")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            statusBanner

            VStack(spacing: 8) {
                ForEach(board.indices, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(board[row].indices, id: \.self) { column in
                            CellView(
                                cell: board[row][column],
                                isPlayerHere: playerPos.row == row && playerPos.col == column
                            )
                            .onTapGesture {
                                attemptMove(to: Position(row: row, col: column))
                            }
                        }
                    }
                }
            }

            heldIndicator

            HStack(spacing: 16) {
                Button("重設") {
                    reset()
                }

                Button("Undo") {
                    undo()
                }
                .disabled(history.isEmpty)
            }

            HStack(spacing: 16) {
                Button("上一關") {
                    loadLevel(levelIndex - 1)
                }
                .disabled(levelIndex == 0)

                Button("下一關") {
                    loadLevel(levelIndex + 1)
                }
                .disabled(levelIndex == ContentView.levels.count - 1)
            }
        }
        .padding()
    }

    var statusBanner: some View {
        HStack {
            switch gameState {
            case .won:
                Text("完成")
                if levelIndex + 1 < ContentView.levels.count {
                    Button("下一關") {
                        loadLevel(levelIndex + 1)
                    }
                } else {
                    Text("全部完成")
                }
            case .failed:
                Text("調色失敗")
            case .playing:
                Text("\(moveCount) 步（最佳 \(currentLevel.par)）")
            }
        }
        .font(.headline)
    }

    var heldIndicator: some View {
        Group {
            if let held {
                Circle().fill(pigmentColor(held))
            } else {
                Circle().stroke(Color.gray, lineWidth: 2)
            }
        }
        .frame(width: 32, height: 32)
    }

    func attemptMove(to pos: Position) {
        guard gameState == .playing else { return }

        let rowDelta = abs(pos.row - playerPos.row)
        let colDelta = abs(pos.col - playerPos.col)
        guard (rowDelta == 1 && colDelta == 0) || (rowDelta == 0 && colDelta == 1) else { return }

        guard board[pos.row][pos.col].pigments.count < 3 else { return }

        history.append(Snapshot(board: board, playerPos: playerPos, held: held))

        playerPos = pos

        if let source = board[pos.row][pos.col].source {
            held = source
        } else if let held {
            board[pos.row][pos.col].pigments.insert(held)
        }

        moveCount += 1
        evaluateGameState()
    }

    func evaluateGameState() {
        let cells = board.flatMap { $0 }

        if cells.contains(where: { $0.target != nil && $0.pigments.count == 3 }) {
            gameState = .failed
            return
        }

        let allTargetsMet = cells.allSatisfy { cell in
            guard let target = cell.target else { return true }
            return cell.pigments == target
        }
        if allTargetsMet {
            gameState = .won
        }
    }

    func undo() {
        guard let last = history.popLast() else { return }
        board = last.board
        playerPos = last.playerPos
        held = last.held
        gameState = .playing
        moveCount -= 1
    }

    func loadLevel(_ index: Int) {
        guard ContentView.levels.indices.contains(index) else { return }
        let level = ContentView.levels[index]
        levelIndex = index
        board = level.board
        playerPos = level.start
        held = level.board[level.start.row][level.start.col].source
        history = []
        moveCount = 0
        gameState = .playing
    }

    func reset() {
        loadLevel(levelIndex)
    }
}

struct CellView: View {
    let cell: Cell
    let isPlayerHere: Bool

    var isWall: Bool {
        cell.target == nil && cell.pigments.count == 3
    }

    var body: some View {
        RoundedRectangle(cornerRadius: isWall ? 4 : 12)
            .fill(mixedColor(for: cell.pigments))
            .frame(width: 80, height: 80)
            .overlay {
                if let source = cell.source {
                    Circle()
                        .fill(pigmentColor(source))
                        .frame(width: 20, height: 20)
                }
            }
            .overlay {
                if let target = cell.target {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(mixedColor(for: target), lineWidth: 5)
                }
            }
            .overlay {
                if isWall {
                    RoundedRectangle(cornerRadius: 2)
                        .inset(by: 8)
                        .strokeBorder(Color(white: 0.4), lineWidth: 3)
                }
            }
            .overlay {
                if isPlayerHere {
                    RoundedRectangle(cornerRadius: isWall ? 4 : 12)
                        .strokeBorder(Color.white, lineWidth: 4)
                }
            }
    }
}

#Preview {
    ContentView()
}
