import Foundation

// MARK: - ANSI Color Types

public enum ANSIColor: Sendable, Equatable {
    case `default`
    case black, red, green, yellow, blue, magenta, cyan, white
    case brightBlack, brightRed, brightGreen, brightYellow
    case brightBlue, brightMagenta, brightCyan, brightWhite
    case palette(UInt8) // 256-color
    case rgb(UInt8, UInt8, UInt8)

    public static func from4Bit(_ code: Int, bright: Bool) -> ANSIColor {
        switch code {
        case 0: return bright ? .brightBlack : .black
        case 1: return bright ? .brightRed : .red
        case 2: return bright ? .brightGreen : .green
        case 3: return bright ? .brightYellow : .yellow
        case 4: return bright ? .brightBlue : .blue
        case 5: return bright ? .brightMagenta : .magenta
        case 6: return bright ? .brightCyan : .cyan
        case 7: return bright ? .brightWhite : .white
        default: return .default
        }
    }
}

// MARK: - Text Attributes

public struct ANSIAttributes: Sendable, Equatable {
    public var foreground: ANSIColor
    public var background: ANSIColor
    public var bold: Bool
    public var dim: Bool
    public var italic: Bool
    public var underline: Bool
    public var strikethrough: Bool
    public var inverse: Bool

    public static let plain = ANSIAttributes(
        foreground: .default, background: .default,
        bold: false, dim: false, italic: false,
        underline: false, strikethrough: false, inverse: false
    )
}

// MARK: - Attributed Character

public struct TerminalChar: Sendable, Equatable {
    public var character: Character
    public var attributes: ANSIAttributes

    public init(_ character: Character, attributes: ANSIAttributes = .plain) {
        self.character = character
        self.attributes = attributes
    }
}

// MARK: - Terminal Screen Buffer

public struct TerminalLine: Sendable, Identifiable, Equatable {
    public let id: UUID
    public var cells: [TerminalChar]

    public init(cells: [TerminalChar] = []) {
        self.id = UUID()
        self.cells = cells
    }

    public var text: String {
        String(cells.map(\.character))
    }
}

// MARK: - Attributed Span (for rendering)

public struct AttributedSpan: Sendable, Identifiable, Equatable {
    public let id = UUID()
    public let text: String
    public let attributes: ANSIAttributes

    public init(text: String, attributes: ANSIAttributes) {
        self.text = text
        self.attributes = attributes
    }
}

extension TerminalLine {
    public func attributedSpans() -> [AttributedSpan] {
        guard !cells.isEmpty else { return [] }
        var spans: [AttributedSpan] = []
        var currentAttrs = cells[0].attributes
        var currentText = String(cells[0].character)

        for cell in cells.dropFirst() {
            if cell.attributes == currentAttrs {
                currentText.append(cell.character)
            } else {
                spans.append(AttributedSpan(text: currentText, attributes: currentAttrs))
                currentAttrs = cell.attributes
                currentText = String(cell.character)
            }
        }
        spans.append(AttributedSpan(text: currentText, attributes: currentAttrs))
        return spans
    }
}

// MARK: - Screen Buffer

public final class ScreenBuffer: @unchecked Sendable {
    public var lines: [TerminalLine]
    public var cursorRow: Int
    public var cursorCol: Int
    public var columns: Int
    public var rows: Int
    public var scrollbackLines: [TerminalLine]
    public var maxScrollback: Int

    private var currentAttributes: ANSIAttributes = .plain
    private var savedCursorRow: Int = 0
    private var savedCursorCol: Int = 0

    public init(columns: Int = 80, rows: Int = 24, maxScrollback: Int = 10000) {
        self.columns = columns
        self.rows = rows
        self.maxScrollback = maxScrollback
        self.cursorRow = 0
        self.cursorCol = 0
        self.scrollbackLines = []
        self.lines = (0..<rows).map { _ in TerminalLine() }
    }

