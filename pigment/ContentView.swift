//
//  ContentView.swift
//  pigment
//
//  Created by Jack on 2026/9/19.
//

import SwiftUI
import UIKit

extension Font {
    /// Nanum Brush Script (OFL) — Latin-only brush font; CJK glyphs fall back to the system font automatically.
    static func brush(_ size: CGFloat) -> Font {
        .custom("NanumBrush", size: size)
    }
}

/// A substring styled in the brush font, meant to be interpolated into a `Text("...")` literal
/// so it renders inline with differently-sized surrounding text without using the deprecated `Text.+`.
func brushRun(_ text: String, size: CGFloat) -> AttributedString {
    var run = AttributedString(text)
    run.font = .brush(size)
    return run
}

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

func progressKey(for level: Level) -> String {
    "\(level.category.rawValue)-\(level.name)"
}

enum LevelProgressStore {
    static let defaultsKey = "levelBestMoves"

    static func loadAll() -> [String: Int] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let dict = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return [:]
        }
        return dict
    }

    static func saveAll(_ progress: [String: Int]) {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
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

enum Screen {
    case playing, levelSelect
}

struct ContentView: View {
    static let tutorialLevels: [Level] = [
        Level(name: "移動", category: .tutorial, rows: ["R..r", "....", "....", "...."],
              start: Position(row: 0, col: 0), par: 3),
        Level(name: "沾色", category: .tutorial, rows: ["R..o", "....", "....", "Y..."],
              start: Position(row: 3, col: 0), par: 12),
        Level(name: "汙染", category: .tutorial, rows: ["R..p", "....", "....", "Yg.B"],
              start: Position(row: 3, col: 0), par: 16),
    ]

    static let formalLevels: [Level] = [
        Level(name: "交織", category: .formal, rows: ["....", "..pY", "..oB", "R.g."],
              start: Position(row: 3, col: 0), par: 22),
        Level(name: "包圍", category: .formal, rows: ["...B", "o...", "Rg..", "p..Y"],
              start: Position(row: 2, col: 0), par: 21),
        Level(name: "偽軟", category: .formal, rows: ["...B", ".rg.", ".bo.", "R..Y"],
              start: Position(row: 3, col: 0), par: 23)
    ]

    static func isTutorialCompleted() -> Bool {
        let progress = LevelProgressStore.loadAll()
        return tutorialLevels.allSatisfy { progress[progressKey(for: $0)] != nil }
    }

    @State var screen: Screen = .levelSelect
    @State var section: LevelCategory = ContentView.isTutorialCompleted() ? .formal : .tutorial
    @State var levelIndex: Int = 0
    @State var board: [[Cell]] = ContentView.tutorialLevels[0].board
    @State var playerPos: Position = ContentView.tutorialLevels[0].start
    @State var held: Pigment? = ContentView.tutorialLevels[0].board[
        ContentView.tutorialLevels[0].start.row
    ][ContentView.tutorialLevels[0].start.col].source

    @State var gameState: GameState = .playing
    @State var history: [Snapshot] = []
    @State var moveCount: Int = 0
    @State var levelBestMoves: [String: Int] = LevelProgressStore.loadAll()

    @State var showingInfo = false
    @State var showingSettings = false
    @AppStorage("isSoundEnabled") var isSoundEnabled: Bool = true
    @AppStorage("isHapticsEnabled") var isHapticsEnabled: Bool = true

    var sectionLevels: [Level] {
        section == .tutorial ? ContentView.tutorialLevels : ContentView.formalLevels
    }

    var currentLevel: Level {
        sectionLevels[levelIndex]
    }

    var body: some View {
        switch screen {
        case .playing:
            gameScreen
        case .levelSelect:
            if section == .tutorial {
                LevelSelectView(
                    levels: ContentView.tutorialLevels,
                    bestMoves: levelBestMoves,
                    crossLinkLabel: "跳過教學",
                    crossLinkIcon: "forward.fill",
                    onSelect: { index in
                        loadLevel(index, from: ContentView.tutorialLevels)
                        screen = .playing
                    },
                    onCrossLink: {
                        section = .formal
                    }
                )
            } else {
                LevelSelectView(
                    levels: ContentView.formalLevels,
                    bestMoves: levelBestMoves,
                    crossLinkLabel: "教學關卡",
                    crossLinkIcon: "graduationcap",
                    onSelect: { index in
                        loadLevel(index, from: ContentView.formalLevels)
                        screen = .playing
                    },
                    onCrossLink: {
                        section = .tutorial
                    }
                )
            }
        }
    }

    var gameScreen: some View {
        ZStack {
            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    Button {
                        showingInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                .font(.title2)
                .sheet(isPresented: $showingInfo) {
                    MixingInfoView()
                }
                .sheet(isPresented: $showingSettings) {
                    SettingsView(isSoundEnabled: $isSoundEnabled, isHapticsEnabled: $isHapticsEnabled)
                }

                VStack(spacing: 4) {
                    if section == .tutorial {
                        Text("\(currentLevel.category.rawValue) · \(currentLevel.name)").font(.title2).bold()
                        Text("第 \(brushRun("\(levelIndex + 1)", size: 28)) 關")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(currentLevel.name).font(.title2).bold()
                    }
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
                    .font(.brush(28))
                    .disabled(history.isEmpty)
                }

                Button("選關") {
                    screen = .levelSelect
                }
            }
            .padding()

            if gameState == .won {
                resultOverlay
            }
        }
    }

    var statusBanner: some View {
        HStack {
            switch gameState {
            case .won:
                EmptyView()
            case .failed:
                Text("調色失敗")
            case .playing:
                if currentLevel.category == .formal {
                    Text("\(brushRun("\(moveCount)", size: 34)) 步")
                } else {
                    Text("\(brushRun("\(moveCount)", size: 34)) 步（最佳 \(brushRun("\(currentLevel.par)", size: 34))）")
                }
            }
        }
        .font(.headline)
    }

    var canAdvanceToNextLevel: Bool {
        levelIndex + 1 < sectionLevels.count || section == .tutorial
    }

    func goToNextLevel() {
        if levelIndex + 1 < sectionLevels.count {
            loadLevel(levelIndex + 1)
        } else if section == .tutorial {
            section = .formal
            screen = .levelSelect
        }
    }

    var resultOverlay: some View {
        ZStack {
            Color.black.opacity(0.88)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {}

            VStack(spacing: 20) {
                Text("完成").font(.title).bold()
                Text("\(brushRun("\(moveCount)", size: 40)) 步完成")
                    .font(.headline)
                crownRating

                BoardPreview(board: board, cellSize: 44)

                VStack(spacing: 12) {
                    Button {
                        reset()
                    } label: {
                        Text("重新遊玩").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        goToNextLevel()
                    } label: {
                        Text("下一關").frame(maxWidth: .infinity)
                    }
                    .disabled(!canAdvanceToNextLevel)
                    .buttonStyle(.borderedProminent)

                    Button {
                        screen = .levelSelect
                    } label: {
                        Text("選關").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .controlSize(.large)
                .frame(maxWidth: .infinity)
            }
            .padding(24)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
            .padding(32)
        }
    }

    var crownRating: some View {
        CrownRating(earnedCount: moveCount <= currentLevel.par ? 2 : 1)
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

        if isHapticsEnabled {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }

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
            recordCompletion()
        }
    }

    func recordCompletion() {
        let key = progressKey(for: currentLevel)
        if levelBestMoves[key] == nil || moveCount < levelBestMoves[key]! {
            levelBestMoves[key] = moveCount
            LevelProgressStore.saveAll(levelBestMoves)
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
        loadLevel(index, from: sectionLevels)
    }

    /// 切換分區時必須明確帶入關卡清單，因為 `section` 的新值不見得已反映到 `sectionLevels`。
    func loadLevel(_ index: Int, from levels: [Level]) {
        guard levels.indices.contains(index) else { return }
        let level = levels[index]
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

struct CrownRating: View {
    let earnedCount: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<2, id: \.self) { index in
                Image(systemName: "crown.fill")
                    .foregroundStyle(index < earnedCount ? Color.yellow : Color.gray)
            }
        }
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
                    Image("ink-stain-2")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(pigmentColor(source))
                        .frame(width: 52, height: 52)
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
                        .strokeBorder(Color(white: 0.5), lineWidth: 4)
                }
            }
    }
}

