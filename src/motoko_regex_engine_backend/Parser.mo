import Debug "mo:base/Debug";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Types "Types";

module {
  public class Parser(tokens: [Types.Token]) {
    var cursor: Nat = 0;

    public func parse(): ?Types.AST {
      parseAlternation()
    };

     private func parseAlternation(): ?Types.AST {
      var left = parseConcatenation();
      label l while (cursor < tokens.size()) {
        switch (peekToken()) {
          case (?token) {
            if (token.tokenType == #Alternation) {
              ignore advanceCursor();
              switch (parseConcatenation()) {
                case (?right) {
                  switch (left) {
                    case (?l) {
                      left := ?#node(#Alternation(l, right));

                    };
                    case null { break l; };
                  };
                };
                case (null) { break l; };
              };
            } else { break l; };
          };
          case (null) { break l; };
        };
      };
      left
    };

    private func parseConcatenation(): ?Types.AST {
      var left = parseQuantifier();
      label l while (cursor < tokens.size()) {
        switch (peekToken()) {
          case (?token) {
            if (token.tokenType != #Alternation and token.tokenType != #GroupEnd) {
              switch (parseQuantifier()) {
                case (?right) {
                  switch (left) {
                    case (?l) {
                      left := ?#node(#Concatenation(l, right));
                    };
                    case null { break l; };
                  };
                };
                case (null) { break l; };
              };
            } else { break l; };
          };
          case (null) { break l; };
        };
      };
      left
    };

    private func parseQuantifier(): ?Types.AST {
    var node = parsePrimary();
    if (cursor < tokens.size()) {
        switch (peekToken()) {
        case (?token) {
            switch (token.tokenType) {
            case (#Quantifier(quantType)) {
                ignore advanceCursor();
                switch (node) {
                case (?n) {
                    // Check if the next token is a lazy or possessive quantifier
                    let nextToken = peekToken();
                    switch (nextToken) {
                    case (?t) {
                        switch (t.tokenType) {
                        case (#Quantifier(#Lazy)) {
                            ignore advanceCursor();
                            node := ?#node(#Quantifier(#Lazy, n));
                        };
                        case (#Quantifier(#Possessive)) {
                            ignore advanceCursor();
                            node := ?#node(#Quantifier(#Possessive, n));
                        };
                        case (_) {
                            node := ?#node(#Quantifier(quantType, n));
                        };
                        };
                    };
                    case null {
                        node := ?#node(#Quantifier(quantType, n));
                    };
                    };
                };
                case null {};
                };
            };
            case (#QuantifierRange) {
                let rangeToken = advanceCursor();
                switch (rangeToken) {
                case (?rt) {
                    let (min, max) = parseQuantifierRange(rt.value);
                    switch (node) {
                    case (?n) {
                        node := ?#node(#Quantifier(#Range(min, max), n));
                    };
                    case null {};
                    };
                };
                case null {};
                };
            };
            case (_) {};
            };
        };
        case (null) {};
        };
    };
    node
    };



    private func parsePrimary(): ?Types.AST {
      switch (advanceCursor()) {
        case (?token) {
          switch (token.tokenType) {
            case (#Character(char)) {
              ?#node(#Character(char));
            };
            case (#GroupStart) {
              switch (parseAlternation()) {
                case (?groupNode) {
                  switch (expectToken(#GroupEnd)) {
                    case (?_) {
                      ?#node(#Group(groupNode));
                    };
                    case null { null };
                  };
                };
                case (null) { null };
              };
            };
            case (#CharacterClass(isNegated, classes)) {
              ?#node (#CharacterClass(isNegated, classes)); 
            };
            case (#Anchor(anchorType)) {
              ?#node(#Anchor(anchorType));
            };
            case (#Metacharacter(metaType)) {
              ?#node (#Metacharacter(metaType));
            };
            case (_) {
              Debug.print("Unexpected token: " # debug_show(token.tokenType));
              null
            };
          };
        };
        case (null) { null };
      }
    };

    private func parseQuantifierRange(value: Text): (Nat, ?Nat) {
      let chars = Text.toIter(value);
      var min: Nat = 0;
      var max: ?Nat = null;
      var parsingMin = true;
      
      label l for (char in chars) {
        if (char == '{' or char == '}') {
          continue l;
        };
        if (char == ',') {
          parsingMin := false;
          continue l;
        };
        switch (Nat.fromText(Text.fromChar(char))) {
          case (?d) {
            if (parsingMin) {
              min := min * 10 + d;
            } else {
              max := switch (max) {
                case (null) ?d;
                case (?m) ?(m * 10 + d);
              };
            };
          };
          case (null) {
            Debug.print("Invalid character in quantifier range: " # Text.fromChar(char));
            return (0, null);
          };
        };
      };
      
      (min, max)
    };

    private func expectToken(expectedType: Types.TokenType): ?Types.Token {
      switch (advanceCursor()) {
        case (?token) {
          if (token.tokenType != expectedType) {
            Debug.print("Expected " # debug_show(expectedType) # " but found " # debug_show(token.tokenType));
            null
          } else {
            ?token
          };
        };
        case (null) {
          Debug.print("Unexpected end of input");
          null
        };
      }
    };

    private func peekToken(): ?Types.Token {
      if (cursor < tokens.size()) {
        ?tokens[cursor]
      } else {
        null
      }
    };

    private func advanceCursor(): ?Types.Token {
      if (cursor < tokens.size()) {
        let token = tokens[cursor];
        cursor += 1;
        ?token
      } else {
        null
      }
    };
  };
};