import SwiftUI
import AnvilTerminal

struct TerminalView: View {
    @ObservedObject var viewModel: TerminalViewModel
    var sessionOverrideId: UUID? = nil

    var body: some View {
        VStack(spacing: 0) {
            if let session = activeSession {
                TerminalContentView(session: session, viewModel: viewModel)
                    .id(session.id)
            } else {
                emptyState
            }
        }
        .background(Color.clear)
    }

    private var activeSession: TerminalSession? {
        if let sessionOverrideId {
            return viewModel.session(with: sessionOverrideId)
        }
        return viewModel.selectedSession
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AnvilSpacing.md) {
            Image(systemName: "terminal")
                .font(.system(size: 32, weight: .thin))
                .foregroundStyle(AnvilColor.textTertiary.opacity(0.5))

            Text("No terminal session")
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Terminal Content View

struct TerminalContentView: View {
    @ObservedObject var session: TerminalSession
    @ObservedObject var viewModel: TerminalViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            let charSize = measureCharSize()
            let _ = updateSize(geometry: geometry, charSize: charSize)

            VStack(spacing: 0) {
                HStack {
                    Circle()
                        .fill(AnvilColor.accentRed)
                        .frame(width: 10, height: 10)
                    Circle()
                        .fill(AnvilColor.accentAmber)
                        .frame(width: 10, height: 10)
                    Circle()
                        .fill(AnvilColor.accentGreen)
                        .frame(width: 10, height: 10)

                    Spacer()

                    Text(session.title)
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)

                    Spacer()
                }
                .padding(.horizontal, AnvilSpacing.md)
                .padding(.vertical, AnvilSpacing.sm)
                .background(.thinMaterial)

                Divider().overlay(AnvilColor.borderSubtle)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            let allLines = session.screenBuffer.allLines
                            ForEach(Array(allLines.enumerated()), id: \.element.id) { _, line in
                                terminalLineView(line)
                                    .id(line.id)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                    }
                    .background(Color(nsColor: .textBackgroundColor))
                    .onChange(of: session.screenBuffer.allLines.count) { _, _ in
                        if let lastId = session.screenBuffer.allLines.last?.id {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AnvilColor.borderSubtle, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
            .contentShape(Rectangle())
            .onTapGesture {
                isFocused = true
            }
        }
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onKeyPress(phases: .down) { keyPress in
            handleKeyPress(keyPress)
        }
        .onAppear {
            isFocused = true
        }
    }

    // MARK: - Line Rendering

    private func terminalLineView(_ line: AnvilTerminal.TerminalLine) -> some View {
        HStack(spacing: 0) {
            let spans = line.attributedSpans()
            if spans.isEmpty {
                Text(" ")
                    .font(AnvilFont.code)
                    .foregroundStyle(Color.clear)
            } else {
                ForEach(spans) { span in
                    Text(span.text)
                        .font(spanFont(span.attributes))
                        .foregroundStyle(foregroundColor(span.attributes))
                        .background(backgroundColor(span.attributes))
                        .underline(span.attributes.underline)
                        .strikethrough(span.attributes.strikethrough)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(height: 16)
        .textSelection(.enabled)
    }

    // MARK: - Keyboard Input

    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        guard session.isRunning else { return .ignored }

        let chars = keyPress.characters
        let key = keyPress.key
        let modifiers = keyPress.modifiers

        // Handle control key combinations
        if modifiers.contains(.command) {
            return .ignored // Let system handle Cmd+key
        }

        if modifiers.contains(.control) {
            if let scalar = chars.unicodeScalars.first {
                let letter = scalar.value
                if letter >= 0x61 && letter <= 0x7A { // a-z
                    let ctrlCode = letter - 0x60
                    if let scalar = UnicodeScalar(ctrlCode) {
                        session.send(String(scalar))
                    }
                    return .handled
                }
            }
            return .ignored
        }

        // Special keys
        switch key {
        case .return:
            session.send("\r")
            return .handled
        case .tab:
            session.send("\t")
            return .handled
        case .delete: // Backspace
            session.send("\u{7F}")
            return .handled
        case .upArrow:
            session.sendKey(.up)
            return .handled
        case .downArrow:
            session.sendKey(.down)
            return .handled
        case .leftArrow:
            session.sendKey(.left)
            return .handled
        case .rightArrow:
            session.sendKey(.right)
            return .handled
        case .escape:
            session.sendKey(.escape)
            return .handled
        case .home:
            session.sendKey(.home)
            return .handled
        case .end:
            session.sendKey(.end)
            return .handled
        case .pageUp:
            session.sendKey(.pageUp)
            return .handled
        case .pageDown:
            session.sendKey(.pageDown)
            return .handled
        default:
            break
        }

        // Regular characters
        if !chars.isEmpty {
            session.send(String(chars))
            return .handled
        }

        return .ignored
    }

    // MARK: - Sizing

    private func measureCharSize() -> CGSize {
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let attrStr = NSAttributedString(string: "M", attributes: [.font: font])
        let size = attrStr.size()
        return CGSize(width: max(size.width, 7), height: max(size.height, 16))
    }

    private func updateSize(geometry: GeometryProxy, charSize: CGSize) {
        let cols = max(20, Int(geometry.size.width / charSize.width))
        let rows = max(5, Int(geometry.size.height / charSize.height))
        if cols != viewModel.terminalColumns || rows != viewModel.terminalRows {
            Task { @MainActor in
                viewModel.resize(columns: cols, rows: rows)
            }
        }
    }

    // MARK: - Color Mapping

    private func foregroundColor(_ attrs: ANSIAttributes) -> Color {
        let color = attrs.inverse ? attrs.background : attrs.foreground
        return ansiColor(color, isDefault: true)
    }

    private func backgroundColor(_ attrs: ANSIAttributes) -> Color {
        let color = attrs.inverse ? attrs.foreground : attrs.background
        return ansiBackgroundColor(color)
    }

    private func spanFont(_ attrs: ANSIAttributes) -> Font {
        if attrs.bold {
            return .system(size: 12, weight: .bold, design: .monospaced)
        }
        if attrs.italic {
            return .system(size: 12, design: .monospaced).italic()
        }
        return AnvilFont.code
    }

    private func ansiColor(_ color: ANSIColor, isDefault: Bool) -> Color {
        switch color {
        case .default: return isDefault ? AnvilColor.textPrimary : .clear
        case .black: return Color(hex: 0x3B4252)
        case .red: return Color(hex: 0xBF616A)
        case .green: return Color(hex: 0xA3BE8C)
        case .yellow: return Color(hex: 0xEBCB8B)
        case .blue: return Color(hex: 0x81A1C1)
        case .magenta: return Color(hex: 0xB48EAD)
        case .cyan: return Color(hex: 0x88C0D0)
        case .white: return Color(hex: 0xE5E9F0)
        case .brightBlack: return Color(hex: 0x4C566A)
        case .brightRed: return Color(hex: 0xBF616A)
        case .brightGreen: return Color(hex: 0xA3BE8C)
        case .brightYellow: return Color(hex: 0xEBCB8B)
        case .brightBlue: return Color(hex: 0x81A1C1)
        case .brightMagenta: return Color(hex: 0xB48EAD)
        case .brightCyan: return Color(hex: 0x8FBCBB)
        case .brightWhite: return Color(hex: 0xECEFF4)
        case .palette(let idx): return palette256Color(idx)
        case .rgb(let r, let g, let b):
            return Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
        }
    }

    private func ansiBackgroundColor(_ color: ANSIColor) -> Color {
        switch color {
        case .default: return .clear
        default: return ansiColor(color, isDefault: false)
        }
    }

    private func palette256Color(_ index: UInt8) -> Color {
        let idx = Int(index)
        if idx < 16 {
            return ansiColor(ANSIColor.from4Bit(idx % 8, bright: idx >= 8), isDefault: true)
        }
        if idx < 232 {
            // 216 color cube: 6x6x6
            let adjusted = idx - 16
            let r = adjusted / 36
            let g = (adjusted % 36) / 6
            let b = adjusted % 6
            return Color(
                red: r == 0 ? 0 : Double(r * 40 + 55) / 255,
                green: g == 0 ? 0 : Double(g * 40 + 55) / 255,
                blue: b == 0 ? 0 : Double(b * 40 + 55) / 255
            )
        }
        // Grayscale: 24 shades
        let gray = Double((idx - 232) * 10 + 8) / 255
        return Color(red: gray, green: gray, blue: gray)
    }
}