/// 關卡縮圖，讓玩家在選關時看出盤面長相。
struct BoardPreview: View {
    let board: [[Cell]]
    var cellSize: CGFloat = 14

    var body: some View {
        VStack(spacing: 2) {
            ForEach(board.indices, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(board[row].indices, id: \.self) { column in
                        let cell = board[row][column]
                        RoundedRectangle(cornerRadius: 3)
                            .fill(mixedColor(for: cell.pigments))
                            .frame(width: cellSize, height: cellSize)
                            .overlay {
                                if let source = cell.source {
                                    Circle()
                                        .fill(pigmentColor(source))
                                        .frame(width: cellSize * 0.5, height: cellSize * 0.5)
                                }
                            }
                            .overlay {
                                if let target = cell.target {
                                    RoundedRectangle(cornerRadius: 3)
                                        .strokeBorder(mixedColor(for: target), lineWidth: 2)
                                }
                            }
                    }
                }
            }
        }
    }
}

struct LevelSelectView: View {
    let levels: [Level]
    let bestMoves: [String: Int]
    let crossLinkLabel: String
    let crossLinkIcon: String
    let onSelect: (Int) -> Void
    let onCrossLink: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("選擇關卡").font(.title).bold()

            HStack(spacing: 16) {
                ForEach(levels.indices, id: \.self) { index in
                    let level = levels[index]
                    Button {
                        onSelect(index)
                    } label: {
                        VStack(spacing: 10) {
                            BoardPreview(board: level.board)
                            Text(level.name).font(.headline)
                            let best = bestMoves[progressKey(for: level)]
                            VStack(spacing: 4) {
                                Text("\(brushRun(best != nil ? "\(best!)" : "-", size: 24)) 步")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                CrownRating(earnedCount: best.map { $0 <= level.par ? 2 : 1 } ?? 0)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                onCrossLink()
            } label: {
                Label(crossLinkLabel, systemImage: crossLinkIcon)
            }

            Spacer()
        }
        .padding()
    }
}

struct MixingInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("混色規則").font(.title2).bold()
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
            }

