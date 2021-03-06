import XCTest
import MiniLexer

class TokenizerTests: XCTestCase {
    var sut: TokenizerLexer<TestToken>!
    
    func testInitWithLexer() {
        let lexer = Lexer(input: "()")
        sut = TokenizerLexer(lexer: lexer)
        
        XCTAssert(sut.lexer === lexer)
    }
    
    func testTokenizeStream() {
        sut = TokenizerLexer(input: "()")
        
        XCTAssertEqual(sut.nextToken().tokenType, .openParens)
        XCTAssertEqual(sut.nextToken().tokenType, .closeParens)
        XCTAssertEqual(sut.nextToken().tokenType, .eof)
    }
    
    func testTokenizeEofOnEmptyString() {
        sut = TokenizerLexer(input: "")
        
        XCTAssertEqual(sut.nextToken().tokenType, .eof)
    }
    
    func testSkipToken() {
        sut = TokenizerLexer(input: "()")
        
        sut.skipToken()
        
        XCTAssertEqual(sut.nextToken().tokenType, .closeParens)
    }
    
    func testToken() {
        sut = TokenizerLexer(input: "()")
        
        let token = sut.token()
        
        XCTAssertEqual(token.value, "(")
        XCTAssertEqual(token.tokenType, .openParens)
    }
    
    func testTokenIsType() {
        sut = TokenizerLexer(input: "(")
        
        XCTAssert(sut.tokenType(is: .openParens))
    }
    
