import Lexer "../Lexer";
import Parser "../Parser";
import Compiler "../Compiler";
import Result "mo:base/Result";
import Extensions "../Extensions";
import Types "../Types";
import Debug "mo:base/Debug";

actor {
    type Token = Types.Token;
    type LexerError = Lexer.LexerError;
    type ParserError = Parser.ParserError;
    type AST = Types.AST;

    public query func testLexer(t: Text): async Result.Result<[Token], LexerError>{
        let lexer = Lexer.Lexer(t);
        lexer.tokenize();
    };

    public query func testParser(t: Text): async Result.Result<AST, ParserError> {
    let lexer = Lexer.Lexer(t);
    switch (lexer.tokenize()) {
        case (#ok(tokens)) {
            let parser = Parser.Parser(tokens);
            parser.parse();
        }; 
        case (#err(error)) {
            #err(error)
            };
        }
    };
  /*public query func testCompiler(t :Text): async Result.Result<Types.CompiledRegex,Error> {
    let lexer = Lexer.Lexer(t);
    let tokenResult = switch (lexer.tokenize()){
        case (#ok(tokens)){
            let parser = Parser.Parser(tokens);
            switch (parser.parse()) {
        case (#ok(ast)) {
            let compiler = Compiler.Compiler();
            switch (compiler.compile(ast)){
                case (#ok(compiledRegex)) {
                    compiledRegex
                };
                case (#err(error)) {
                    Debug.trap("Compiler error: " # Extensions.errorToText(error));
                };
            }
        };
        case (#err(error)) {
            Debug.trap("Parser error: " # Extensions.errorToText(error));
        };
        };
        };
        case(#err(error)){

        };
    };
    }*/
};
