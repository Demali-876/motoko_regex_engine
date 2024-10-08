import Nat "mo:base/Nat";
import Types "Types";
import Result "mo:base/Result";

module {
  public type ParserError = Types.RegexError;
  public type Token = Types.Token;
  public type AST = Types.AST;

  public class Parser(initialTokens: [Token]) {
    var tokens = initialTokens;
    var cursor : Nat = 0;
    var captureGroupIndex = 1;
    public func parse(): Result.Result<AST, ParserError> {
      parseAlternation()
    };

    private func parseAlternation(): Result.Result<AST, ParserError> {
      var left = parseConcatenation();
      label l while (cursor < tokens.size()) {
        switch (peekToken()) {
          case (?token) {
            if (token.tokenType == #Alternation) {
              ignore advanceCursor();
              switch (parseConcatenation()) {
                case (#ok(right)) {
                  switch (left) {
                    case (#ok(l)) {
                      left := #ok(#Alternation([l, right]));
                    };
                    case (#err(error)) {
                      return #err(error);
                    };
                  };
                };
                case (#err(error)) {
                  return #err(error);
                };
              };
            } else { break l; };
          };
          case (null) { break l; };
        };
      };
      left
    };

    private func parseConcatenation(): Result.Result<AST, ParserError> {
      var left = parseQuantifier();
      label l while (cursor < tokens.size()) {
        switch (peekToken()) {
          case (?token) {
            if (token.tokenType != #Alternation) {
              switch (parseQuantifier()) {
                case (#ok(right)) {
                  switch (left) {
                    case (#ok(l)) {
                      left := #ok(#Concatenation([l, right]));
                    };
                    case (#err(error)) {
                      return #err(error);
                    };
                  };
                };
                case (#err(error)) {
                  return #err(error);
                };
              };
            } else { break l; };
          };
          case (null) { break l; };
        };
      };
      left
    };

    private func parseQuantifier(): Result.Result<AST, ParserError> {
      var node = parsePrimary();

      if (cursor < tokens.size()) {
        switch (peekToken()) {
          case (?token) {
            switch (token.tokenType) {
              case (#Quantifier(quantType)) {
                ignore advanceCursor();
                switch (node) {
                  case (#ok(n)) {
                    node := #ok(#Quantifier({
                      subExpr = n;
                      min = quantType.min;
                      max = quantType.max;
                      mode = quantType.mode;
                    }));
                  };
                  case (#err(error)) {
                    return #err(error);
                  };
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

   private func parsePrimary(): Result.Result<AST, ParserError> {
      switch (advanceCursor()) {
        case (?token) {
          switch (token.tokenType) {
            case (#Character(char)) {
              #ok(#Character(char));
            };
            case (#Group(groupData)) {
              // Determine if this is a capturing group
              let isCapturing = switch (groupData.modifier) {
                case (?#NonCapturing) { false };
                case (_) { true };
              };
              // Assign capture index for capturing groups
              let currentCaptureIndex = if (isCapturing) {
                let index = captureGroupIndex;
                captureGroupIndex += 1;  // Increment for the next capturing group
                ?index;
              } else {
                null;
              };

              switch (parseGroup(groupData)) {
                case (#ok(groupNode)) {
                  #ok(#Group({
                    subExpr = groupNode;
                    modifier = switch (groupData.modifier) {
                      case (?mod) { ?mod };
                      case (null) {
                        if (isCapturing) { null } else { ?#NonCapturing };
                      };
                    };
                    captureIndex = currentCaptureIndex;
                  }));
                };
                case (#err(error)) {
                  #err(error);
                };
              };
            };
            case (#CharacterClass(isNegated, classes)) {
              #ok(#CharacterClass({
                isNegated = isNegated;
                classes = classes;
              }));
            };
            case (#Anchor(anchorType)) {
              #ok(#Anchor(anchorType));
            };
            case (#Metacharacter(metaType)) {
              #ok(#Metacharacter(metaType));
            };
            case (_) {
              #err(#GenericError("Unexpected token: " # debug_show(token.tokenType)));
            };
          };
        };
        case (null) {
          #err(#UnexpectedEndOfInput);
        };
      };
    };

    private func parseGroup(groupData: {modifier: ?Types.GroupModifierType; subTokens: [Token]}): Result.Result<AST, ParserError> {
      // Save current state
      let savedTokens = tokens;
      let savedCursor = cursor;

      // Set new state for parsing the group
      tokens := groupData.subTokens;
      cursor := 0;

      // Parse the group
      let result = parseAlternation();

      // Restore previous state
      tokens := savedTokens;
      cursor := savedCursor;

      result
    };

    private func peekToken(): ?Token {
      if (cursor < tokens.size()) {
        ?tokens[cursor]
      } else {
        null
      }
    };

    private func advanceCursor(): ?Token {
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
