import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Array "mo:base/Array";
import Int "mo:base/Int";
import Result "mo:base/Result";
import Buffer "mo:base/Buffer";
import Types "Types";
import Extensions "Extensions";
import Cursor "Cursor";

module {
  type Token = Types.Token;
  public type LexerError = Types.RegexError;
  type CharacterClass = Types.CharacterClass;

  public class Lexer(input: Text) {
    let cursor = Cursor.Cursor(input);
    let tokenBuffer = Buffer.Buffer<Token>(16);

    public func tokenize(): Result.Result<[Token], LexerError> {
      while (cursor.hasNext()) {
        switch (nextToken()) {
          case (#ok(token)) {
            tokenBuffer.add(token);
          };
          case (#err(error)) {
            return #err(error);
          };
        };
      };
      #ok(Buffer.toArray(tokenBuffer))
    };

    private func nextToken(): Result.Result<Token, LexerError> {
      switch (cursor.current()) {
        case (char) {
          let token = switch char {
            case '.' {
              cursor.inc();
              createToken(#Metacharacter(#Dot), ".")
            };
            case '^' {
              if (cursor.getPos() == 0) {
                cursor.inc();
                createToken(#Anchor(#StartOfString), "^")
              } else {
                cursor.inc();
                createToken(#Character(char), Text.fromChar(char))
              }
            };
            case '$' {
              cursor.inc();
              createToken(#Anchor(#EndOfString), "$")
            };
            case '|' {
              cursor.inc();
              createToken(#Alternation, "|")
            };
            case _ {
              // Default case for characters
              if (char != '\\' and char != '(' and char != '[' and char != '*' and char != '+' and char != '?' and char != '{') {
                cursor.inc();
                createToken(#Character(char), Text.fromChar(char))
              } else {
                // Tokens that require special handling
                switch char {
                  case '*' { tokenizeQuantifier(0, null) };
                  case '+' { tokenizeQuantifier(1, null) };
                  case '?' { tokenizeQuantifier(0, ?1) };
                  case '(' { tokenizeGroup() };
                  case '[' { tokenizeCharacterClass() };
                  case '\\' { tokenizeEscapedChar() };
                  case '{' { tokenizeQuantifierRange() };
                  case _ {
                    #err(#GenericError("Unexpected character '" # Text.fromChar(char) # "' at position " # Nat.toText(cursor.getPos())))
                  };
                }
              }
            };
          };
          token
        };
      }
    };

    private func createToken(tokenType: Types.TokenType, value: Text): Result.Result<Token, LexerError> {
      #ok({
        tokenType = tokenType;
        value = value;
        position = #Instance(cursor.getPos() - 1);
      })
    };

    private func tokenizeQuantifier(min: Nat, max: ?Nat): Result.Result<Token, LexerError> {
      let start = cursor.getPos();
      cursor.inc(); // Consume the quantifier character

      let mode = if (cursor.hasNext()) {
        switch (cursor.current()) {
          case '?' { cursor.inc(); #Lazy };
          case '+' { cursor.inc(); #Possessive };
          case _ { #Greedy };
        }
      } else {
        #Greedy
      };

      createToken(#Quantifier({ min; max; mode }), Extensions.slice(input, start, ?cursor.getPos()))
    };

    private func tokenizeQuantifierRange(): Result.Result<Token, LexerError> {
      let start = cursor.getPos();
      cursor.inc(); // Consume the opening '{'

      var rangeContent = "";
      while (cursor.hasNext() and cursor.current() != '}') {
        rangeContent := rangeContent # Text.fromChar(cursor.current());
        cursor.inc();
      };

      if (not cursor.hasNext() or cursor.current() != '}') {
        return #err(#InvalidQuantifierRange("Missing closing '}' for quantifier range at position " # Nat.toText(cursor.getPos())));
      };
      cursor.inc(); // Consume the closing '}'

      let (min, max) = Extensions.parseQuantifierRange(rangeContent);

      createToken(#Quantifier({ min; max; mode = #Greedy }), Extensions.slice(input, start, ?cursor.getPos()))
    };

    private func tokenizeCharacterClass(): Result.Result<Token, LexerError> {
      let start = cursor.getPos();
      cursor.inc(); // Consume the opening '['

      var isNegated = false;

      if (cursor.hasNext() and cursor.current() == '^') {
        isNegated := true;
        cursor.inc();
      };

      var classTokens: [CharacterClass] = [];

      while (cursor.hasNext() and cursor.current() != ']') {
        let c = cursor.current();
        cursor.inc();

        if (c == '\\') {
          if (cursor.hasNext()) {
            let nextChar = cursor.current();
            cursor.inc();
            classTokens := Array.append(classTokens, [tokenizeEscapedClass(nextChar)]);
          } else {
            return #err(#UnexpectedEndOfInput);
          };
        } else if (c == '-' and classTokens.size() > 0 and cursor.hasNext() and cursor.current() != ']') {
          let nextChar = cursor.current();
          cursor.inc();
          switch (Extensions.arrayLast(classTokens)) {
            case (?#Single(lastChar)) {
              classTokens := Array.append(Extensions.sliceArray(classTokens, 0, Int.abs(classTokens.size() - 1)), [#Range(lastChar, nextChar)]);
            };
            case _ {
              return #err(#GenericError("Invalid character range at position " # Nat.toText(cursor.getPos())));
            };
          };
        } else {
          classTokens := Array.append(classTokens, [#Single(c)]);
        };
      };

      if (not cursor.hasNext() or cursor.current() != ']') {
        return #err(#GenericError("Unclosed character class at position " # Nat.toText(cursor.getPos())));
      };

      cursor.inc(); // Consume the closing ']'

      createToken(#CharacterClass(isNegated, classTokens), Extensions.slice(input, start, ?cursor.getPos()))
    };

    private func tokenizeGroup(): Result.Result<Token, LexerError> {
      let start = cursor.getPos();
      cursor.inc(); // Consume the opening '('

      let groupModifierResult = parseGroupModifier();
      var groupModifier: ?Types.GroupModifierType = null;
      switch (groupModifierResult) {
        case (#err(error)) { return #err(error) };
        case (#ok(modifier)) { groupModifier := modifier };
      };

      let subExprResult = tokenizeSubExpression();
      var subTokens: [Token] = [];
      switch (subExprResult) {
        case (#err(error)) { return #err(error) };
        case (#ok(tokens)) { subTokens := Buffer.toArray(tokens) };
      };

      if (not cursor.hasNext() or cursor.current() != ')') {
        return #err(#GenericError("Expected closing parenthesis at position " # Nat.toText(cursor.getPos()) # ", found '" # Text.fromChar(cursor.current()) # "'"));
      };

      cursor.inc(); // Consume the closing ')'

      let groupToken: Token = {
        tokenType = #Group({
          modifier = groupModifier;
          subTokens = subTokens;
          quantifier = null;
        });
        value = Extensions.slice(input, start, ?cursor.getPos());
        position = #Span(start, cursor.getPos() - 1);
      };
      #ok(groupToken)
    };

    private func parseGroupModifier(): Result.Result<?Types.GroupModifierType, LexerError> {
      if (cursor.hasNext() and cursor.current() == '?') {
        cursor.inc();
        if (cursor.hasNext()) {
          switch (cursor.current()) {
            case ':' { cursor.inc(); return #ok(?#NonCapturing) };
            case '=' { cursor.inc(); return #ok(?#PositiveLookahead) };
            case '!' { cursor.inc(); return #ok(?#NegativeLookahead) };
            case '<' {
              cursor.inc();
              if (cursor.hasNext()) {
                switch (cursor.current()) {
                  case '=' { cursor.inc(); return #ok(?#PositiveLookbehind) };
                  case '!' { cursor.inc(); return #ok(?#NegativeLookbehind) };
                  case _ { return #err(#GenericError("Invalid lookbehind modifier at position " # Nat.toText(cursor.getPos()))) };
                };
              } else {
                return #err(#UnexpectedEndOfInput);
              }
            };
            case _ { return #err(#GenericError("Invalid group modifier at position " # Nat.toText(cursor.getPos()))) };
          };
        } else {
          return #err(#UnexpectedEndOfInput);
        }
      };
      // No modifier present
      #ok(null)
    };

    private func tokenizeSubExpression(): Result.Result<Buffer.Buffer<Token>, LexerError> {
      var subTokens = Buffer.Buffer<Token>(16);

      while (cursor.hasNext()) {
        if (cursor.current() == ')') {
          return #ok(subTokens);
        };

        switch (nextToken()) {
          case (#ok(token)) {
            subTokens.add(token);
          };
          case (#err(error)) {
            return #err(error);
          };
        };
      };

      #err(#GenericError("Unclosed group at position " # Nat.toText(cursor.getPos())))
    };

    private func tokenizeEscapedChar(): Result.Result<Token, LexerError> {
      cursor.inc(); // Move past the backslash
      if (not cursor.hasNext()) {
        return #err(#UnexpectedEndOfInput);
      };
      let escapedChar = cursor.current();

      let token = switch escapedChar {
        case 'w' { createToken(#Metacharacter(#WordChar), "\\w") };
        case 'W' { createToken(#Metacharacter(#NonWordChar), "\\W") };
        case 'd' { createToken(#Metacharacter(#Digit), "\\d") };
        case 'D' { createToken(#Metacharacter(#NonDigit), "\\D") };
        case 's' { createToken(#Metacharacter(#Whitespace), "\\s") };
        case 'S' { createToken(#Metacharacter(#NonWhitespace), "\\S") };
        case 'b' { createToken(#Anchor(#WordBoundary), "\\b") };
        case 'B' { createToken(#Anchor(#NonWordBoundary), "\\B") };
        case 'A' { createToken(#Anchor(#StartOfStringOnly), "\\A") };
        case 'z' { createToken(#Anchor(#EndOfStringOnly), "\\z") };
        case 'G' { createToken(#Anchor(#PreviousMatchEnd), "\\G") };
        case _ { createToken(#Character(escapedChar), "\\" # Text.fromChar(escapedChar)) };
      };
      cursor.inc(); // Move past the escaped character
      token
    };

    private func tokenizeEscapedClass(char: Char): CharacterClass {
      switch (char) {
        case 'd' { #Metacharacter(#Digit) };
        case 'D' { #Metacharacter(#NonDigit) };
        case 'w' { #Metacharacter(#WordChar) };
        case 'W' { #Metacharacter(#NonWordChar) };
        case 's' { #Metacharacter(#Whitespace) };
        case 'S' { #Metacharacter(#NonWhitespace) };
        case _ { #Single(char) };
      }
    };
  };
};
