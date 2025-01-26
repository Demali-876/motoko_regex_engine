import Nat "mo:base/Nat";
import Types "Types";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Char "mo:base/Char";
module {
  public class Parser(initialTokens: [Types.Token]) {
    var tokens = initialTokens;
    var cursor : Nat = 0;
    var captureGroupIndex = 1;
    let maxQuantifier : Nat = 1000; 

    public func parse(): Result.Result<Types.AST, Types.RegexError> {
      cursor := 0;
      captureGroupIndex := 1;
      
      if (tokens.size() == 0) {
        return #err(#GenericError("Empty pattern"));
      };

      let result = parseAlternation();
      
      if (cursor < tokens.size()) {
        return #err(#UnexpectedToken(tokens[cursor].tokenType));
      };

      result
    };

    private func parseAlternation(): Result.Result<Types.AST, Types.RegexError> {
      var nodes: [Types.AST] = [];

      switch (parseConcatenation()) {
        case (#ok(node)) {
          nodes := Array.append(nodes, [node]);
        };
        case (#err(error)) { return #err(error) };
      };

      label aloop while (cursor < tokens.size()) {
        switch (peekToken()) {
          case (?token) {
            if (token.tokenType == #Alternation) {
              ignore advanceCursor();

              switch (peekToken()) {
                case (?nextToken) {
                  if (nextToken.tokenType == #Alternation) {
                    return #err(#GenericError("Empty alternative not allowed in pattern"));
                  };
                };
                case (null) {
                  return #err(#GenericError("Unexpected end of pattern after '|'"));
                };
              };
              
              switch (parseConcatenation()) {
                case (#ok(node)) {
                  nodes := Array.append(nodes, [node]);
                };
                case (#err(error)) { return #err(error) };
              };
            } else {
              break aloop;
            };
          };
          case (null) { break aloop };
        };
      };

      if (nodes.size() == 1) {
        #ok(nodes[0])
      } else if (nodes.size() > 1) {
        #ok(#Alternation(nodes))
      } else {
        #err(#GenericError("Empty pattern"))
      }
    };

    private func parseConcatenation(): Result.Result<Types.AST, Types.RegexError> {
      var nodes: [Types.AST] = [];
      
      switch (peekToken()) {
        case (?token) {
          if (token.tokenType != #Alternation) {
            switch (parseSingleExpression()) {
              case (#ok(node)) {
                nodes := Array.append(nodes, [node]);
              };
              case (#err(error)) { return #err(error) };
            };
          };
        };
        case (null) {};
      };
      
      label cloop while (cursor < tokens.size()) {
        switch (peekToken()) {
          case (?token) {
            switch (token.tokenType) {
              case (#Alternation) { break cloop };
              case (#Group(groupData)) {
                if (groupData.modifier == ?#NegativeLookbehind or 
                    groupData.modifier == ?#PositiveLookbehind) {
                  break cloop;
                };
                switch (parseSingleExpression()) {
                  case (#ok(node)) {
                    nodes := Array.append(nodes, [node]);
                  };
                  case (#err(error)) { return #err(error) };
                };
              };
              case (_) {
                switch (parseSingleExpression()) {
                  case (#ok(node)) {
                    nodes := Array.append(nodes, [node]);
                  };
                  case (#err(error)) { return #err(error) };
                };
              };
            };
          };
          case (null) { break cloop};
        };
      };

      switch (nodes.size()) {
        case 0 { #err(#GenericError("Empty pattern segment")) };
        case 1 { #ok(nodes[0]) };
        case _ { #ok(#Concatenation(nodes)) };
      }
    };

    private func parseSingleExpression(): Result.Result<Types.AST, Types.RegexError> {
  switch (peekToken()) {
    case (?token) {
      switch (token.tokenType) {
        case (#Character(char)) { 
          ignore advanceCursor();
          parseQuantifierIfPresent(#Character(char))
        };
        case (#Metacharacter(metaType)) {
          ignore advanceCursor();
          parseQuantifierIfPresent(#Metacharacter(metaType))
        };
        case (#Anchor(anchorType)) {
          ignore advanceCursor();
          #ok(#Anchor(anchorType))
        };
        case (#CharacterClass(isNegated, classes)) {
          ignore advanceCursor();
          switch (validateCharacterClass(classes)) {
            case (#err(error)) { return #err(error) };
            case (#ok()) {
              let astClasses = Array.map<Types.CharacterClass, Types.AST>(
                classes, 
                characterClassElementToAST
              );
              parseQuantifierIfPresent(#CharacterClass({
                isNegated = isNegated;
                classes = astClasses;
              }))
            };
          };
        };
        case (#Group(groupData)) {
          ignore advanceCursor();
          switch(parseGroup(groupData)) {
            case (#ok(groupAst)) {
              parseQuantifierIfPresent(groupAst)
            };
            case (#err(e)) { #err(e) };
          };
        };
        case (_) {
          #err(#UnexpectedToken(token.tokenType))
        };
      }
    };
    case (null) {
      #err(#UnexpectedEndOfInput)
    };
  }
};

    private func validateCharacterClass(classes: [Types.CharacterClass]): Result.Result<(), Types.RegexError> {
      if (classes.size() == 0) {
        return #err(#GenericError("Empty character class"));
      };

      for (cclass in classes.vals()) {
        switch (cclass) {
          case (#Range(start, end)) {
            if (Char.toNat32(start) > Char.toNat32(end)) {
              return #err(#GenericError("Invalid character range: " # debug_show(start) # "-" # debug_show(end)));
            };
          };
          case (#Quantified(_, quantifier)) {
            if (quantifier.min > maxQuantifier) {
              return #err(#InvalidQuantifier("Quantifier min value too large"));
            };
            switch (quantifier.max) {
              case (?max) {
                if (max > maxQuantifier or max < quantifier.min) {
                  return #err(#InvalidQuantifier("Invalid quantifier range"));
                };
              };
              case (null) {};
            };
          };
          case (_) {};
        };
      };
      #ok()
    };

    private func parseGroup(groupData: {
        modifier: ?Types.GroupModifierType; 
        subTokens: [Types.Token]; 
        quantifier: ?Types.QuantifierType
    }): Result.Result<Types.AST, Types.RegexError> {
        switch (groupData.quantifier) {
            case (?quantifier) {
                if (quantifier.min > maxQuantifier) {
                    return #err(#InvalidQuantifier("Group quantifier min value too large"));
                };
                switch (quantifier.max) {
                    case (?max) {
                        if (max > maxQuantifier or max < quantifier.min) {
                            return #err(#InvalidQuantifier("Invalid group quantifier range"));
                        };
                    };
                    case (null) {};
                };
            };
            case (null) {};
        };

        let savedTokens = tokens;
        let savedCursor = cursor;
        let savedCaptureIndex = captureGroupIndex;

        tokens := groupData.subTokens;
        cursor := 0;

        let result = parseAlternation();

        tokens := savedTokens;
        cursor := savedCursor;

        switch (result) {
            case (#ok(groupNode)) {
                let isCapturing = switch (groupData.modifier) {
                    case (?#NonCapturing) { false };
                    case (_) { true };
                };

                let currentCaptureIndex = if (isCapturing) {
                    let index = captureGroupIndex;
                    captureGroupIndex += 1;
                    ?index
                } else {
                    null
                };

                let groupAST = #Group({
                    subExpr = groupNode;
                    modifier = groupData.modifier;
                    captureIndex = currentCaptureIndex;
                });

                switch (groupData.quantifier) {
                    case (?quantifier) {
                        #ok(#Quantifier({
                            subExpr = groupAST;
                            quantifier = quantifier;
                        }))
                    };
                    case (null) {
                        #ok(groupAST)
                    };
                }
            };
            case (#err(error)) { 
                captureGroupIndex := savedCaptureIndex;
                #err(error) 
            };
        }
    };


   private func parseQuantifierIfPresent(astNode: Types.AST): Result.Result<Types.AST, Types.RegexError> {
  if (cursor < tokens.size()) {
    switch (tokens[cursor].tokenType) {
      case (#Quantifier(quantifier)) {
        switch (astNode) {
          case (#Anchor(_)) {
            #err(#GenericError("Cannot apply quantifier to an anchor"))
          };
          case (#Group({ modifier = ?_; subExpr =_; })) {
            #err(#GenericError("Cannot apply quantifier to a lookaround assertion"))
          };
          case (#Quantifier(_)) {
            #err(#GenericError("Cannot directly quantify a quantified expression"))
          };
          case (_) {
            if (quantifier.min > maxQuantifier) {
              return #err(#InvalidQuantifier("Quantifier min value too large"));
            };
            switch (quantifier.max) {
              case (?max) {
                if (max > maxQuantifier or max < quantifier.min) {
                  return #err(#InvalidQuantifier("Invalid quantifier range"));
                };
              };
              case (null) {};
            };
            ignore advanceCursor();
            #ok(#Quantifier({
              subExpr = astNode;
              quantifier = quantifier;
            }))
          };
        }
      };
      case (_) {
        #ok(astNode)
      };
    }
  } else {
    #ok(astNode)
  }
};


    private func characterClassElementToAST(classElement: Types.CharacterClass): Types.AST {
      switch (classElement) {
        case (#Single(char)) {
          #Character(char)
        };
        case (#Range(startChar, endChar)) {
          #Range((startChar, endChar))
        };
        case (#Metacharacter(metaType)) {
          #Metacharacter(metaType)
        };
        case (#Quantified(classItem, quantifier)) {
          let subAst = characterClassElementToAST(classItem);
          #Quantifier({
            subExpr = subAst;
            quantifier = quantifier;
          })
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