            mixRow(pigments: [.red, .yellow], resultName: "橙", resultColor: .orange)
            mixRow(pigments: [.yellow, .blue], resultName: "綠", resultColor: .green)
            mixRow(pigments: [.red, .blue], resultName: "紫", resultColor: .purple)
            mixRow(pigments: [.red, .yellow, .blue], resultName: "黑（無法通行）", resultColor: .black)
        }
        .padding()
        .presentationDetents([.height(280)])
    }

    func mixRow(pigments: [Pigment], resultName: String, resultColor: Color) -> some View {
        HStack(spacing: 8) {
            ForEach(pigments.indices, id: \.self) { index in
                Circle().fill(pigmentColor(pigments[index])).frame(width: 24, height: 24)
                if index < pigments.count - 1 {
                    Text("+")
                }
            }
            Text("=")
            Circle().fill(resultColor).frame(width: 24, height: 24)
            Text(resultName)
        }
    }
}

struct SettingsView: View {
    @Binding var isSoundEnabled: Bool
    @Binding var isHapticsEnabled: Bool

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("設定").font(.title2).bold()
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
            }
            Toggle("背景音樂", isOn: $isSoundEnabled)
            Toggle("震動", isOn: $isHapticsEnabled)
        }
        .padding()
        .presentationDetents([.height(220)])
    }
}

#Preview {
    ContentView()
}

#Preview("選關") {
    LevelSelectView(
        levels: ContentView.formalLevels,
        bestMoves: [progressKey(for: ContentView.formalLevels[0]): 20],
        crossLinkLabel: "教學關卡",
        crossLinkIcon: "graduationcap",
        onSelect: { _ in },
        onCrossLink: { }
    )
}
