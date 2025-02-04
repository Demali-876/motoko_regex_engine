import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Array "mo:base/Array";
import Int "mo:base/Int";
import Result "mo:base/Result";
import Char "mo:base/Char";
import Buffer "mo:base/Buffer";
import Types "Types";
import Extensions "Extensions";
import Cursor "Cursor";

module {

  public class Lexer(input : Text) {
    let cursor = Cursor.Cursor(input);
    let tokenBuffer = Buffer.Buffer<Types.Token>(16);

    public func tokenize() : Result.Result<[Types.Token], Types.RegexError> {
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
      #ok(Buffer.toArray(tokenBuffer));
    };

    private func nextToken() : Result.Result<Types.Token, Types.RegexError> {
      switch (cursor.current()) {
        case (char) {
          let token = switch char {
            case '.' {
              cursor.inc();
              createToken(#Metacharacter(#Dot), ".");
            };
            case '^' {
              cursor.inc();
              createToken(#Anchor(#StartOfString), "^");
            };
            case '$' {
              cursor.inc();
              createToken(#Anchor(#EndOfString), "$");
            };
            case '|' {
              cursor.inc();
              createToken(#Alternation, "|");
            };

            case '(' { tokenizeGroup() };
            case '[' { tokenizeCharacterClass() };

            case '*' { tokenizeQuantifier(0, null) };
            case '+' { tokenizeQuantifier(1, null) };
            case '?' { tokenizeQuantifier(0, ?1) };
            case '{' { tokenizeQuantifierRange() };

            case '\\' {
              if (not cursor.hasNext()) {
                #err(#GenericError("Incomplete escape sequence at position " # Nat.toText(cursor.getPos())));
              } else {
                let startPos = cursor.getPos();
                cursor.inc();
                let escapedChar = cursor.current();
                if (Extensions.isReservedSymbol(escapedChar)) {
                  cursor.inc();
                  createToken(#Character(escapedChar), "\\" # Text.fromChar(escapedChar));
                } else {
                  tokenizeEscapedChar();
                };
              };
            };

            case (')' or ']' or '}') {
              #err(#GenericError("Unmatched closing '" # Text.fromChar(char) # "' at position " # Nat.toText(cursor.getPos())));
            };

            case _ {
              if (Extensions.isReservedSymbol(char)) {
                #err(#GenericError("Invalid use of regex metacharacter '" # Text.fromChar(char) # "' at position " # Nat.toText(cursor.getPos())));
              } else {
                cursor.inc();
                createToken(#Character(char), Text.fromChar(char));
              };
            };
          };
          token;
        };
      };
    };
    private func createToken(tokenType : Types.TokenType, value : Text) : Result.Result<Types.Token, Types.RegexError> {
      #ok({
        tokenType = tokenType;
        value = value;
        position = #Instance(cursor.getPos() - 1);
      });
    };

    private func tokenizeQuantifier(min : Nat, max : ?Nat) : Result.Result<Types.Token, Types.RegexError> {
      let start = cursor.getPos();
      cursor.inc();

      let mode = if (cursor.hasNext()) {
        switch (cursor.current()) {
          case '?' {
            cursor.inc();
            #Lazy;
          };
          case ('*' or '+') {
            return #err(#GenericError("Invalid quantifier modifier at position " # Nat.toText(cursor.getPos())));
          };
          case _ { #Greedy };
        };
      } else {
        #Greedy;
      };

      createToken(#Quantifier({ min; max; mode }), Extensions.slice(input, start, ?cursor.getPos()));
    };

    private func tokenizeQuantifierRange() : Result.Result<Types.Token, Types.RegexError> {
      let start = cursor.getPos();
      cursor.inc();
      if (not cursor.hasNext()) {
        return #err(#InvalidQuantifierRange("Unclosed quantifier at position " # Nat.toText(start)));
      };
      if (cursor.current() == ',') {
        return #err(#InvalidQuantifierRange("Quantifier cannot start with comma at position " # Nat.toText(cursor.getPos())));
      };
      if (cursor.current() == '}') {
        return #err(#InvalidQuantifierRange("Empty quantifier at position " # Nat.toText(start)));
      };

      var rangeContent = "";
      var hasComma = false;
      var hasNumber = false;

      while (cursor.hasNext() and cursor.current() != '}') {
        let current = cursor.current();
        if (current == ',') {
          if (hasComma) {
            return #err(#InvalidQuantifierRange("Multiple commas in quantifier range at position " # Nat.toText(cursor.getPos())));
          };
          hasComma := true;
        } else if (Char.isDigit(current)) {
          hasNumber := true;
        } else {
          return #err(#InvalidQuantifierRange("Invalid character in quantifier range at position " # Nat.toText(cursor.getPos())));
        };
        rangeContent := rangeContent # Text.fromChar(current);
        cursor.inc();
      };

      if (not hasNumber) {
        return #err(#InvalidQuantifierRange("Quantifier range must contain at least one number"));
      };

      if (not cursor.hasNext() or cursor.current() != '}') {
        return #err(#InvalidQuantifierRange("Missing closing '}' for quantifier range"));
      };

      cursor.inc();
      let (min, max) = Extensions.parseQuantifierRange(rangeContent);

      let mode = if (cursor.hasNext()) {
        switch (cursor.current()) {
          case '?' {
            cursor.inc();
            #Lazy;
          };
          case ('*' or '+') {
            return #err(#GenericError("Invalid quantifier modifier at position " # Nat.toText(cursor.getPos())));
          };
          case _ { #Greedy };
        };
      } else {
        #Greedy;
      };

      createToken(#Quantifier({ min; max; mode }), Extensions.slice(input, start, ?cursor.getPos()));
    };
    private func tokenizeCharacterClass() : Result.Result<Types.Token, Types.RegexError> {
      let start = cursor.getPos();
      cursor.inc();

      var isNegated = false;
      var hasContent = false;

      if (cursor.hasNext() and cursor.current() == '^') {
        isNegated := true;
        cursor.inc();
      };

      var classTokens : [Types.CharacterClass] = [];
      var lastChar : ?Char = null;

      while (cursor.hasNext() and cursor.current() != ']') {
        let c = cursor.current();
        cursor.inc();
        hasContent := true;

        if (c == '-') {
          switch (lastChar) {
            case (null) {
              return #err(#GenericError("Invalid range: '-' at start of class at position " # Nat.toText(cursor.getPos())));
            };
            case (?prev) {
              if (not cursor.hasNext() or cursor.current() == ']') {
                return #err(#GenericError("Incomplete range at position " # Nat.toText(cursor.getPos())));
              };
              let nextChar = cursor.current();
              if (Char.toNat32(prev) > Char.toNat32(nextChar)) {
                return #err(#GenericError("Invalid character range order at position " # Nat.toText(cursor.getPos())));
              };
              cursor.inc();
              classTokens := Array.append(
                Extensions.sliceArray(classTokens, 0, Int.abs(classTokens.size() - 1)),
                [#Range(prev, nextChar)],
              );
              lastChar := null;
            };
          };
        } else {
          if (c == '\\') {
            if (cursor.hasNext()) {
              let nextChar = cursor.current();
              cursor.inc();
              switch (tokenizeEscapedClass(nextChar)) {
                case (#ok(classToken)) {
                  classTokens := Array.append(classTokens, [classToken]);
                  lastChar := null;
                };
                case (#err(e)) { return #err(e) };
              };
            } else {
              return #err(#UnexpectedEndOfInput);
            };
          } else {
            classTokens := Array.append(classTokens, [#Single(c)]);
            lastChar := ?c;
          };
        };
      };

      if (not hasContent) {
        return #err(#GenericError("Empty character class at position " # Nat.toText(start)));
      };

      if (not cursor.hasNext()) {
        return #err(#GenericError("Unclosed character class at position " # Nat.toText(start)));
      };

      cursor.inc();
      createToken(#CharacterClass(isNegated, classTokens), Extensions.slice(input, start, ?cursor.getPos()));
    };

    private func tokenizeGroup() : Result.Result<Types.Token, Types.RegexError> {
      let start = cursor.getPos();
      cursor.inc();

      var groupModifier : ?Types.GroupModifierType = null;
      var groupName : ?Text = null;

      if (cursor.hasNext() and cursor.current() == '?') {
        cursor.inc();

        if (cursor.hasNext()) {
          let nextChar = cursor.current();

          if (nextChar == '<') {
            cursor.inc();
            if (cursor.hasNext()) {
              let lookbehindChar = cursor.current();
              switch (lookbehindChar) {
                case ('=' or '!') {
                  cursor.dec();
                  cursor.dec();
                  let modifierResult = parseGroupModifier();
                  switch (modifierResult) {
                    case (#ok(?modifier)) { groupModifier := ?modifier };
                    case (#err(error)) { return #err(error) };
                    case (#ok(null)) {
                      return #err(#GenericError("Invalid group modifier at position " # Nat.toText(start)));
                    };
                  };
                };
                case _ {
                  var nameBuffer = Buffer.Buffer<Char>(10);

                  cursor.dec();

                  while (cursor.hasNext() and cursor.current() != '>') {
                    let c = cursor.current();
                    cursor.inc();

                    if (c != '<' and not (('a' <= c and c <= 'z') or ('A' <= c and c <= 'Z'))) {
                      return #err(#GenericError("Invalid named group character '" # Text.fromChar(c) # "' at position " # Nat.toText(cursor.getPos())));
                    };

                    if (c != '<') {
                      nameBuffer.add(c);
                    };
                  };

                  if (nameBuffer.size() == 0) {
                    return #err(#GenericError("Empty group name at position " # Nat.toText(start)));
                  };

                  if (not cursor.hasNext() or cursor.current() != '>') {
                    return #err(#GenericError("Unterminated named group at position " # Nat.toText(start)));
                  };
                  cursor.inc();
                  groupName := ?Text.fromIter(nameBuffer.vals());
                };
              };
            } else {
              return #err(#UnexpectedEndOfInput);
            };
          } else {
            cursor.dec();
            let modifierResult = parseGroupModifier();
            switch (modifierResult) {
              case (#ok(?modifier)) { groupModifier := ?modifier };
              case (#err(error)) { return #err(error) };
              case (#ok(null)) {
                return #err(#GenericError("Invalid group modifier at position " # Nat.toText(start)));
              };
            };
          };
        } else {
          return #err(#UnexpectedEndOfInput);
        };
      };

      if (cursor.hasNext() and cursor.current() == ')') {
        return #err(#GenericError("Empty group at position " # Nat.toText(start)));
      };

      let subExprResult = tokenizeSubExpression();
      var subTokens : [Types.Token] = [];

      switch (subExprResult) {
        case (#err(error)) { return #err(error) };
        case (#ok(tokens)) {
          if (Buffer.isEmpty(tokens)) {
            return #err(#GenericError("Empty group at position " # Nat.toText(start)));
          };
          subTokens := Buffer.toArray(tokens);
        };
      };

      if (not cursor.hasNext() or cursor.current() != ')') {
        return #err(#GenericError("Expected closing parenthesis at position " # Nat.toText(cursor.getPos()) # ", found '" # Text.fromChar(cursor.current()) # "'"));
      };
      cursor.inc();

      let groupToken : Types.Token = {
        tokenType = #Group({
          modifier = groupModifier;
          subTokens = subTokens;
          quantifier = null;
          name = groupName;
        });
        value = Extensions.slice(input, start, ?cursor.getPos());
        position = #Span(start, cursor.getPos() - 1);
      };

      #ok(groupToken);
    };
    private func parseGroupModifier() : Result.Result<?Types.GroupModifierType, Types.RegexError> {
      if (not cursor.hasNext()) {
        return #ok(null);
      };

      let startPos = cursor.getPos();

      if (cursor.current() == '?') {
        cursor.inc();
        if (cursor.hasNext()) {
          let modifier = cursor.current();
          switch (modifier) {
            case ':' {
              cursor.inc();
              return #ok(?#NonCapturing);
            };
            case '=' {
              cursor.inc();
              return #ok(?#PositiveLookahead);
            };
            case '!' {
              cursor.inc();
              return #ok(?#NegativeLookahead);
            };
            case '<' {
              cursor.inc();
              if (cursor.hasNext()) {
                switch (cursor.current()) {
                  case '=' {
                    cursor.inc();
                    return #ok(?#PositiveLookbehind);
                  };
                  case '!' {
                    cursor.inc();
                    return #ok(?#NegativeLookbehind);
                  };
                  case _ {
                    return #err(#GenericError("Invalid lookbehind modifier at position " # Nat.toText(cursor.getPos())));
                  };
                };
              } else {
                return #err(#UnexpectedEndOfInput);
              };
            };
            case _ {
              return #err(#GenericError("Invalid group modifier '" # Text.fromChar(modifier) # "' at position " # Nat.toText(startPos)));
            };
          };
        } else {
          return #err(#UnexpectedEndOfInput);
        };
      };
      #ok(null);
    };

    private func tokenizeSubExpression() : Result.Result<Buffer.Buffer<Types.Token>, Types.RegexError> {
      var subTokens = Buffer.Buffer<Types.Token>(16);

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

      #err(#GenericError("Unclosed group at position " # Nat.toText(cursor.getPos())));
    };

    private func tokenizeEscapedChar() : Result.Result<Types.Token, Types.RegexError> {
      if (not cursor.hasNext()) {
        return #err(#UnexpectedEndOfInput);
      };

      let escapedChar = cursor.current();

      if (escapedChar == 'k') {
        cursor.inc();

        if (not cursor.hasNext() or cursor.current() != '<') {
          return #err(#GenericError("Expected '<' after '\\k' for named backreference"));
        };

        cursor.inc();
        var nameBuffer = Buffer.Buffer<Char>(10);

        while (cursor.hasNext() and cursor.current() != '>') {
          let c = cursor.current();

          if (not (('a' <= c and c <= 'z') or ('A' <= c and c <= 'Z'))) {
            return #err(#GenericError("Invalid backreference name '\\k<" # Text.fromIter(nameBuffer.vals()) # ">' at position " # Nat.toText(cursor.getPos()) # ". Names must be alphabetic."));
          };
          nameBuffer.add(c);
          cursor.inc();
        };
        if (nameBuffer.size() == 0) {
          return #err(#GenericError("Attempted to reference a group but provided no name!"));
        };

        if (not cursor.hasNext() or cursor.current() != '>') {
          return #err(#GenericError("Unterminated named backreference '\\k<" # Text.fromIter(nameBuffer.vals()) # ">'"));
        };

        cursor.inc();

        let name = Text.fromIter(nameBuffer.vals());

        return #ok({
          tokenType = #Backreference;
          value = name;
          position = #Span(cursor.getPos() - Text.size(name), cursor.getPos());
        });
      };

      if (escapedChar == 'p' or escapedChar == 'P') {
        cursor.inc();

        if (not cursor.hasNext() or cursor.current() != '{') {
          return #err(#GenericError("Expected '{' after '\\p' or '\\P' for Unicode property"));
        };

        cursor.inc();
        var propertyText = "";

        while (cursor.hasNext() and cursor.current() != '}') {
          propertyText := propertyText # Text.fromChar(cursor.current());
          cursor.inc();
        };

        if (not cursor.hasNext() or cursor.current() != '}') {
          return #err(#GenericError("Unterminated Unicode property '\\p{" # propertyText # "'"));
        };

        cursor.inc();

        if (Extensions.isValidUnicodeProperty(propertyText)) {
          return createToken(#Metacharacter(#UnicodeProperty(escapedChar == 'P', propertyText)), "\\" # (if (escapedChar == 'P') "P" else "p") # "{" # propertyText # "}");
        } else {
          return #err(#GenericError("Invalid Unicode property '\\p{" # propertyText # "}'"));
        };
      };

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
        case c { createToken(#Character(c), "\\" # Text.fromChar(c)) };
      };

      cursor.inc();
      token;
    };

    private func tokenizeEscapedClass(char : Char) : Result.Result<Types.CharacterClass, Types.RegexError> {
      if (not Extensions.isValidEscapeSequence(char, true)) {
        return #err(#GenericError("Invalid escape sequence '\\" # Text.fromChar(char) # "' in character class"));
      };
      #ok(
        switch (char) {
          case 'd' { #Metacharacter(#Digit) };
          case 'D' { #Metacharacter(#NonDigit) };
          case 'w' { #Metacharacter(#WordChar) };
          case 'W' { #Metacharacter(#NonWordChar) };
          case 's' { #Metacharacter(#Whitespace) };
          case 'S' { #Metacharacter(#NonWhitespace) };
          case _ { #Single(char) };
        }
      );
    };
  };
};
