import Types "Types";
import Result "mo:base/Result";
import Lexer "Lexer";
import Parser "Parser";
import Compiler "Compiler";
import Matcher "Matcher";
import Iter "mo:base/Iter";
import Debug "mo:base/Debug";

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
      label compilation {
        let tokens = switch(lexer.tokenize()) {
          case (#ok(tokens)) tokens;
          case (#err(e)) {
            nfa := null;
            Debug.print("Compilation failed during tokenization: " # debug_show(e));
            break compilation;
          };
        };

        let parser = Parser.Parser(tokens);
        let ast = switch(parser.parse()) {
          case (#ok(ast)) ast;
          case (#err(e)) {
            nfa := null;
            Debug.print("Compilation failed during parsing: " # debug_show(e));
            break compilation;
          };
        };
        switch(compiler.compile(ast)) {
          case (#ok(compiledNFA)) nfa := ?compiledNFA;
          case (#err(e)) {
            nfa := null;
            Debug.print("Compilation failed during NFA construction: " # debug_show(e));
          };
        };
      };
    };

    public func match(text: Text): Result.Result<Match, RegexError> {
      switch (nfa) {
        case (null) #err(#NotCompiled);
        case (?compiledNFA) {
          matcher.match(compiledNFA, text, flags)
        };
      }
    };
    public func search(text: Text): Result.Result<Match, RegexError> {
      switch (nfa) {
        case (null) #err(#NotCompiled);
        case (?compiledNFA) {
          matcher.search(compiledNFA, text, flags)
        };
      }
    };
    public func findAll(text: Text): Result.Result<[Match], RegexError> {
      switch (nfa) {
        case (null) #err(#NotCompiled);
        case (?compiledNFA) {
          matcher.findAll(compiledNFA, text, flags)
        };
      }
    };
    public func findIter(text: Text): Result.Result<Iter.Iter<Match>, RegexError> {
      switch (nfa) {
        case (null) #err(#NotCompiled);
        case (?compiledNFA) {
          matcher.findIter(compiledNFA, text, flags)
        };
      }
    };
    public func enableDebug(b:Bool){
      matcher.debugMode(b);
    }
  };
};