    public var allLines: [TerminalLine] {
        scrollbackLines + lines
    }

    // MARK: - Writing

    public func write(_ char: Character) {
        ensureCursorInBounds()
        let cell = TerminalChar(char, attributes: currentAttributes)
        while lines[cursorRow].cells.count <= cursorCol {
            lines[cursorRow].cells.append(TerminalChar(" ", attributes: .plain))
        }
        lines[cursorRow].cells[cursorCol] = cell
        cursorCol += 1
        if cursorCol >= columns {
            cursorCol = 0
            lineFeed()
        }
    }

    public func lineFeed() {
        cursorRow += 1
        if cursorRow >= rows {
            // Scroll up: move top line to scrollback
            let scrolled = lines.removeFirst()
            scrollbackLines.append(scrolled)
            if scrollbackLines.count > maxScrollback {
                scrollbackLines.removeFirst()
            }
            lines.append(TerminalLine())
            cursorRow = rows - 1
        }
    }

    public func carriageReturn() {
        cursorCol = 0
    }

    public func backspace() {
        if cursorCol > 0 {
            cursorCol -= 1
        }
    }

    public func tab() {
        let nextTab = ((cursorCol / 8) + 1) * 8
        cursorCol = min(nextTab, columns - 1)
    }

    // MARK: - Cursor Movement

    public func moveCursor(row: Int, col: Int) {
        cursorRow = max(0, min(row, rows - 1))
        cursorCol = max(0, min(col, columns - 1))
    }

    public func moveCursorUp(_ n: Int) {
        cursorRow = max(0, cursorRow - n)
    }

    public func moveCursorDown(_ n: Int) {
        cursorRow = min(rows - 1, cursorRow + n)
    }

    public func moveCursorForward(_ n: Int) {
        cursorCol = min(columns - 1, cursorCol + n)
    }

    public func moveCursorBackward(_ n: Int) {
        cursorCol = max(0, cursorCol - n)
    }

    public func saveCursor() {
        savedCursorRow = cursorRow
        savedCursorCol = cursorCol
    }

    public func restoreCursor() {
        cursorRow = savedCursorRow
        cursorCol = savedCursorCol
    }

    // MARK: - Erase

    public func eraseInDisplay(_ mode: Int) {
        switch mode {
        case 0:
            // Erase from cursor to end of screen
            eraseLine(0)
            for i in (cursorRow + 1)..<rows {
                lines[i] = TerminalLine()
            }
        case 1:
            // Erase from start to cursor
            for i in 0..<cursorRow {
                lines[i] = TerminalLine()
            }
            eraseLine(1)
        case 2, 3:
            // Erase entire screen
            for i in 0..<rows {
                lines[i] = TerminalLine()
            }
            if mode == 3 {
                scrollbackLines.removeAll()
            }
        default:
            break
        }
    }

    public func eraseLine(_ mode: Int) {
        ensureCursorInBounds()
        switch mode {
        case 0:
            // Erase from cursor to end of line
            if cursorCol < lines[cursorRow].cells.count {
                lines[cursorRow].cells.removeSubrange(cursorCol...)
            }
        case 1:
            // Erase from start to cursor
            for i in 0...min(cursorCol, lines[cursorRow].cells.count - 1) {
                lines[cursorRow].cells[i] = TerminalChar(" ", attributes: .plain)
            }
        case 2:
            // Erase entire line
            lines[cursorRow] = TerminalLine()
        default:
            break
        }
    }

    public func deleteCharacters(_ n: Int) {
        ensureCursorInBounds()
        let end = min(cursorCol + n, lines[cursorRow].cells.count)
        if cursorCol < lines[cursorRow].cells.count {
            lines[cursorRow].cells.removeSubrange(cursorCol..<end)
        }
    }

