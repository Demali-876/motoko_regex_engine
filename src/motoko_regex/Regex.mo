import Lexer "Lexer";
import Parser "Parser";
import Compiler "Compiler";
import Extensions "Extensions";
import Types "Types";
import Debug "mo:base/Debug";

actor {

    public query func testLexer(t: Text): async [Types.Token] {
        let lexer = Lexer.Lexer(t);
        lexer.tokenize();
    };

    public query func testParser(t: Text): async ?Types.AST {
    let lexer = Lexer.Lexer(t);
    let tokenResult = lexer.tokenize();
    let parser = Parser.Parser(tokenResult);
    
    switch (parser.parse()) {
        case (#ok(ast)) {
            ?ast
        };
        case (#err(error)) {
            Debug.print("Parser error: " # Extensions.errorToText(error));
            null
        };
    }
};

    public query func testCompiler(t: Text): async Types.CompiledRegex {
    let lexer = Lexer.Lexer(t);
    let tokenResult = lexer.tokenize();
    let parser = Parser.Parser(tokenResult);
    let astResult = parser.parse();
    
    switch (astResult) {
        case (#ok(ast)) {
            let compiler = Compiler.Compiler();
            compiler.compile(ast);
        };
        case (#err(error)) {
            Debug.print("Compiler error: " # Extensions.errorToText(error));
            {
                transitions = [];
                startState = 0;
                acceptStates = [];
            };
        };
    }
};

};

