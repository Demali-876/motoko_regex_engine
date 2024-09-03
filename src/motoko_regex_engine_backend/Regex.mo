import Lexer "Lexer";
import Parser "Parser";
import Compiler "Compiler";
import Types "Types";

actor {
    // Test the Lexer
    public query func testLexer(t: Text): async [Types.Token] {
        let lexer = Lexer.Lexer(t);
        lexer.tokenize();
    };

    // Test the Parser
    public query func testParser(t: Text): async ?Types.AST {
        let lexer = Lexer.Lexer(t);
        let tokenResult = lexer.tokenize();
        let parser = Parser.Parser(tokenResult);
        parser.parse();
    };

    // Test the Compiler
    public query func testCompiler(t: Text): async Types.CompiledRegex {
        let lexer = Lexer.Lexer(t);
        let tokenResult = lexer.tokenize();
        let parser = Parser.Parser(tokenResult);
        let astResult = parser.parse();
        
        switch (astResult) {
            case (?ast) {
                let compiler = Compiler.Compiler();
                compiler.compile(ast);
            };
            case null {
                // Return an empty compiled regex if parsing fails
                {
                    transitions = [];
                    startState = 0;
                    acceptStates = [];
                    captureGroups = [];
                };
            };
        };
    };
};