    public func insertBlankCharacters(_ n: Int) {
        ensureCursorInBounds()
        let blanks = (0..<n).map { _ in TerminalChar(" ", attributes: .plain) }
        while lines[cursorRow].cells.count < cursorCol {
            lines[cursorRow].cells.append(TerminalChar(" ", attributes: .plain))
        }
        lines[cursorRow].cells.insert(contentsOf: blanks, at: cursorCol)
        if lines[cursorRow].cells.count > columns {
            lines[cursorRow].cells.removeLast(lines[cursorRow].cells.count - columns)
        }
    }

    // MARK: - SGR (Select Graphic Rendition)

    public func applyAttributes(_ params: [Int]) {
        var i = 0
        while i < params.count {
            let code = params[i]
            switch code {
            case 0:
                currentAttributes = .plain
            case 1:
                currentAttributes.bold = true
            case 2:
                currentAttributes.dim = true
            case 3:
                currentAttributes.italic = true
            case 4:
                currentAttributes.underline = true
            case 7:
                currentAttributes.inverse = true
            case 9:
                currentAttributes.strikethrough = true
            case 22:
                currentAttributes.bold = false
                currentAttributes.dim = false
            case 23:
                currentAttributes.italic = false
            case 24:
                currentAttributes.underline = false
            case 27:
                currentAttributes.inverse = false
            case 29:
                currentAttributes.strikethrough = false
            case 30...37:
                currentAttributes.foreground = .from4Bit(code - 30, bright: false)
            case 38:
                // Extended foreground
                if i + 1 < params.count {
                    if params[i + 1] == 5, i + 2 < params.count {
                        currentAttributes.foreground = .palette(UInt8(clamping: params[i + 2]))
                        i += 2
                    } else if params[i + 1] == 2, i + 4 < params.count {
                        currentAttributes.foreground = .rgb(
                            UInt8(clamping: params[i + 2]),
                            UInt8(clamping: params[i + 3]),
                            UInt8(clamping: params[i + 4])
                        )
                        i += 4
                    }
                }
            case 39:
                currentAttributes.foreground = .default
            case 40...47:
                currentAttributes.background = .from4Bit(code - 40, bright: false)
            case 48:
                // Extended background
                if i + 1 < params.count {
                    if params[i + 1] == 5, i + 2 < params.count {
                        currentAttributes.background = .palette(UInt8(clamping: params[i + 2]))
                        i += 2
                    } else if params[i + 1] == 2, i + 4 < params.count {
                        currentAttributes.background = .rgb(
                            UInt8(clamping: params[i + 2]),
                            UInt8(clamping: params[i + 3]),
                            UInt8(clamping: params[i + 4])
                        )
                        i += 4
                    }
                }
            case 49:
                currentAttributes.background = .default
            case 90...97:
                currentAttributes.foreground = .from4Bit(code - 90, bright: true)
            case 100...107:
                currentAttributes.background = .from4Bit(code - 100, bright: true)
            default:
                break
            }
            i += 1
        }
    }

    // MARK: - Scroll Region

    public func scrollUp(_ n: Int) {
        for _ in 0..<n {
            let scrolled = lines.removeFirst()
            scrollbackLines.append(scrolled)
            if scrollbackLines.count > maxScrollback {
                scrollbackLines.removeFirst()
            }
            lines.append(TerminalLine())
        }
    }

    public func scrollDown(_ n: Int) {
        for _ in 0..<n {
            lines.removeLast()
            lines.insert(TerminalLine(), at: 0)
        }
    }

    // MARK: - Resize

    public func resize(columns: Int, rows: Int) {
        self.columns = columns
        self.rows = rows
        while lines.count < rows {
            lines.append(TerminalLine())
        }
        while lines.count > rows {
            let removed = lines.removeFirst()
            scrollbackLines.append(removed)
        }
        cursorRow = min(cursorRow, rows - 1)
        cursorCol = min(cursorCol, columns - 1)
    }

    // MARK: - Private

    private func ensureCursorInBounds() {
        cursorRow = max(0, min(cursorRow, rows - 1))
        cursorCol = max(0, cursorCol)
    }
}

