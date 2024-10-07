import Lexer "Lexer";
import Parser "Parser";
import Compiler "Compiler";
import Types "Types";

actor {

    public query func testLexer(t: Text): async [Types.Token] {
        let lexer = Lexer.Lexer(t);
        lexer.tokenize();
    };

    /*public query func testParser(t: Text): async ?Types.AST {
        let lexer = Lexer.Lexer(t);
        let tokenResult = lexer.tokenize();
        let parser = Parser.Parser(tokenResult);
        parser.parse();
    };

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
                {
                    transitions = [];
                    startState = 0;
                    acceptStates = [];
                    captureGroups = [];
                };
            };
        };
    };*/
};

