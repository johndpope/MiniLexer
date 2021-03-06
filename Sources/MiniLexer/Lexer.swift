/// Class capable of parsing tokens out of a string.
/// Currently presents support to parse some simple time formats,
/// single/double-quoted strings, and floating point numbers.
public final class Lexer {
    
    public typealias Atom = UnicodeScalar
    public typealias Index = String.Index
    
    private var state: LexerState
    
    public let inputString: String
    
    @_versioned
    internal var inputSource: String.UnicodeScalarView {
        return inputString.unicodeScalars
    }
    
    public var inputIndex: Index {
        get {
            return state.index
        }
        set {
            state.index = newValue
        }
    }
    
    @_versioned
    internal let endIndex: Index
    
    public init(input: String) {
        state = LexerState(index: input.startIndex)
        
        inputString = input
        endIndex = inputString.endIndex
    }
    
    public init(input: String, index: Index) {
        state = LexerState(index: index)
        
        inputString = input
        endIndex = inputString.endIndex
    }
    
    /// Rewinds the input index to point to the start of the string
    public func rewindToStart() {
        inputIndex = inputString.startIndex
    }
    
    /// Advances the stream until the first non-whitespace character is found.
    @inline(__always)
    public func skipWhitespace() {
        advance(while: Lexer.isWhitespace)
    }
    
    /// Returns whether the current stream position points to the end of the input
    /// string.
    /// No further reading is possible when a stream is pointing to the end.
    @inline(__always)
    public func isEof() -> Bool {
        return inputIndex >= endIndex
    }
    
    /// Returns whether the current stream position + `offsetBy` points to past
    /// the end of the input string.
    @inline(__always)
    public func isEof(offsetBy: Int) -> Bool {
        guard let index = inputSource.index(inputIndex, offsetBy: offsetBy, limitedBy: endIndex) else {
            return true
        }
        
        return index >= endIndex
    }
    
    /// Returns whether the next char returns true when passed to the given predicate,
    /// This method is safe, since it checks isEoF before making the check call.
    @inline(__always)
    public func safeNextCharPasses(with predicate: (Atom) throws -> Bool) rethrows -> Bool {
        return try !isEof() && predicate(unsafePeek())
    }
    
    /// Returns whether the next char in the string the given char.
    /// This method is safe, since it checks isEoF before making the check call,
    /// and returns 'false' if EoF.
    @inline(__always)
    public func safeIsNextChar(equalTo char: Atom) -> Bool {
        return !isEof() && unsafePeek() == char
    }
    
    /// Returns whether the next char in the string the given char.
    /// This method is safe, since it checks isEoF before making the check call,
    /// and returns 'false' if EoF.
    @inline(__always)
    public func safeIsNextChar(equalTo char: Atom, offsetBy: Int) -> Bool {
        return !isEof(offsetBy: offsetBy) && unsafePeekForward(offsetBy: offsetBy) == char
    }
    
    /// Reads a single character from the current stream position, and forwards
    /// the stream by 1 unit.
    @inline(__always)
    public func next() throws -> Atom {
        let atom = try peek()
        unsafeAdvance()
        return atom
    }
    
    /// Peeks the current character at the current index
    @inline(__always)
    public func peek() throws -> Atom {
        if isEof() {
            throw endOfStringError()
        }
        
        return inputSource[inputIndex]
    }
    
    /// Peeks a character forward `count` characters from the current position.
    ///
    /// - precondition: `count > 0`
    /// - throws: `LexerError.endOfStringError`, if inputIndex + count >= endIndex
    @inline(__always)
    public func peekForward(count: Int = 1) throws -> Atom {
        precondition(count >= 0)
        guard let newIndex = inputSource.index(inputIndex, offsetBy: count, limitedBy: endIndex) else {
            throw endOfStringError()
        }
        
        return inputSource[newIndex]
    }
    
    /// Unsafe version of peek(), proper for usages where check of isEoF is
    /// preemptively made.
    @inline(__always)
    @_versioned
    internal func unsafePeek() -> Atom {
        return inputSource[inputIndex]
    }
    
    /// Unsafe version of peekForward(), proper for usages where check of isEoF is
    /// preemptively made.
    @inline(__always)
    @_versioned
    internal func unsafePeekForward(offsetBy: Int = 1) -> Atom {
        let newIndex = inputSource.index(inputIndex, offsetBy: offsetBy)
        return inputSource[newIndex]
    }
    
    /// Parses the string by applying a given grammar rule on this lexer at the
    /// current position.
    /// Throws, if operation fails.
    @_specialize(where G == GrammarRule)
    @_specialize(where G == RecursiveGrammarRule)
    @inline(__always)
    public func parse<G: LexerGrammarRule>(with rule: G) throws -> G.Result {
        return try rule.consume(from: self)
    }
    
    /// Performs discardable index changes inside a given closure.
    /// Any changes to this parser's state are undone after the method returns.
    @inline(__always)
    public func withTemporaryIndex<T>(changes: () throws -> T) rethrows -> T {
        let backtrack = backtracker()
        defer {
            backtrack.backtrack()
        }
        return try changes()
    }
    
    /// Attempts to perform throwable changes to the parser while inside a given
    /// closure. In case the changes fail, the state of the parser is rewind back
    /// and the error is rethrown.
    /// In case the `changes` block succeed, the method returns its return value
    /// and doesn't rewind.
    @inline(__always)
    public func rewindOnFailure<T>(changes: () throws -> T) rethrows -> T {
        let backtrack = backtracker()
        do {
            return try changes()
        } catch {
            backtrack.backtrack()
            throw error
        }
    }
    