// MARK: - ANSI Parser

public final class ANSIParser: Sendable {

    public init() {}

    public enum Token: Sendable {
        case text(Character)
        case lineFeed
        case carriageReturn
        case backspace
        case tab
        case bell
        case csi(command: Character, params: [Int])
        case osc(String) // Operating System Command
        case setTitle(String)
    }

    public func parse(_ data: Data) -> [Token] {
        let bytes = [UInt8](data)
        var tokens: [Token] = []
        var i = 0

        while i < bytes.count {
            let byte = bytes[i]

            switch byte {
            case 0x1B: // ESC
                i += 1
                if i >= bytes.count { break }
                switch bytes[i] {
                case 0x5B: // [  -> CSI
                    i += 1
                    let (token, newIndex) = parseCSI(bytes, from: i)
                    if let token = token {
                        tokens.append(token)
                    }
                    i = newIndex
                case 0x5D: // ]  -> OSC
                    i += 1
                    let (token, newIndex) = parseOSC(bytes, from: i)
                    if let token = token {
                        tokens.append(token)
                    }
                    i = newIndex
                case 0x37: // 7 -> save cursor
                    tokens.append(.csi(command: "s", params: []))
                    i += 1
                case 0x38: // 8 -> restore cursor
                    tokens.append(.csi(command: "u", params: []))
                    i += 1
                case 0x4D: // M -> reverse index
                    tokens.append(.csi(command: "T", params: [1]))
                    i += 1
                default:
                    i += 1
                }

            case 0x0A: // LF
                tokens.append(.lineFeed)
                i += 1
            case 0x0D: // CR
                tokens.append(.carriageReturn)
                i += 1
            case 0x08: // BS
                tokens.append(.backspace)
                i += 1
            case 0x09: // TAB
                tokens.append(.tab)
                i += 1
            case 0x07: // BEL
                tokens.append(.bell)
                i += 1
            case 0x00...0x06, 0x0B, 0x0C, 0x0E...0x1A, 0x1C...0x1F:
                // Other control chars — ignore
                i += 1
            default:
                // Regular UTF-8 text
                if let (char, newIndex) = decodeUTF8(bytes, from: i) {
                    tokens.append(.text(char))
                    i = newIndex
                } else {
                    i += 1
                }
            }
        }

        return tokens
    }

    // MARK: - CSI Parser

    private func parseCSI(_ bytes: [UInt8], from start: Int) -> (Token?, Int) {
        var i = start
        var paramString = ""

        // Collect parameter bytes (digits, semicolons, question mark)
        while i < bytes.count {
            let b = bytes[i]
            if (0x30...0x3F).contains(b) {
                paramString.append(Character(UnicodeScalar(b)))
                i += 1
            } else {
                break
            }
        }

        // Collect intermediate bytes
        while i < bytes.count && (0x20...0x2F).contains(bytes[i]) {
            i += 1
        }

        // Final byte (command)
        guard i < bytes.count else { return (nil, i) }
        let command = Character(UnicodeScalar(bytes[i]))
        i += 1

        // Parse parameters
        let cleanParams = paramString.replacingOccurrences(of: "?", with: "")
        let params = cleanParams.split(separator: ";").compactMap { Int($0) }

        return (.csi(command: command, params: params), i)
    }

    // MARK: - OSC Parser

    private func parseOSC(_ bytes: [UInt8], from start: Int) -> (Token?, Int) {
        var i = start
        var content = ""

        while i < bytes.count {
            if bytes[i] == 0x07 { // BEL terminates OSC
                i += 1
                break
            }
            if bytes[i] == 0x1B, i + 1 < bytes.count, bytes[i + 1] == 0x5C { // ESC \ terminates OSC
                i += 2
                break
            }
            content.append(Character(UnicodeScalar(bytes[i])))
            i += 1
        }

        // OSC 0 and 2 set the window title
        if content.hasPrefix("0;") || content.hasPrefix("2;") {
            let title = String(content.dropFirst(2))
            return (.setTitle(title), i)
        }

        return (.osc(content), i)
    }

