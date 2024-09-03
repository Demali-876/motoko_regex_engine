import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Array "mo:base/Array";
import Int "mo:base/Int";
import Result "mo:base/Result";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Char "mo:base/Char";
import Types "Types";
import Cursor "Cursor";

module {
  public class Lexer(input : Text) {
    let cursor = Cursor.Cursor(input);

    public func tokenize() : [Types.Token] {
      let tokenBuffer = Buffer.Buffer<Types.Token>(16);

      while (cursor.hasNext()) {
        switch (nextToken()) {
          case (#ok(token)) { tokenBuffer.add(token) };
           case (#err(error)) {
            let errorText = switch (error) {
                case (#GenericError(text)) text;
                case (#InvalidEscapeSequence(char)) "Invalid escape sequence: " # Char.toText(char);
                case (#InvalidQuantifierRange(text)) "Invalid quantifier range: " # text;
                case (#MismatchedParenthesis(left, right)) "Mismatched parenthesis: " # Char.toText(left) # " and " # Char.toText(right);
                case (#UnexpectedCharacter(char)) "Unexpected character: " # Char.toText(char);
                case (#UnexpectedEndOfInput) "Unexpected end of input";
                case (#UnmatchedParenthesis(char)) "Unmatched parenthesis: " # Char.toText(char);
            };
            Debug.trap(errorText);
            };
        };
      };

      Buffer.toArray(tokenBuffer)
    };

    private func nextToken() : Result.Result<Types.Token, Types.LexerError> {
      switch (cursor.current()) {
        case (char) {
          let token = switch char {
            case '.' { #ok(createToken(#Metacharacter(#Dot), ".")) };
            case '*' { #ok(createToken(#Quantifier(#ZeroOrMore), "*")) };
            case '+' { #ok(createToken(#Quantifier(#OneOrMore), "+")) };
            case '?' { #ok(createToken(#Quantifier(#ZeroOrOne), "?")) };
            case '(' { #ok(createToken(#GroupStart, "(")) };
            case ')' { #ok(createToken(#GroupEnd, ")")) };
            case '[' { tokenizeCharacterClass() };
            case ']' { #ok(createToken(#Character(char), Text.fromChar(char))) };
            case '^' { 
              if (cursor.getPos() == 0) {
                #ok(createToken(#Anchor(#StartOfString), "^"))
              } else {
                #ok(createToken(#Character(char), Text.fromChar(char)))
              }
            };
            case '$' { #ok(createToken(#Anchor(#EndOfString), "$")) };
            case '|' { #ok(createToken(#Alternation, "|")) };
            case '\\' { tokenizeEscapedChar() };
            case '{' { tokenizeQuantifierRange() };
            case '}' { #ok(createToken(#Character(char), Text.fromChar(char))) };
            case _ { #ok(createToken(#Character(char), Text.fromChar(char))) };
          };

          switch token {
            case (#ok(_)) { cursor.inc() };
            case (#err(_)) { };
          };

          token
        };
      }
    };

    private func createToken(tokenType : Types.TokenType, value : Text) : Types.Token {
      {
        tokenType = tokenType;
        value = value;
        position = cursor.getPos();
      }
    };

        private func tokenizeCharacterClass() : Result.Result<Types.Token, Types.LexerError> {
        let start = cursor.getPos();
        cursor.inc();  // Move past the opening '['
        var isNegated = false;

        // Check for negation
        if (cursor.hasNext() and cursor.current() == '^') {
            isNegated := true;
            cursor.inc();
        };

        var classTokens: [Types.CharacterClass] = [];

        while (cursor.hasNext() and cursor.current() != ']') {
            let c = cursor.current();
            cursor.inc();

            if (c == '\\') {
                // Handle escaped characters and metacharacters
                if (cursor.hasNext()) {
                    let nextChar = cursor.current();
                    cursor.inc();
                    switch (nextChar) {
                        case 'd' { classTokens := Array.append(classTokens, [#Metacharacter(#Digit)]); };
                        case 'D' { classTokens := Array.append(classTokens, [#Metacharacter(#NonDigit)]); };
                        case 'w' { classTokens := Array.append(classTokens, [#Metacharacter(#WordChar)]); };
                        case 'W' { classTokens := Array.append(classTokens, [#Metacharacter(#NonWordChar)]); };
                        case 's' { classTokens := Array.append(classTokens, [#Metacharacter(#Whitespace)]); };
                        case 'S' { classTokens := Array.append(classTokens, [#Metacharacter(#NonWhitespace)]); };
                        case _ { classTokens := Array.append(classTokens, [#Single(nextChar)]); };
                    };
                } else {
                    return #err(#UnexpectedEndOfInput);
                };
            } else if (c == '-' and classTokens.size() > 0 and cursor.hasNext()) {
                let nextChar = cursor.current();
                cursor.inc();
                if (nextChar == ']' or nextChar == '-') {
                    return #err(#GenericError("Invalid character range at position " # Nat.toText(cursor.getPos()) # ": '" # Text.fromChar(c) # "-" # Text.fromChar(nextChar) # "'"));
                } else {
                    switch (Types.arrayLast(classTokens)) {
                        case (?#Single(lastChar)) {
                            classTokens := Array.append(Types.sliceArray(classTokens, 0, Int.abs(classTokens.size() - 1)), [#Range(lastChar, nextChar)]);
                        };
                        case _ {
                            return #err(#GenericError("Unexpected state in character class at position " # Nat.toText(cursor.getPos())));
                        };
                    };
                };
            } else if (c == '-') {
                classTokens := Array.append(classTokens, [#Single(c)]);
            } else {
                classTokens := Array.append(classTokens, [#Single(c)]);
            };
        };

        // Check for unclosed character class
        if (not cursor.hasNext() or cursor.current() != ']') {
            return #err(#GenericError("Unclosed character class at position " # Nat.toText(cursor.getPos())));
        };

        cursor.inc();  // Move past the closing ']'

        // Look ahead for quantifiers
        if (cursor.hasNext()) {
            let nextChar = cursor.current();
            if (nextChar == '{' or nextChar == '*' or nextChar == '+' or nextChar == '?') {
                return #ok(createToken(#CharacterClass(isNegated, classTokens), Types.slice(input, start, ?cursor.getPos())));
            };
        };

        return #ok(createToken(#CharacterClass(isNegated, classTokens), Types.slice(input, start, ?cursor.getPos())));
    };

    private func tokenizeEscapedChar() : Result.Result<Types.Token, Types.LexerError> {
      cursor.inc();
      switch (cursor.current()) {
        case (nextChar) {
          switch nextChar {
            case 'w' { #ok(createToken(#Metacharacter(#WordChar), "\\w")) };
            case 'W' { #ok(createToken(#Metacharacter(#NonWordChar), "\\W")) };
            case 'd' { #ok(createToken(#Metacharacter(#Digit), "\\d")) };
            case 'D' { #ok(createToken(#Metacharacter(#NonDigit), "\\D")) };
            case 's' { #ok(createToken(#Metacharacter(#Whitespace), "\\s")) };
            case 'S' { #ok(createToken(#Metacharacter(#NonWhitespace), "\\S")) };
            case 'b' { #ok(createToken(#Anchor(#WordBoundary), "\\b")) };
            case 'B' { #ok(createToken(#Anchor(#NonWordBoundary), "\\B")) };
            case 'A' { #ok(createToken(#Anchor(#StartOfStringOnly), "\\A")) };
            case 'z' { #ok(createToken(#Anchor(#EndOfStringOnly), "\\z")) };
            case 'G' { #ok(createToken(#Anchor(#PreviousMatchEnd), "\\G")) };
            case _ { #ok(createToken(#Character(nextChar), "\\" # Text.fromChar(nextChar))) };
          }
        };
      }
    };

    private func tokenizeQuantifierRange() : Result.Result<Types.Token, Types.LexerError> {
      let start = cursor.getPos();
      cursor.inc();

      while (cursor.hasNext()) {
        switch (cursor.current()) {
          case ('}') { 
            cursor.inc();
            return #ok(createToken(#QuantifierRange, cursor.slice(start, ?cursor.getPos())));
          };
          case (_) { cursor.inc() };
        };
      };

      #err(#InvalidQuantifierRange(cursor.slice(start, null)))
    };
  };
};