    func testConsumeTokenIfTypeIsMatching() {
        sut = TokenizerLexer(input: "(")
        
        let result = sut.consumeToken(ifTypeIs: .openParens)
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.value, "(")
        XCTAssertEqual(result?.tokenType, .openParens)
        XCTAssertEqual(result?.range, "(".startIndex..<"(".endIndex)
        XCTAssert(sut.isEof)
    }
    
    func testConsumeTokenIfTypeIsNonMatching() {
        sut = TokenizerLexer(input: "(")
        
        XCTAssertNil(sut.consumeToken(ifTypeIs: .closeParens))
        XCTAssertFalse(sut.isEof)
    }
    
    func testBacktracker() {
        sut = TokenizerLexer(input: "(,)")
        let bt = sut.backtracker()
        sut.skipToken()
        sut.skipToken()
        
        bt.backtrack()
        
        XCTAssertEqual(sut.token().tokenType, .openParens)
    }
    
    func testBacktrackerWontWorkTwice() {
        sut = TokenizerLexer(input: "(,)")
        let bt = sut.backtracker()
        sut.skipToken()
        bt.backtrack()
        sut.skipToken()
        
        bt.backtrack()
        
        XCTAssertEqual(sut.token().tokenType, .comma)
    }
    
    func testBacktrackerWontEraseHasReadFirstTokenState() throws {
        sut = TokenizerLexer(input: "(")
        let bt = sut.backtracker()
        sut.skipToken()
        
        bt.backtrack()
        
        try sut.advance(over: .openParens) // Should not throw error!
    }
    
    func testAdvanceOver() throws {
        sut = TokenizerLexer(input: "(,)")
        
        XCTAssertEqual(try sut.advance(over: .openParens).tokenType, .openParens)
        
        XCTAssertEqual(sut.token().tokenType, .comma)
    }
    
    func testAdvanceOverFailed() {
        sut = TokenizerLexer(input: "(,)")
        
        XCTAssertThrowsError(try sut.advance(over: .comma))
    }
    
    func testAdvanceOverErrorMessage() {
        sut = TokenizerLexer(input: "(,)")
        
        do {
            try sut.advance(over: .comma)
            XCTFail("Should have thrown")
        } catch let error as LexerError {
            XCTAssertEqual(error.description(withOffsetsIn: sut.lexer.inputString),
                           "Error at line 1 column 1: Expected token ',' but found '('")
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
    
    func testAdvanceMatching() throws {
        sut = TokenizerLexer(input: "(,)")
        
        XCTAssertEqual(try sut.advance(matching: { $0 == .openParens }).tokenType, .openParens)
        
        XCTAssertEqual(sut.token().tokenType, .comma)
    }
    
    func testAdvanceMatchingFailed() {
        sut = TokenizerLexer(input: "(,)")
        
        XCTAssertThrowsError(try sut.advance(matching: { $0 == .comma }))
    }
    
    func testBacktracking() {
        sut = TokenizerLexer(input: "(,)")
        
        sut.backtracking {
            sut.skipToken()
            sut.skipToken()
        }
        
        XCTAssertEqual(sut.token().tokenType, .openParens)
    }
    
    func testBacktrackingWorksWithErrorsThrown() {
        sut = TokenizerLexer(input: "(,)")
        
        do {
            try sut.backtracking {
                sut.skipToken()
                try sut.advance(over: .openParens)
            }
            
            XCTFail("Should have thrown error")
        } catch {
            //
        }
        
        XCTAssertEqual(sut.token().tokenType, .openParens)
        XCTAssertEqual(sut.lexer.inputIndex, sut.lexer.inputString.startIndex)
    }
    
    func testAllTokens() {
        sut = TokenizerLexer(input: "(,)")
        
        let tokens = sut.allTokens().map { $0.tokenType }
        
        XCTAssertEqual(tokens, [.openParens, .comma, .closeParens])
    }
    
    func testAllTokensSpaced() {
        sut = TokenizerLexer(input: " ( , ) ")
        
        let tokens = sut.allTokens().map { $0.tokenType }
        
        XCTAssertEqual(tokens, [.openParens, .comma, .closeParens])
    }
    
    func testAdvanceUntil() {
        sut = TokenizerLexer(input: "(,)")
        
        sut.advance(until: { $0.tokenType == .closeParens })
        
        XCTAssertEqual(sut.token().tokenType, .closeParens)
    }
    
    func testAdvancesUntilStopsAtEndOfFile() {
        sut = TokenizerLexer(input: "(,)")
        
        sut.advance(until: { _ in false })
        
        XCTAssertEqual(sut.token().tokenType, .eof)
    }
    
    func testTokenMatches() {
        sut = TokenizerLexer(input: "(")
        
        XCTAssert(sut.tokenType(matches: { $0 == .openParens }))
        XCTAssertFalse(sut.tokenType(matches: { $0 == .closeParens }))
    }
    
    func testTokenMatchesWithEmptyString() {
        sut = TokenizerLexer(input: "")
        
        XCTAssert(sut.tokenType(matches: { $0 == .eof }))
        XCTAssertFalse(sut.tokenType(matches: { $0 == .closeParens }))
    }
    
    func testTokenizerConsistencyWhenLexerIndexIsModifiedExternally() throws {
        sut = TokenizerLexer(input: "(,)")
        _=sut.token()
        
        try sut.lexer.advanceLength(1)
        
        XCTAssertEqual(sut.token().value, ",")
        XCTAssertEqual(sut.token().tokenType, .comma)
        XCTAssertEqual(sut.token().range, sut.lexer.inputString.index("(,)".startIndex, offsetBy: 1)..<"(,".endIndex)
    }
    
    func testMakeIterator() throws {
        sut = TokenizerLexer(input: "(,,)")
        
        let iterator = sut.makeIterator()
        
        XCTAssertEqual(iterator.next()?.value, "(")
        XCTAssertEqual(iterator.next()?.value, ",")
        XCTAssertEqual(iterator.next()?.value, ",")
        XCTAssertEqual(iterator.next()?.value, ")")
        XCTAssertNil(iterator.next())
    }
}

enum TestToken: String, TokenProtocol {
    case openParens = "("
    case comma = ","
    case closeParens = ")"
    case eof = ""
    
    static var eofToken = TestToken.eof
    
    var tokenString: String {
        switch self {
        case .openParens:
            return "("
        case .comma:
            return ","
        case .closeParens:
            return ")"
        case .eof:
            return ""
        }
    }
    
    static func tokenType(at lexer: Lexer) -> TestToken? {
        if lexer.safeIsNextChar(equalTo: "(") {
            return .openParens
        }
        if lexer.safeIsNextChar(equalTo: ",") {
            return .comma
        }
        if lexer.safeIsNextChar(equalTo: ")") {
            return .closeParens
        }
        return nil
    }
    
    func length(in lexer: Lexer) -> Int {
        switch self {
        case .openParens, .closeParens, .comma:
            return 1
        case .eof:
            return 0
        }
    }
}
