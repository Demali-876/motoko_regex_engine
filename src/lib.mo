import Types "Types";
import Result "mo:base/Result";
import Lexer "Lexer";
import Parser "Parser";
import Compiler "Compiler";
import Matcher "Matcher";
import Iter "mo:base/Iter";
import Debug "mo:base/Debug";
import Formatter "Formatter";

module {
  public type Pattern = Text;
  public type NFA = Types.CompiledRegex;
  public type Match = Types.Match;
  public type Flags = Types.Flags;
  public type RegexError = Types.RegexError;

  public class Regex(pattern : Pattern, flags : ?Flags) {
    private var compiler = Compiler.Compiler();
    private var lexer = Lexer.Lexer(pattern);
    private var matcher = Matcher.Matcher();
    private var nfa : ?NFA = null;

    ignore do {
      label compilation {
        let tokens = switch (lexer.tokenize()) {
          case (#ok(tokens)) tokens;
          case (#err(e)) {
            nfa := null;
            Debug.print("Compilation failed during tokenization: " # debug_show (e));
            break compilation;
          };
        };

        let parser = Parser.Parser(tokens);
        let ast = switch (parser.parse()) {
          case (#ok(ast)) ast;
          case (#err(e)) {
            nfa := null;
            Debug.print("Compilation failed during parsing: " # debug_show (e));
            break compilation;
          };
        };
        switch (compiler.compile(ast)) {
          case (#ok(compiledNFA)) nfa := ?compiledNFA;
          case (#err(e)) {
            nfa := null;
            Debug.print("Compilation failed during NFA construction: " # debug_show (e));
          };
        };
      };
    };

    public func match(text : Text) : Result.Result<Match, RegexError> {
      switch (nfa) {
        case (null) #err(#NotCompiled);
        case (?compiledNFA) {
          matcher.match(compiledNFA, text, flags);
        };
      };
    };
    public func search(text : Text) : Result.Result<Match, RegexError> {
      switch (nfa) {
        case (null) #err(#NotCompiled);
        case (?compiledNFA) {
          matcher.search(compiledNFA, text, flags);
        };
      };
    };
    public func findAll(text : Text) : Result.Result<[Match], RegexError> {
      switch (nfa) {
        case (null) #err(#NotCompiled);
        case (?compiledNFA) {
          matcher.findAll(compiledNFA, text, flags);
        };
      };
    };
    public func findIter(text : Text) : Result.Result<Iter.Iter<Match>, RegexError> {
      switch (nfa) {
        case (null) #err(#NotCompiled);
        case (?compiledNFA) {
          matcher.findIter(compiledNFA, text, flags);
        };
      };
    };
    public func inspectRegex() : Result.Result<Text, RegexError> {
      switch (nfa) {
        case (null) #err(#NotCompiled);
        case (?compiledNFA) #ok(Formatter.formatNFA(compiledNFA));
      };
    };
    public func inspectState(state : Types.State) : Result.Result<Text, RegexError> {
      switch (nfa) {
        case (null) #err(#NotCompiled);
        case (?compiledNFA) {
          switch (matcher.inspect(state, compiledNFA)) {
            case (#err(e)) #err(e);
            case (#ok(transitions)) {
              #ok(Formatter.formatStateTransitions(state, transitions));
            };
          };
        };
      };
    };
    public func split(text : Text, maxSpilt : ?Nat) : Result.Result<[Text], RegexError> {
      switch (nfa) {
        case (null) #err(#NotCompiled);
        case (?compiledNFA) {
          matcher.split(compiledNFA, text, maxSpilt, flags);
        };
      };
    };
    public func replace(text : Text, replacement : Text, maxReplacements : ?Nat) : Result.Result<Text, RegexError> {
      switch (nfa) {
        case (null) #err(#NotCompiled);
        case (?compiledNFA) {
          matcher.replace(compiledNFA, text, replacement, maxReplacements, flags);
        };
      };
    };
    public func sub(text : Text, replacement : Text, maxSubstitutions : ?Nat) : Result.Result<Text, RegexError> {
      switch (nfa) {
        case (null) #err(#NotCompiled);
        case (?compiledNFA) {
          matcher.sub(compiledNFA, text, replacement, maxSubstitutions, flags);
        };
      };
    };
    public func enableDebug(b : Bool) {
      matcher.debugMode(b);
    };
  };
};
