import Lexer "../Lexer";
import Parser "../Parser";
import Compiler "../Compiler";
import Result "mo:base/Result";
import Extensions "../Extensions";
import Types "../Types";
import Debug "mo:base/Debug";
import Regex "../lib"

actor {
    type Token = Types.Token;
    type LexerError = Lexer.LexerError;
    type ParserError = Parser.ParserError;
    type CompilerError = Compiler.CompilerError;
    type AST = Types.AST;
    

    public query func testLexer(t: Text): async Result.Result<[Types.Token], Types.RegexError>{
        let lexer = Lexer.Lexer(t);
        lexer.tokenize();
    };

    public query func testParser(t: Text): async Result.Result<Types.AST, Types.RegexError> {
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
  public query func testCompiler(t :Text): async Result.Result<Types.CompiledRegex,Types.RegexError> {
    let lexer = Lexer.Lexer(t);
    
    switch (lexer.tokenize()) {
        case (#err(error)) {
            #err((error))
        };
        case (#ok(tokens)) {
            let parser = Parser.Parser(tokens);
            switch (parser.parse()) {
                case (#err(error)) {
                    #err((error))
                };
                case (#ok(ast)) {
                    let compiler = Compiler.Compiler();
                    switch (compiler.compile(ast)) {
                        case (#err(error)) {
                            #err((error))
                        };
                        case (#ok(compiledRegex)) {
                            #ok(compiledRegex)
                        };
                    }
                };
            }
        };
    };
  };
  public query func testMatch(): async Result.Result<Types.Match, Types.RegexError> {
    let regex = Regex.Regex("abc", null);
    switch(regex.match("abcdef")) {
        case (#ok(result)) {
            #ok(result)
        };
        case (#err(e)) {
            #err(e)
        };
    };
};
};
