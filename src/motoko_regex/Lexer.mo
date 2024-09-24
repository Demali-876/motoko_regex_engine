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
  public class Lexer(input : Text) {
    let cursor = Cursor.Cursor(input);
    let tokenBuffer = Buffer.Buffer<Types.Token>(16);
    var start = cursor.getPos();

    public func tokenize() : [Types.Token] {
      while (cursor.hasNext()) {
        switch (nextToken()) {
          case (#ok(token)) { tokenBuffer.add(token) };
           case (#err(error)) {
            Debug.trap(Extensions.errorToText(error));
            };
        };
      };
      Buffer.toArray(tokenBuffer)
    };

    private func nextToken() : Result.Result<Types.Token, Types.LexerError> {
    switch (cursor.current()) {
                case (char) {
                let token = switch char {
                case '.' { #ok(createToken(#Metacharacter(#Dot), ".",#Instance(cursor.getPos()))) };
                case '*' {cursor.inc(); applyQuantifier(#ZeroOrMore(#Greedy))};
                case '+' {cursor.inc(); applyQuantifier(#OneOrMore(#Greedy))};
                case '?' {cursor.inc(); applyQuantifier(#ZeroOrOne(#Greedy))};
                case '(' { #ok(createToken(#GroupStart, "(", #Instance(cursor.getPos()))) };
                case ')' { #ok(createToken(#GroupEnd, ")",#Instance(cursor.getPos()))) };
                case '[' { tokenizeCharacterClass() };
                case ']' { #ok(createToken(#Character(char), Text.fromChar(char),#Instance(cursor.getPos()))) };
                case '^' {
                    if (cursor.getPos() == 0) {
                        #ok(createToken(#Anchor(#StartOfString), "^",#Instance(cursor.getPos())))
                    } else {
                        #ok(createToken(#Character(char), Text.fromChar(char),#Instance(cursor.getPos())))
                    }
                };
                case '$' { #ok(createToken(#Anchor(#EndOfString), "$",#Instance(cursor.getPos()))) };
                case '|' { #ok(createToken(#Alternation, "|",#Instance(cursor.getPos()))) };
                case '\\' { tokenizeEscapedChar() };
                case '{' {
                    let quantifierResult = tokenizeQuantifierRange();
                    return quantifierResult;
                };
                case _ { #ok(createToken(#Character(char), Text.fromChar(char),#Instance(cursor.getPos()))) };
            };

            switch token {
                case (#ok(_)) {
                    cursor.inc();  // Always increment the cursor after processing a token
                };
                case (#err(_)) { };  // Handle errors but do not move the cursor
            };

            token  // Return the token
        };
    }
};

    private func createToken(tokenType : Types.TokenType, value : Text, pos:Types.Position) : Types.Token {
      {
        tokenType = tokenType;
        value = value;
        position = pos;
      }
    };

    private func tokenizeCharacterClass() : Result.Result<Types.Token, Types.LexerError> {
    start := cursor.getPos();
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
                return #err(#GenericError("Invalid character range at position " # Nat.toText(cursor.getPos())
                # ": '" # Text.fromChar(c) # "-" # Text.fromChar(nextChar) # "'"));
            } else {
                switch (Extensions.arrayLast(classTokens)) {
                    case (?#Single(lastChar)) {
                        classTokens := Array.append(Extensions.sliceArray(classTokens, 0, Int.abs(classTokens.size() - 1)),
                        [#Range(lastChar, nextChar)]);
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
    if (not cursor.hasNext() and cursor.current() != ']') {
        return #err(#GenericError("Unclosed character class at position " # Nat.toText(cursor.getPos())));
    };

    cursor.inc();  // Move past the closing ']'
    if (cursor.hasNext()) {
        switch (cursor.current()) {
            case '+' { return applyQuantifierToClassTokens(#OneOrMore(#Greedy), classTokens, isNegated, start); };
            case '*' { return applyQuantifierToClassTokens(#ZeroOrMore(#Greedy), classTokens, isNegated, start); };
            case '?' { return applyQuantifierToClassTokens(#ZeroOrOne(#Greedy), classTokens, isNegated, start); };
            case _ {};  // No quantifier, continue as normal
        };
    };
    if (cursor.hasNext() and cursor.current() == '{') {
        let quantifierResult = tokenizeQuantifierRange();
        switch (quantifierResult) {
            case (#ok(quantifierToken)) {
                switch (quantifierToken.tokenType) {
                    case (#QuantifierRange) {
                        let quantifierType = Extensions.parseQuantifierRange(quantifierToken.value);
                        let quantifiedClassTokens = Array.map<Types.CharacterClass, Types.CharacterClass>(
                            classTokens,
                            func (ct : Types.CharacterClass) : Types.CharacterClass {
                                #Quantified(ct, #Range(quantifierType))
                            }
                        );
                        return #ok(createToken(#CharacterClass(isNegated, quantifiedClassTokens), Extensions.slice(input, start, ?cursor.getPos()),#Span(start, cursor.getPos())));
                    };
                    case (_) {
                        return #err(#GenericError("Unexpected token type for quantifier at position " # Nat.toText(cursor.getPos())));
                    };
                };
            };
            case (#err(error)) { return #err(error); };
        };
    };
    #ok(createToken(#CharacterClass(isNegated, classTokens), Extensions.slice(input, start, ?cursor.getPos()),#Span(start, cursor.getPos())))
};

    private func tokenizeEscapedChar() : Result.Result<Types.Token, Types.LexerError> {
      cursor.inc();
      switch (cursor.current()) {
            case 'w' { #ok(createToken(#Metacharacter(#WordChar), "\\w",#Instance(cursor.getPos()))) };
            case 'W' { #ok(createToken(#Metacharacter(#NonWordChar), "\\W",#Instance(cursor.getPos()))) };
            case 'd' { #ok(createToken(#Metacharacter(#Digit), "\\d",#Instance(cursor.getPos()))) };
            case 'D' { #ok(createToken(#Metacharacter(#NonDigit), "\\D",#Instance(cursor.getPos()))) };
            case 's' { #ok(createToken(#Metacharacter(#Whitespace), "\\s",#Instance(cursor.getPos()))) };
            case 'S' { #ok(createToken(#Metacharacter(#NonWhitespace), "\\S",#Instance(cursor.getPos()))) };
            case 'b' { #ok(createToken(#Anchor(#WordBoundary), "\\b",#Instance(cursor.getPos()))) };
            case 'B' { #ok(createToken(#Anchor(#NonWordBoundary), "\\B",#Instance(cursor.getPos()))) };
            case 'A' { #ok(createToken(#Anchor(#StartOfStringOnly), "\\A",#Instance(cursor.getPos()))) };
            case 'z' { #ok(createToken(#Anchor(#EndOfStringOnly), "\\z",#Instance(cursor.getPos()))) };
            case 'G' { #ok(createToken(#Anchor(#PreviousMatchEnd), "\\G",#Instance(cursor.getPos()))) };
            case _ { #ok(createToken(#Character(cursor.current()), "\\" # Text.fromChar(cursor.current()),#Instance(cursor.getPos()))) };
      }
    };

    private func tokenizeQuantifierRange() : Result.Result<Types.Token, Types.LexerError> {
    start := cursor.getPos();
    cursor.inc();

    while (cursor.hasNext() and cursor.current() != '}') {
        cursor.inc();
    };

    if (not cursor.hasNext() and cursor.current() != '}') {
        return #err(#InvalidQuantifierRange(Extensions.slice(input, start, ?cursor.getPos())));
    };

    cursor.inc();

    #ok(createToken(#QuantifierRange, Extensions.slice(input, start, ?cursor.getPos()),#Span(start, cursor.getPos())))
    };
    private func applyQuantifier(quantifier: Types.QuantifierType) : Result.Result<Types.Token, Types.LexerError> {
    if (tokenBuffer.size() == 0) {
        return #err(#GenericError("Quantifier without preceding token"));
    };

    let previousToken = Buffer.last(tokenBuffer);

    let (finalQuantifier, additionalChar) = if (cursor.hasNext()) {
        switch (cursor.peekNext()) {
        case '?' {
            cursor.inc();
            switch (quantifier) {
            case (#ZeroOrMore(_)) (#ZeroOrMore(#Lazy), "?");
            case (#OneOrMore(_)) (#OneOrMore(#Lazy), "?");
            case (#ZeroOrOne(_)) (#ZeroOrOne(#Lazy), "?");
            case (#Range(min, max)) (#Range(min, max), "");
            }
        };
        case '+' {
            cursor.inc();
            switch (quantifier) {
            case (#ZeroOrMore(_)) (#ZeroOrMore(#Possessive), "+");
            case (#OneOrMore(_)) (#OneOrMore(#Possessive), "+");
            case (#ZeroOrOne(_)) (#ZeroOrOne(#Possessive), "+");
            case (#Range(min, max)) (#Range(min, max), "");
            }
        };
        case _ { (quantifier, "") };
        };
    } else {
        (quantifier, "");
    };

    let quantifierToken = createToken(#Quantifier(finalQuantifier),
        previousToken.value # (
        switch finalQuantifier {
            case (#ZeroOrMore(_)) "*";
            case (#OneOrMore(_)) "+";
            case (#ZeroOrOne(_)) "?";
            case (#Range(min, max)) {
            "{" # Nat.toText(min) #
            (switch max {
                case null "";
                case (?m) "," # Nat.toText(m) 
            }) # "}"
            };
        }
        ) # additionalChar, #Span(start, cursor.getPos())
    );

    tokenBuffer.add(quantifierToken);
    #ok(quantifierToken)
    };
     private func applyQuantifierToClassTokens(
        quantifier: Types.QuantifierType,
        classTokens: [Types.CharacterClass],
        isNegated: Bool,
        start: Nat
        ) : Result.Result<Types.Token, Types.LexerError> {
        let quantifiedClassTokens = Array.map<Types.CharacterClass, Types.CharacterClass>(
            classTokens,
            func (ct : Types.CharacterClass) : Types.CharacterClass {
                #Quantified(ct, quantifier)
            }
        );
        #ok(createToken(#CharacterClass(isNegated, quantifiedClassTokens), Extensions.slice(input, start, ?cursor.getPos()),#Span(start, cursor.getPos())))
    };
  };
};