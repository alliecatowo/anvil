import Testing
@testable import AnvilTerminal

@Suite("ANSI Parser Tests")
struct ANSIParserTests {

    @Test("Parses plain text")
    func parsePlainText() {
        let parser = ANSIParser()
        let data = "Hello".data(using: .utf8)!
        let tokens = parser.parse(data)
        #expect(tokens.count == 5)
    }

    @Test("Parses SGR color codes")
    func parseSGR() {
        let parser = ANSIParser()
        let data = "\u{1B}[31mRed\u{1B}[0m".data(using: .utf8)!
        let tokens = parser.parse(data)

        // Should have: CSI(m,[31]), R, e, d, CSI(m,[0])
        #expect(tokens.count == 5)
    }

    @Test("Screen buffer writes text")
    func screenBufferWrite() {
        let buffer = ScreenBuffer(columns: 80, rows: 24)
        let parser = ANSIParser()
        let tokens = parser.parse("Hello World".data(using: .utf8)!)
        buffer.process(tokens)

        #expect(buffer.lines[0].text.hasPrefix("Hello World"))
    }

    @Test("Screen buffer handles newlines")
    func screenBufferNewlines() {
        let buffer = ScreenBuffer(columns: 80, rows: 24)
        let parser = ANSIParser()
        let tokens = parser.parse("Line1\r\nLine2".data(using: .utf8)!)
        buffer.process(tokens)

        #expect(buffer.lines[0].text.hasPrefix("Line1"))
        #expect(buffer.lines[1].text.hasPrefix("Line2"))
    }

    @Test("Screen buffer handles cursor movement")
    func cursorMovement() {
        let buffer = ScreenBuffer(columns: 80, rows: 24)
        let parser = ANSIParser()
        let tokens = parser.parse("ABC\u{1B}[2DXYZ".data(using: .utf8)!)
        buffer.process(tokens)

        // ABC, move left 2, write XYZ -> AXYZ
        #expect(buffer.lines[0].text.hasPrefix("AXYZ"))
    }

    @Test("Attributed spans group by attributes")
    func attributedSpans() {
        let buffer = ScreenBuffer(columns: 80, rows: 24)
        let parser = ANSIParser()
        let data = "plain\u{1B}[1mbold\u{1B}[0mnormal".data(using: .utf8)!
        buffer.process(parser.parse(data))

        let spans = buffer.lines[0].attributedSpans()
        #expect(spans.count == 3)
        #expect(spans[0].text == "plain")
        #expect(spans[0].attributes.bold == false)
        #expect(spans[1].text == "bold")
        #expect(spans[1].attributes.bold == true)
        #expect(spans[2].text == "normal")
        #expect(spans[2].attributes.bold == false)
    }
}
