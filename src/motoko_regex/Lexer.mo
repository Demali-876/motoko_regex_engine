import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Array "mo:base/Array";
import Int "mo:base/Int";
import Result "mo:base/Result";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Types "Types";
import Extensions "Extensions";
import Cursor "Cursor";

module {
  type Token = Types.Token;
  type LexerError = Types.LexerError;
  type CharacterClass = Types.CharacterClass;
  public class Lexer(input: Text) {
    let cursor = Cursor.Cursor(input);
    let tokenBuffer = Buffer.Buffer<Token>(16);

    public func tokenize(): [Token] {
      while (cursor.hasNext()) {
        switch (nextToken()) {
          case (#ok(token)) { tokenBuffer.add(token) };
          case (#err(error)) { Debug.trap(Extensions.errorToText(error)) };
        };
      };
      Buffer.toArray(tokenBuffer)
    };

    private func nextToken(): Result.Result<Token, LexerError> {
      switch (cursor.current()) {
          case (char) {
              let token = switch char {
                  case '.' { createToken(#Metacharacter(#Dot), ".") };
                  case '*' { tokenizeQuantifier(0, null) };
                  case '+' { tokenizeQuantifier(1, null) };
                  case '?' { tokenizeQuantifier(0, ?1) };
                  case '(' {
                    switch (tokenizeGroup()) {
                        case (#ok(token)) { return #ok(token); };
                        case (#err(error)) { return #err(error); };
                    };
                  };
                  case '[' { tokenizeCharacterClass() };
                  case '^' {
                      if (cursor.getPos() == 0) {
                          createToken(#Anchor(#StartOfString), "^")
                      } else {
                          createToken(#Character(char), Text.fromChar(char))
                      }
                  };
                  case '$' { createToken(#Anchor(#EndOfString), "$") };
                  case '|' { createToken(#Alternation, "|") };
                  case '\\' { tokenizeEscapedChar() };
                  case '{' {
                      if (tokenBuffer.size() > 0) {
                          return tokenizeQuantifierRange();
                      } else {
                          return #err(#GenericError("Quantifier range must follow a valid token at position " # Nat.toText(cursor.getPos())));
                      }
                  };
                  case _ { createToken(#Character(char), Text.fromChar(char)) };
              };
              switch (token) {
                  case (#ok(_)) { cursor.inc() };
                  case (#err(_)) { };
              };
              token
          };
      }
  };

    private func createToken(tokenType: Types.TokenType, value: Text): Result.Result<Token, LexerError> {
      #ok({
        tokenType = tokenType;
        value = value;
        position = #Instance(cursor.getPos());
      })
    };

    private func tokenizeQuantifier(min: Nat, max: ?Nat): Result.Result<Token, LexerError> {
      let start = cursor.getPos();
      cursor.inc();
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
        cursor.inc();

        var rangeContent = "";
        while (cursor.hasNext() and cursor.current() != '}') {
            rangeContent := rangeContent # Text.fromChar(cursor.current());
            cursor.inc();
        };

        if (cursor.current() != '}') {
            return #err(#InvalidQuantifierRange("Missing closing '}' for quantifier range at position " # Nat.toText(cursor.getPos())));
        };

        cursor.inc();

        let (min, max) = Extensions.parseQuantifierRange(rangeContent);

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

    private func tokenizeCharacterClass(): Result.Result<Token, LexerError> {
      let start = cursor.getPos();
      cursor.inc();
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
        } else if (c == '-' and classTokens.size() > 0 and cursor.hasNext()) {
          let nextChar = cursor.current();
          cursor.inc();
          if (nextChar == ']' or nextChar == '-') {
            return #err(#GenericError("Invalid character range at position " # Nat.toText(cursor.getPos()) # ": '" # Text.fromChar(c) # "-" # Text.fromChar(nextChar) # "'"));
          } else {
            switch (Extensions.arrayLast(classTokens)) {
              case (?#Single(lastChar)) {
                classTokens := Array.append(Extensions.sliceArray(classTokens, 0, Int.abs(classTokens.size() - 1)), [#Range(lastChar, nextChar)]);
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

      if (not cursor.hasNext() or cursor.current() != ']') {
      return #err(#GenericError("Unclosed character class at position " # Nat.toText(cursor.getPos())));
      };

      cursor.inc();

      if (cursor.hasNext()) {
        switch (cursor.current()) {
          case '+' { return applyQuantifierToClassTokens(1, null, classTokens, isNegated, start) };
          case '*' { return applyQuantifierToClassTokens(0, null, classTokens, isNegated, start) };
          case '?' { return applyQuantifierToClassTokens(0, ?1, classTokens, isNegated, start) };
          case '{' { return tokenizeQuantifierRangeForClassTokens(classTokens, isNegated, start) };
          case _ { };  // No quantifier, continue as normal
        };
      };

      createToken(#CharacterClass(isNegated, classTokens), Extensions.slice(input, start, ?cursor.getPos()))
    };
    private func tokenizeGroup(): Result.Result<Token, LexerError> {
    let start = cursor.getPos();
    if (not cursor.hasNext()) {
        return #err(#GenericError("Unexpected end of input at position " # Nat.toText(start)));
    };
    cursor.inc();

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

    if (not cursor.hasNext()) {
        return #err(#GenericError("Unexpected end of input while parsing group at position " # Nat.toText(start)));
    };

    if (cursor.current() != ')') {
        return #err(#GenericError("Expected closing parenthesis at position " # Nat.toText(cursor.getPos()) # ", found '" # Text.fromChar(cursor.current()) # "'"));
    };

    cursor.inc();

    let groupToken: Token = {
        tokenType = #Group({
            modifier = groupModifier;
            subTokens = subTokens;
        });
        value = Extensions.slice(input, start, ?cursor.getPos());
        position = #Span(start, cursor.getPos() -1);
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
    var depth = 1;

    while (cursor.hasNext() and depth > 0) {
        switch (cursor.current()) {
            case '(' {
                depth += 1;
                switch (tokenizeGroup()) {
                    case (#ok(token)) { subTokens.add(token) };
                    case (#err(error)) { return #err(error) };
                };
            };
            case ')' {
                depth -= 1;
                if (depth == 0) {
                    return #ok(subTokens);
                } else {
                    cursor.inc();
                };
            };
            case _ {
                switch (nextToken()) {
                    case (#ok(token)) { subTokens.add(token) };
                    case (#err(error)) { return #err(error) };
                };
            };
        };
    };

    if (depth > 0) {
        return #err(#GenericError("Unclosed group at position " # Nat.toText(cursor.getPos())));
    };

    #ok(subTokens)
};

    private func tokenizeEscapedChar(): Result.Result<Token, LexerError> {
      cursor.inc();
      switch (cursor.current()) {
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
        case _ { createToken(#Character(cursor.current()), "\\" # Text.fromChar(cursor.current())) };
      }
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

    private func applyQuantifierToClassTokens(
      min: Nat,
      max: ?Nat,
      classTokens: [CharacterClass],
      isNegated: Bool,
      start: Nat
    ): Result.Result<Token, LexerError> {
      let mode = if (cursor.hasNext()) {
        switch (cursor.current()) {
          case '?' { cursor.inc(); #Lazy };
          case '+' { cursor.inc(); #Possessive };
          case _ { #Greedy };
        }
      } else {
        #Greedy
      };

      let quantifiedClassTokens = Array.map<CharacterClass, CharacterClass>(
        classTokens,
        func (ct: CharacterClass): CharacterClass {
          #Quantified(ct, { min; max; mode })
        }
      );

      createToken(#CharacterClass(isNegated, quantifiedClassTokens), Extensions.slice(input, start, ?cursor.getPos()))
    };

    private func tokenizeQuantifierRangeForClassTokens(
      classTokens: [CharacterClass],
      isNegated: Bool,
      start: Nat
    ): Result.Result<Token, LexerError> {
      let quantifierResult = tokenizeQuantifierRange();
      switch (quantifierResult) {
        case (#ok(quantifierToken)) {
          switch (quantifierToken.tokenType) {
            case (#Quantifier(quantifierType)) {
              let quantifiedClassTokens = Array.map<CharacterClass, CharacterClass>(
                classTokens,
                func (ct: CharacterClass): CharacterClass {
                  #Quantified(ct, quantifierType)
                }
              );
              return createToken(#CharacterClass(isNegated, quantifiedClassTokens), Extensions.slice(input, start, ?cursor.getPos()));
            };
            case (_) {
              return #err(#GenericError("Unexpected token type for quantifier at position " # Nat.toText(cursor.getPos())));
            };
          };
        };
        case (#err(error)) { return #err(error) };
      };
    };
  };
};