    /// Performs an operation, retuning the index of the read head after the
    /// operation is completed.
    ///
    /// Can be used to record index after changes are made in conjunction to
    /// `withTemporaryIndex`
    @inline(__always)
    public func withIndexAfter<T>(performing changes: () throws -> T) rethrows -> (T, Lexer.Index) {
        return (try changes(), inputIndex)
    }
    
    /// Returns a backtracker that is able to return the state of this lexer back
    /// to the point at which this method was called.
    public func backtracker() -> Backtracker {
        return Backtracker(lexer: self)
    }
    
    // MARK: Character checking
    @inline(__always)
    public static func isDigit(_ c: Atom) -> Bool {
        return c >= "0" && c <= "9"
    }
    
    @inline(__always)
    public static func isWhitespace(_ c: Atom) -> Bool {
        return c == " " || c == "\r" || c == "\n" || c == "\t"
    }
    
    @inline(__always)
    public static func isLetter(_ c: Atom) -> Bool {
        return isLowercaseLetter(c) || isUppercaseLetter(c)
    }
    
    @inline(__always)
    public static func isLowercaseLetter(_ c: Atom) -> Bool {
        switch c {
        case "a"..."z":
            return true
            
        default:
            return false
        }
    }
    
    @inline(__always)
    public static func isUppercaseLetter(_ c: Atom) -> Bool {
        switch c {
        case "A"..."Z":
            return true
            
        default:
            return false
        }
    }
    
    @inline(__always)
    public static func isAlphanumeric(_ c: Atom) -> Bool {
        return isLetter(c) || isDigit(c)
    }
    
    // MARK: Error methods
    @inline(__always)
    public func unexpectedCharacterError(offset: Lexer.Index? = nil, char: Atom, _ message: String) -> Error {
        let offset = offset ?? inputIndex
        
        return LexerError.unexpectedCharacter(offset, char: char, message: message)
    }
    
    @inline(__always)
    public func unexpectedStringError(offset: Lexer.Index? = nil, _ message: String) -> Error {
        let offset = offset ?? inputIndex
        
        return LexerError.unexpectedString(offset, message: message)
    }
    
    @inline(__always)
    public func syntaxError(offset: Lexer.Index? = nil, _ message: String) -> Error {
        let offset = offset ?? inputIndex
        
        return LexerError.syntaxError(offset, message)
    }
    
    @inline(__always)
    public func endOfStringError(_ message: String = "Reached unexpected end of input string") -> Error {
        return LexerError.endOfStringError(message)
    }
    
    /// Allows backtracking changes to a Lexer's state
    public class Backtracker {
        private let lexer: Lexer
        private let state: LexerState
        
        init(lexer: Lexer) {
            self.lexer = lexer
            self.state = lexer.state
        }
        
        /// Backtracks the state of the lexer associated with this backtracker
        /// back to the point at which it was created.
        public func backtrack() {
            lexer.state = state
        }
    }
    
    private struct LexerState {
        var index: Lexer.Index
    }
    
    @_versioned
    internal static func lineNumber(at index: String.Index, in string: String) -> Int {
        let line =
            string[..<index].reduce(0) {
                $0 + ($1 == "\n" ? 1 : 0)
            }
        
        return line + 1 // lines start at one
    }
    
    @_versioned
    internal static func columnOffset(at index: String.Index, in string: String) -> Int {
        // Figure out start of line at the given index
        let lineStart =
            zip(string[..<index], string.indices)
                .reversed()
                .first { $0.0 == "\n" }?.1
        
        let lineStartOffset =
            lineStart.map(string.index(after:)) ?? string.startIndex
        
        return string.distance(from: lineStartOffset, to: index) + 1 // columns start at one
    }
}

// MARK: - Find/skip to next methods
extension Lexer {
    
    /// Returns the index of the next occurrence of a given input char.
    /// Method starts searching from current read index.
    /// This method does not alter the current
    @inline(__always)
    public func findNext(_ atom: Atom) -> Index? {
        return withTemporaryIndex {
            advance(until: { $0 == atom })
            
            if inputIndex != inputString.endIndex {
                return inputIndex
            }
            
            return nil
        }
    }
    
    /// Skips all chars until the next occurrence of a given char.
    /// Method starts searching from current read index.
    /// If the char is not found after the current index, an error is thrown.
    @inline(__always)
    public func skipToNext(_ atom: Atom) throws {
        guard let index = findNext(atom) else {
            throw LexerError.notFound("Expected \(atom) but it was not found.")
        }
        
        inputIndex = index
    }
}

public enum LexerError: Error {
    case unexpectedCharacter(Lexer.Index, char: Lexer.Atom, message: String)
    case unexpectedString(Lexer.Index, message: String)
    case syntaxError(Lexer.Index, String)
    case endOfStringError(String)
    case notFound(String)
    case miscellaneous(String)
    case genericParseError
}

extension LexerError: CustomStringConvertible {
    public func description(withOffsetsIn string: String) -> String {
        switch self {
        case let .unexpectedCharacter(offset, _, message: message),
             let .unexpectedString(offset, message: message),
             let .syntaxError(offset, message):
            let column = Lexer.columnOffset(at: offset, in: string)
            let line = Lexer.lineNumber(at: offset, in: string)
            
            return "Error at line \(line) column \(column): \(message)"
        case .endOfStringError(let message),
             .notFound(let message),
             .miscellaneous(let message):
            return "Error: \(message)"
        case .genericParseError:
            return "An internal error during parsing was raised"
        }
    }
    
    public var description: String {
        switch self {
        case let .unexpectedCharacter(_, _, message: message),
             let .unexpectedString(_, message: message),
             let .syntaxError(_, message):
            return "Error: \(message)"
        case .endOfStringError(let message),
             .notFound(let message),
             .miscellaneous(let message):
            return "Error: \(message)"
        case .genericParseError:
            return "An internal error during parsing was raised"
        }
    }
}
