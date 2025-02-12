import { test; suite; expect } "mo:test";
import Bool "mo:base/Bool";
import Text "mo:base/Text";
import Result "mo:base/Result";
import Lexer "../src/Lexer";
import Types "../src/Types";

let tokenizeCases : [(Text, Result.Result<[Types.Token], Types.RegexError>)] = [
  ("a", #ok([{ tokenType = #Character('a'); value = "a"; position = #Instance(0) }])),
  ("a+", #ok([{ tokenType = #Character('a'); value = "a"; position = #Instance(0) }, { tokenType = #Quantifier({ min = 1; max = null; mode = #Greedy }); value = "+"; position = #Instance(1) }])),
  ("a*", #ok([{ tokenType = #Character('a'); value = "a"; position = #Instance(0) }, { tokenType = #Quantifier({ min = 0; max = null; mode = #Greedy }); value = "*"; position = #Instance(1) }])),
  ("a?", #ok([{ tokenType = #Character('a'); value = "a"; position = #Instance(0) }, { tokenType = #Quantifier({ min = 0; max = ?1; mode = #Greedy }); value = "?"; position = #Instance(1) }])),
  ("a{1,2}", #ok([{ tokenType = #Character('a'); value = "a"; position = #Instance(0) }, { tokenType = #Quantifier({ min = 1; max = ?2; mode = #Greedy }); value = "{1,2}"; position = #Instance(5) }])),
  ("a{1,}", #ok([{ tokenType = #Character('a'); value = "a"; position = #Instance(0) }, { tokenType = #Quantifier({ min = 1; max = null; mode = #Greedy }); value = "{1,}"; position = #Instance(4) }])),
  ("a{1}", #ok([{ tokenType = #Character('a'); value = "a"; position = #Instance(0) }, { tokenType = #Quantifier({ min = 1; max = ?1; mode = #Greedy }); value = "{1}"; position = #Instance(3) }])),
  ("a{1,2}?", #ok([{ tokenType = #Character('a'); value = "a"; position = #Instance(0) }, { tokenType = #Quantifier({ min = 1; max = ?2; mode = #Lazy }); value = "{1,2}?"; position = #Instance(6) }])),
  ("ab", #ok([{ tokenType = #Character('a'); value = "a"; position = #Instance(0) }, { tokenType = #Character('b'); value = "b"; position = #Instance(1) }])),
  ("a+?", #ok([{ tokenType = #Character('a'); value = "a"; position = #Instance(0) }, { tokenType = #Quantifier({ min = 1; max = null; mode = #Lazy }); value = "+?"; position = #Instance(2) }])),
  ("[abc]", #ok([{ tokenType = #CharacterClass(false, [#Single('a'), #Single('b'), #Single('c')]); value = "[abc]"; position = #Instance(4) }])),
  ("(a|b)", #ok([{ tokenType = #Group({ modifier = null; subTokens = [{ tokenType = #Character('a'); value = "a"; position = #Instance(1) }, { tokenType = #Alternation; value = "|"; position = #Instance(2) }, { tokenType = #Character('b'); value = "b"; position = #Instance(3) }]; quantifier = null; name = null }); value = "(a|b)"; position = #Span(0, 4) }])),
  ("\\d+", #ok([{ tokenType = #Metacharacter(#Digit); value = "\\d"; position = #Instance(0) }, { tokenType = #Quantifier({ min = 1; max = null; mode = #Greedy }); value = "+"; position = #Instance(2) }])),
  ("\\+", #ok([{ tokenType = #Character('+'); value = "\\+"; position = #Instance(1) }])),
  ("\\*", #ok([{ tokenType = #Character('*'); value = "\\*"; position = #Instance(1) }])),
  ("\\?", #ok([{ tokenType = #Character('?'); value = "\\?"; position = #Instance(1) }])),
  ("[a-z]", #ok([{ tokenType = #CharacterClass(false, [#Range('a', 'z')]); value = "[a-z]"; position = #Instance(4) }])),
  ("[0-9]", #ok([{ tokenType = #CharacterClass(false, [#Range('0', '9')]); value = "[0-9]"; position = #Instance(4) }])),
  ("[^abc]", #ok([{ tokenType = #CharacterClass(true, [#Single('a'), #Single('b'), #Single('c')]); value = "[^abc]"; position = #Instance(5) }])),
  ("[^a-z]", #ok([{ tokenType = #CharacterClass(true, [#Range('a', 'z')]); value = "[^a-z]"; position = #Instance(5) }])),
  ("[a-z0-9_]", #ok([{ tokenType = #CharacterClass(false, [#Range('a', 'z'), #Range('0', '9'), #Single('_')]); value = "[a-z0-9_]"; position = #Instance(8) }])),
  ("\\w+", #ok([{ tokenType = #Metacharacter(#WordChar); value = "\\w"; position = #Instance(0) }, { tokenType = #Quantifier({ min = 1; max = null; mode = #Greedy }); value = "+"; position = #Instance(2) }])),
  ("\\s*", #ok([{ tokenType = #Metacharacter(#Whitespace); value = "\\s"; position = #Instance(0) }, { tokenType = #Quantifier({ min = 0; max = null; mode = #Greedy }); value = "*"; position = #Instance(2) }])),
  ("(abc)+", #ok([{ tokenType = #Group({ modifier = null; subTokens = [{ tokenType = #Character('a'); value = "a"; position = #Instance(1) }, { tokenType = #Character('b'); value = "b"; position = #Instance(2) }, { tokenType = #Character('c'); value = "c"; position = #Instance(3) }]; quantifier = null; name = null }); value = "(abc)"; position = #Span(0, 4) }, { position = #Instance(5); tokenType = #Quantifier({ max = null; min = 1; mode = #Greedy }); value = "+" }])),
  ("(a(bc)d)", #ok([{ tokenType = #Group({ modifier = null; subTokens = [{ tokenType = #Character('a'); value = "a"; position = #Instance(1) }, { tokenType = #Group({ modifier = null; subTokens = [{ tokenType = #Character('b'); value = "b"; position = #Instance(3) }, { tokenType = #Character('c'); value = "c"; position = #Instance(4) }]; quantifier = null; name = null }); value = "(bc)"; position = #Span(2, 5) }, { tokenType = #Character('d'); value = "d"; position = #Instance(6) }]; quantifier = null; name = null }); value = "(a(bc)d)"; position = #Span(0, 7) }])),
  ("(cat|dog|fish)", #ok([{ tokenType = #Group({ modifier = null; subTokens = [{ tokenType = #Character('c'); value = "c"; position = #Instance(1) }, { tokenType = #Character('a'); value = "a"; position = #Instance(2) }, { tokenType = #Character('t'); value = "t"; position = #Instance(3) }, { tokenType = #Alternation; value = "|"; position = #Instance(4) }, { tokenType = #Character('d'); value = "d"; position = #Instance(5) }, { tokenType = #Character('o'); value = "o"; position = #Instance(6) }, { tokenType = #Character('g'); value = "g"; position = #Instance(7) }, { tokenType = #Alternation; value = "|"; position = #Instance(8) }, { tokenType = #Character('f'); value = "f"; position = #Instance(9) }, { tokenType = #Character('i'); value = "i"; position = #Instance(10) }, { tokenType = #Character('s'); value = "s"; position = #Instance(11) }, { tokenType = #Character('h'); value = "h"; position = #Instance(12) }]; quantifier = null; name = null }); value = "(cat|dog|fish)"; position = #Span(0, 13) }])),
  ("[a-]", #err(#GenericError("Incomplete range at position 3"))),
  ("(abc", #err(#GenericError("Unclosed group at position 4"))),
  ("[abc", #err(#GenericError("Unclosed character class at position 0"))),
  ("^/index\\.htm$", #ok([{ position = #Instance(0); tokenType = #Anchor(#StartOfString); value = "^" }, { position = #Instance(1); tokenType = #Character('/'); value = "/" }, { position = #Instance(2); tokenType = #Character('i'); value = "i" }, { position = #Instance(3); tokenType = #Character('n'); value = "n" }, { position = #Instance(4); tokenType = #Character('d'); value = "d" }, { position = #Instance(5); tokenType = #Character('e'); value = "e" }, { position = #Instance(6); tokenType = #Character('x'); value = "x" }, { position = #Instance(8); tokenType = #Character('.'); value = "\\." }, { position = #Instance(9); tokenType = #Character('h'); value = "h" }, { position = #Instance(10); tokenType = #Character('t'); value = "t" }, { position = #Instance(11); tokenType = #Character('m'); value = "m" }, { position = #Instance(12); tokenType = #Anchor(#EndOfString); value = "$" }]))
  // Broken tests
  // ("{1}", #err(#InvalidQuantifier("Quantifier without preceding token"))),
  // ("a{0}", #err(#InvalidQuantifier("Min quantifier must be greater than 0"))),
  // ("a{5,3}", #err(#InvalidQuantifier("Max quantifier must be greater than min"))),

];

for ((value, expected) in tokenizeCases.vals()) {
  test(
    "tokenize - Value: " # value,
    func() {
      let lexer = Lexer.Lexer(value);
      let result = lexer.tokenize();

      expect.result<[Types.Token], Types.RegexError>(
        result,
        func(t : Result.Result<[Types.Token], Types.RegexError>) : Text = debug_show (t),
        func(x : Result.Result<[Types.Token], Types.RegexError>, y : Result.Result<[Types.Token], Types.RegexError>) : Bool = x == y,
      ).equal(expected);
    },
  );
};
