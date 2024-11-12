import Types "Types";
import Result "mo:base/Result";
import Lexer "Lexer";
import Parser "Parser";
import Compiler "Compiler";
import Matcher "Matcher";

module {
  type Pattern = Text;
  type NFA = Types.CompiledRegex;
  type Match = Types.Match;
  type Flags = Types.Flags;
  type RegexError = Types.RegexError;
  

  public class Regex(pattern: Pattern, flags: ?Flags) {
    private var compiler = Compiler.Compiler();
    private var lexer = Lexer.Lexer(pattern);
    private var matcher = Matcher.Matcher();
    private var nfa: ?NFA = null;

    ignore do {
      label compilation
      {
        let tokens = switch(lexer.tokenize()) {
          case (#ok(tokens)) tokens;
          case (#err(_)) { 
            nfa := null;
            break compilation;
          };
        };
        let parser = Parser.Parser(tokens);
        let ast = switch(parser.parse()) {
          case (#ok(ast)) ast;
          case (#err(_)) {
            nfa := null;
            break compilation;
          };
        };

        switch(compiler.compile(ast)) {
          case (#ok(compiledNFA)) nfa := ?compiledNFA;
          case (#err(_)) nfa := null;
        };
      };
    };

    public func match(text: Text): Result.Result<Match, RegexError> {
      switch(nfa) {
        case (null) #err(#NotCompiled);
        case (?compiledNFA) {
          matcher.match(compiledNFA, text, flags)
        };
      }
    };
  };
};