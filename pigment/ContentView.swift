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

struct Level {
    var board: [[Cell]]
    var startPos: Position
    var startHeld: Pigment?
}

struct ContentView: View {
    // 起點 Position(row: 2, col: 0)
    static let level3x3: [[Cell]] = {
        var grid = Array(
            repeating: Array(repeating: Cell(), count: 3),
            count: 3
        )
        grid[0][0].source = .red
        grid[0][2].source = .yellow
        grid[2][0].target = [.red, .yellow]
        return grid
    }()

    // 起點 Position(row: 3, col: 0)，開局 held = .yellow
    static let level4x4: [[Cell]] = {
        var grid = Array(
            repeating: Array(repeating: Cell(), count: 4),
            count: 4
        )
        grid[0][0].source = .red
        grid[3][0].source = .yellow
        grid[3][3].source = .blue
        grid[0][3].target = [.red, .blue]
        grid[3][1].target = [.yellow, .blue]
        return grid
    }()

    static let currentLevel = Level(
        board: level4x4,
        startPos: Position(row: 3, col: 0),
        startHeld: .yellow
    )

    @State var board: [[Cell]] = ContentView.currentLevel.board
    @State var playerPos: Position = ContentView.currentLevel.startPos
    @State var held: Pigment? = ContentView.currentLevel.startHeld

    @State var gameState: GameState = .playing
    @State var history: [Snapshot] = []
    @State var moveCount: Int = 0

    var body: some View {
        VStack(spacing: 24) {
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
        }
        .padding()
    }

    var statusBanner: some View {
        Group {
            switch gameState {
            case .won: Text("完成")
            case .failed: Text("調色失敗")
            case .playing: Text("步數：\(moveCount)")
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

    func reset() {
        board = ContentView.currentLevel.board
        playerPos = ContentView.currentLevel.startPos
        held = ContentView.currentLevel.startHeld
        history = []
        moveCount = 0
        gameState = .playing
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
