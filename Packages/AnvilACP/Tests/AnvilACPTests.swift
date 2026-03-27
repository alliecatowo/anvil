import XCTest
@testable import AnvilACP
import AnvilDomain

final class AnvilACPTests: XCTestCase {
    func testTokenCounterEstimation() {
        let counter = TokenCounter()
        let tokens = counter.estimateTokens("Hello, world!")
        XCTAssertGreaterThan(tokens, 0)
    }

    func testCostCalculation() {
        let calc = CostCalculator()
        let model = ACPModel(id: "test", name: "Test", provider: "test", contextWindow: 100000, inputCostPer1kTokens: 0.01, outputCostPer1kTokens: 0.03, capabilities: [])
        let cost = calc.calculate(inputTokens: 1000, outputTokens: 500, model: model)
        XCTAssertEqual(cost, Decimal(string: "0.025")!)
    }

    func testToolRegistryOperations() async {
        let registry = ToolRegistry()
        await registry.register(FileTools.readFile)
        await registry.register(FileTools.writeFile)
        let all = await registry.allTools()
        XCTAssertEqual(all.count, 2)
        let readTool = await registry.tool("read_file")
        XCTAssertNotNil(readTool)
    }

    func testACPClientProviderRegistration() async {
        let client = ACPClient()
        let provider = OllamaProvider()
        await client.registerProvider(provider)
        let p = await client.provider("ollama")
        XCTAssertNotNil(p)
    }
}
