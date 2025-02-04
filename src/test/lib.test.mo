import Lexer "../Lexer";
import Parser "../Parser";
import Compiler "../Compiler";
import Types "../Types";
import Regex "../lib";
import Result "mo:base/Result";
import IC "mo:base/ExperimentalInternetComputer";

actor {
  type Pattern = Text;
  public func measurePatternInstructions(pattern : Text, input : Text) : async Nat64 {
    let count = IC.countInstructions(
      func() {
        let regex = Regex.Regex(pattern, null);
        ignore regex.match(input);
      }
    );
    return count;
  };
  public query func testLexer(t : Text) : async Result.Result<[Types.Token], Types.RegexError> {
    let lexer = Lexer.Lexer(t);
    lexer.tokenize();
  };

  public query func testParser(t : Text) : async Result.Result<Types.AST, Types.RegexError> {
    let lexer = Lexer.Lexer(t);
    switch (lexer.tokenize()) {
      case (#ok(tokens)) {
        let parser = Parser.Parser(tokens);
        parser.parse();
      };
      case (#err(error)) {
        #err(error);
      };
    };
  };
  public query func testCompiler(t : Text) : async Result.Result<Types.CompiledRegex, Types.RegexError> {
    let lexer = Lexer.Lexer(t);

    switch (lexer.tokenize()) {
      case (#err(error)) {
        #err((error));
      };
      case (#ok(tokens)) {
        let parser = Parser.Parser(tokens);
        switch (parser.parse()) {
          case (#err(error)) {
            #err((error));
          };
          case (#ok(ast)) {
            let compiler = Compiler.Compiler();
            switch (compiler.compile(ast)) {
              case (#err(error)) {
                #err((error));
              };
              case (#ok(compiledRegex)) {
                #ok(compiledRegex);
              };
            };
          };
        };
      };
    };
  };
  public query func testMatch(aregextext : Pattern, t : Text) : async Result.Result<Types.Match, Types.RegexError> {
    let regex = Regex.Regex(aregextext, null);
    regex.enableDebug(true);
    switch (regex.match(t)) {
      case (#ok(result)) {
        #ok(result);
      };
      case (#err(e)) {
        #err(e);
      };
    };
  };
  public query func testSearch(aregextext : Pattern, t : Text) : async Result.Result<Types.Match, Types.RegexError> {
    let regex = Regex.Regex(aregextext, null);
    regex.enableDebug(true);
    switch (regex.search(t)) {
      case (#ok(result)) {
        #ok(result);
      };
      case (#err(e)) {
        #err(e);
      };
    };
  };
  public query func testFindAll(aregextext : Pattern, t : Text) : async Result.Result<[Types.Match], Types.RegexError> {
    let regex = Regex.Regex(aregextext, null);
    switch (regex.findAll(t)) {
      case (#ok(matches)) {
        #ok(matches);
      };
      case (#err(e)) {
        #err(e);
      };
    };
  };
  public query func testSplit(aregextext : Pattern, t : Text, maxSplit : ?Nat) : async Result.Result<[Text], Types.RegexError> {
    let regex = Regex.Regex(aregextext, null);
    switch (regex.split(t, maxSplit)) {
      case (#ok(matches)) {
        #ok(matches);
      };
      case (#err(e)) {
        #err(e);
      };
    };
  };
  public query func testReplace(aregextext : Pattern, t : Text, replacement : Text, maxReplacement : ?Nat) : async Result.Result<Text, Types.RegexError> {
    let regex = Regex.Regex(aregextext, null);
    switch (regex.replace(t, replacement, maxReplacement)) {
      case (#ok(result)) {
        #ok(result);
      };
      case (#err(e)) {
        #err(e);
      };
    };
  };
  public func inspectNfa(pattern : Pattern) : async Result.Result<Text, Types.RegexError> {
    let regex = Regex.Regex(pattern, null);
    switch (regex.inspectRegex()) {
      case (#ok(result)) {
        #ok(result);
      };
      case (#err(e)) {
        #err(e);
      };
    };
  };
};