    // MARK: - UTF-8 Decoder

    private func decodeUTF8(_ bytes: [UInt8], from start: Int) -> (Character, Int)? {
        let byte = bytes[start]
        let seqLen: Int
        if byte & 0x80 == 0 { seqLen = 1 }
        else if byte & 0xE0 == 0xC0 { seqLen = 2 }
        else if byte & 0xF0 == 0xE0 { seqLen = 3 }
        else if byte & 0xF8 == 0xF0 { seqLen = 4 }
        else { return (Character(UnicodeScalar(0xFFFD)!), start + 1) }

        guard start + seqLen <= bytes.count else {
            return (Character(UnicodeScalar(0xFFFD)!), start + 1)
        }

        let subBytes = Array(bytes[start..<start + seqLen])
        if let str = String(bytes: subBytes, encoding: .utf8), let char = str.first {
            return (char, start + seqLen)
        }
        return (Character(UnicodeScalar(0xFFFD)!), start + 1)
    }
}

// MARK: - Screen Buffer + Token Processing

extension ScreenBuffer {
    public func process(_ tokens: [ANSIParser.Token]) {
        for token in tokens {
            switch token {
            case .text(let char):
                write(char)
            case .lineFeed:
                lineFeed()
            case .carriageReturn:
                carriageReturn()
            case .backspace:
                backspace()
            case .tab:
                tab()
            case .bell:
                break // Could trigger system bell
            case .csi(let command, let params):
                processCSI(command: command, params: params)
            case .osc, .setTitle:
                break // Handled at session level
            }
        }
    }

    private func processCSI(command: Character, params: [Int]) {
        let p1 = params.first ?? 1

        switch command {
        case "A": moveCursorUp(max(1, p1))
        case "B": moveCursorDown(max(1, p1))
        case "C": moveCursorForward(max(1, p1))
        case "D": moveCursorBackward(max(1, p1))
        case "E": // Cursor next line
            moveCursorDown(max(1, p1))
            carriageReturn()
        case "F": // Cursor previous line
            moveCursorUp(max(1, p1))
            carriageReturn()
        case "G": // Cursor horizontal absolute
            cursorCol = max(0, min(p1 - 1, columns - 1))
        case "H", "f": // Cursor position
            let row = max(1, params.count > 0 ? params[0] : 1) - 1
            let col = max(1, params.count > 1 ? params[1] : 1) - 1
            moveCursor(row: row, col: col)
        case "J": eraseInDisplay(params.first ?? 0)
        case "K": eraseLine(params.first ?? 0)
        case "L": // Insert lines
            let n = max(1, p1)
            for _ in 0..<n {
                if cursorRow < rows {
                    lines.insert(TerminalLine(), at: cursorRow)
                    if lines.count > rows {
                        lines.removeLast()
                    }
                }
            }
        case "M": // Delete lines
            let n = max(1, p1)
            for _ in 0..<n {
                if cursorRow < lines.count {
                    lines.remove(at: cursorRow)
                    lines.append(TerminalLine())
                }
            }
        case "P": deleteCharacters(max(1, p1))
        case "@": insertBlankCharacters(max(1, p1))
        case "S": scrollUp(max(1, p1))
        case "T": scrollDown(max(1, p1))
        case "d": // Vertical position absolute
            cursorRow = max(0, min(p1 - 1, rows - 1))
        case "m": applyAttributes(params.isEmpty ? [0] : params)
        case "s": saveCursor()
        case "u": restoreCursor()
        case "r": // Set scrolling region (ignored for now, treat as full screen)
            break
        case "h", "l": // Set/reset mode (private modes) — mostly ignore
            break
        case "n": // Device status report — ignore
            break
        case "c": // Device attributes — ignore
            break
        default:
            break
        }
    }
}
