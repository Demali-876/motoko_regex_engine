import Debug "mo:base/Debug";
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
                                  node := ?#node(#Quantifier(quantType, n));
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
