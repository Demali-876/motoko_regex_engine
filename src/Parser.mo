import Nat "mo:base/Nat";
import Types "Types";
import Result "mo:base/Result";
import Array "mo:base/Array";

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
    
    // Entry point for parsing alternations
    private func parseAlternation(): Result.Result<AST, ParserError> {
      var nodes: [AST] = [];
      label alternationLoop while (cursor < tokens.size()) {
        switch (parseConcatenation()) {
          case (#ok(node)) {
            nodes := Array.append(nodes, [node]);
          };
          case (#err(error)) { return #err(error) };
        };
        switch (peekToken()) {
          case (?token) {
            if (token.tokenType == #Alternation) {
              ignore advanceCursor(); // Consume '|'
            } else {
              break alternationLoop;
            }
          };
          case (null) { break alternationLoop };
        };
      };
      if (nodes.size() == 1) {
        #ok(nodes[0])
      } else {
        #ok(#Alternation(nodes))
      }
    };

    // Parses concatenated expressions
    private func parseConcatenation(): Result.Result<AST, ParserError> {
      var nodes: [AST] = [];
      label concatLoop while (cursor < tokens.size()) {
        switch (peekToken()) {
          case (?token) {
            if (token.tokenType == #Alternation) {
              break concatLoop;
            } else {
              switch (parseSingleExpression()) {
                case (#ok(node)) {
                  nodes := Array.append(nodes, [node]);
                };
                case (#err(error)) { return #err(error) };
              };
            }
          };
          case (null) { break concatLoop };
        };
      };
      if (nodes.size() == 1) {
        #ok(nodes[0])
      } else {
        #ok(#Concatenation(nodes))
      }
    };

    // Parses a single expression, including quantifiers
    private func parseSingleExpression(): Result.Result<AST, ParserError> {
      switch (peekToken()) {
        case (?token) {
          switch (token.tokenType) {
            case (#Character(_)) { parsePrimary() };
            case (#Metacharacter(_)) { parsePrimary() };
            case (#Anchor(_)) { parsePrimary() };
            case (#CharacterClass(_, _)) { parsePrimary() };
            case (#Group(_)) { parsePrimary() };
            case (_) {
              #err(#GenericError("Unexpected token: " # debug_show(token.tokenType)))
            };
          }
        };
        case (null) { #err(#UnexpectedEndOfInput) };
      }
    };

    // Parses primary expressions (characters, groups, character classes)
    private func parsePrimary(): Result.Result<AST, ParserError> {
      switch (advanceCursor()) {
        case (?token) {
          switch (token.tokenType) {
            case (#Character(char)) {
              let node = #Character(char);
              parseQuantifierIfPresent(node)
            };
            case (#Metacharacter(metaType)) {
              let node = #Metacharacter(metaType);
              parseQuantifierIfPresent(node)
            };
            case (#Anchor(anchorType)) {
              let node = #Anchor(anchorType);
              parseQuantifierIfPresent(node)
            };
            case (#CharacterClass(isNegated, classes)) {
              // Convert classes to AST nodes
              let astClasses = Array.map<Types.CharacterClass, AST>(classes, characterClassElementToAST);
              let node = #CharacterClass({
                isNegated = isNegated;
                classes = astClasses;
              });
              parseQuantifierIfPresent(node)
            };
            case (#Group(groupData)) {
              // Parse the group's subTokens into an AST
              let groupResult = parseGroup(groupData);
              switch (groupResult) {
                case (#ok(groupNode)) {
                  #ok(groupNode)
                };
                case (#err(error)) { #err(error) };
              };
            };
            case (_) {
              #err(#GenericError("Unexpected token: " # debug_show(token.tokenType)))
            };
          }
        };
        case (null) {
          #err(#UnexpectedEndOfInput)
        };
      }
    };

    // Helper function to convert CharacterClass elements to AST nodes
    private func characterClassElementToAST(classElement: Types.CharacterClass): AST {
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

    // Parses a group by recursively parsing its subTokens
    private func parseGroup(groupData: {modifier: ?Types.GroupModifierType; subTokens: [Token]; quantifier: ?Types.QuantifierType}): Result.Result<AST, ParserError> {
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

      // Apply quantifier if present in groupData
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
            case null {
              #ok(groupAST)
            };
          }
        };
        case (#err(error)) { #err(error) };
      }
    };

    // Parses quantifiers if present in the next token
    private func parseQuantifierIfPresent(astNode: AST): Result.Result<AST, ParserError> {
      if (cursor < tokens.size()) {
        switch (tokens[cursor].tokenType) {
          case (#Quantifier(quantifier)) {
            ignore advanceCursor(); // Consume the quantifier token
            #ok(#Quantifier({
              subExpr = astNode;
              quantifier = quantifier;
            }))
          };
          case (_) {
            #ok(astNode)
          };
        }
      } else {
        #ok(astNode)
      }
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
