import Types "Types";
import Buffer "mo:base/Buffer";
import Order "mo:base/Order";
import Iter "mo:base/Iter";
import Char "mo:base/Char";
import Array "mo:base/Array";
import Extensions "Extensions";

module {
  public class Compiler() {
    private var nextState : Types.State = 0;
    private var captureGroups = Buffer.Buffer<Types.CaptureGroup>(8);

    public func compile(ast : Types.AST) : Types.CompiledRegex {
      let transitions = Buffer.Buffer<(Types.State, Types.Transition, Types.State)>(16);
      let (start, end) = switch (ast) {
        case (#node(node)) compileNode(node, transitions);
        };
        
      {
        transitions = Buffer.toArray(transitions);
        startState = start;
        acceptStates = [end];
        captureGroups = Buffer.toArray(captureGroups);
      }
    };

    private func compileNode(node : Types.ASTNode, transitions : Buffer.Buffer<(Types.State, Types.Transition, Types.State)>) : (Types.State, Types.State) {
      switch (node) {
        case (#Character(char)) compileCharacter(char, transitions);
        case (#Concatenation(left, right)) compileConcatenation(left, right, transitions);
        case (#Alternation(left, right)) compileAlternation(left, right, transitions);
        case (#Quantifier(quantType, subExpr)) compileQuantifier(quantType, subExpr, transitions);
        case (#Group(subExpr)) compileGroup(subExpr, transitions);
        case (#CharacterClass(isNegated, classes,)) compileCharacterClass(isNegated, classes, transitions);
        case (#Anchor(anchorType)) compileAnchor(anchorType, transitions);
        case (#Metacharacter(metaType)) compileMetacharacter(metaType, transitions);
      }
    };

    private func compileCharacter(char : Char, transitions : Buffer.Buffer<(Types.State, Types.Transition, Types.State)>) : (Types.State, Types.State) {
      let start = nextState;
      nextState += 1;
      let end = nextState;
      nextState += 1;
      transitions.add((start, #Char(char), end));
      (start, end)
    };

    private func compileConcatenation(left : Types.AST, right : Types.AST, transitions : Buffer.Buffer<(Types.State, Types.Transition, Types.State)>) : (Types.State, Types.State) {
        let (leftStart, leftEnd) = switch (left) {
        case (#node(node)) compileNode(node, transitions);
        };
        let (rightStart, rightEnd) = switch (right) {
        case (#node(node)) compileNode(node, transitions);
        };
      transitions.add((leftEnd, #Epsilon, rightStart));
      (leftStart, rightEnd)
    };

    private func compileAlternation(left : Types.AST, right : Types.AST, transitions : Buffer.Buffer<(Types.State, Types.Transition, Types.State)>) : (Types.State, Types.State) {
      let start = nextState;
      nextState += 1;
      let (leftStart, leftEnd) = switch (left) {
        case (#node(node)) compileNode(node, transitions);
        };
        let (rightStart, rightEnd) = switch (right) {
        case (#node(node)) compileNode(node, transitions);
        };
      let end = nextState;
      nextState += 1;
      transitions.add((start, #Epsilon, leftStart));
      transitions.add((start, #Epsilon, rightStart));
      transitions.add((leftEnd, #Epsilon, end));
      transitions.add((rightEnd, #Epsilon, end));
      (start, end)
    };

    private func compileQuantifier(quantType : Types.QuantifierType, subExpr : Types.AST, transitions : Buffer.Buffer<(Types.State, Types.Transition, Types.State)>) : (Types.State, Types.State) {
    let (subStart, subEnd) = switch (subExpr) {
      case (#node(node)) compileNode(node, transitions);
    };
    let start = nextState;
    nextState += 1;
    let end = nextState;
    nextState += 1;

    switch (quantType) {
      case (#ZeroOrMore(mode)) {
        switch (mode) {
          case (#Greedy){
            transitions.add((start, #Epsilon, subStart));
            transitions.add((start, #Epsilon, end));
            transitions.add((subEnd, #Epsilon, subStart));
            transitions.add((subEnd, #Epsilon, end));
          };
          case (#Lazy){
            transitions.add((start, #Epsilon, end));
            transitions.add((start, #Epsilon, subStart));
            transitions.add((subEnd, #Epsilon, start));
          };
          case (#Possessive){
            transitions.add((start, #Epsilon, subStart));
            transitions.add((subEnd, #Epsilon, end));
          };
        };
      };
      case (#OneOrMore(mode)) {
        switch (mode) {
          case (#Greedy){
            transitions.add((start, #Epsilon, subStart));
            transitions.add((subEnd, #Epsilon, subStart));
            transitions.add((subEnd, #Epsilon, end));
          };
          case (#Lazy){
            transitions.add((start, #Epsilon, subStart));
            transitions.add((subEnd, #Epsilon, start));
            transitions.add((start, #Epsilon, end));
          };
          case (#Possessive){
            transitions.add((start, #Epsilon, subStart));
            transitions.add((subEnd, #Epsilon, end));
          };
        };
      };
      case (#ZeroOrOne(mode)) {
        switch (mode) {
          case (#Greedy){
            transitions.add((start, #Epsilon, subStart));
            transitions.add((start, #Epsilon, end));
            transitions.add((subEnd, #Epsilon, end));
          };
          case (#Lazy){
            transitions.add((start, #Epsilon, end));
            transitions.add((start, #Epsilon, subStart));
            transitions.add((subEnd, #Epsilon, end));
          };
          case (#Possessive){
            transitions.add((start, #Epsilon, subStart));
            transitions.add((subEnd, #Epsilon, end));
          };
        };
      };
      case (#Range(min, max)) {
        var currentState = start;

        // Create a chain of 'min' repetitions
        for (_ in Iter.range(0, min - 1)) {
          let nextState = getNextState();
          transitions.add((currentState, #Epsilon, subStart));
          transitions.add((subEnd, #Epsilon, nextState));
          currentState := nextState;
        };

        switch (max) {
          case (null) {
            // Infinite upper bound
            transitions.add((currentState, #Epsilon, subStart));
            transitions.add((subEnd, #Epsilon, currentState));
            transitions.add((currentState, #Epsilon, end));
          };
          case (?maxVal) {
            if (maxVal > min) {
              // Add optional repetitions
              for (_ in Iter.range(0, maxVal - min - 1)) {
                let nextState = getNextState();
                transitions.add((currentState, #Epsilon, subStart));
                transitions.add((currentState, #Epsilon, nextState));
                transitions.add((subEnd, #Epsilon, nextState));
                currentState := nextState;
              };
            };
            transitions.add((currentState, #Epsilon, end));
          };
        };
      };
    };

    (start, end)
  };

    private func getNextState() : Types.State {
      let state = nextState;
      nextState += 1;
      state
    };


    private func compileGroup(subExpr : Types.AST, transitions : Buffer.Buffer<(Types.State, Types.Transition, Types.State)>) : (Types.State, Types.State) {
      let start = nextState;
      nextState += 1;
      let (subStart, subEnd) = switch (subExpr) {
        case (#node(node)) compileNode(node, transitions);
        };
      let end = nextState;
      nextState += 1;
      transitions.add((start, #Epsilon, subStart));
      transitions.add((subEnd, #Epsilon, end));
      captureGroups.add({ startState = start; endState = end });
      (start, end)
    };

    private func compileCharacterClass(isNegated : Bool, classes : [Types.CharacterClass], transitions : Buffer.Buffer<(Types.State, Types.Transition, Types.State)>) : (Types.State, Types.State) {
      let start = nextState;
      nextState += 1;
      let end = nextState;
      nextState += 1;
      let ranges = Buffer.Buffer<(Char, Char)>(classes.size());

      for (c in classes.vals()) {
        switch (c) {
          case (#Single(char)) {
            ranges.add((char, char));
          };
          case (#Range(from, to)) {
            ranges.add((from, to));
          };
          case (#Metacharacter(metaType)) {
            let metaRanges = Extensions.metacharToRanges(metaType);
            for (range in metaRanges.vals()) {
              ranges.add(range);
            };
          };
          case (#Quantified(charClass, quantType)) {
            // Handle quantifiers directly by adding transitions, no need to add to ranges.
            let _ = compileQuantifier(quantType, #node(#CharacterClass(isNegated, [charClass])), transitions);
          };
        };
      };

      // Sort and merge overlapping ranges
      let sortedRanges : [(Char, Char)] = Buffer.toArray(ranges);
      ignore Array.sort<(Char, Char)>(sortedRanges, func(a : (Char, Char), b : (Char, Char)) : Order.Order {
        Char.compare(a.0, b.0)
      });
      let mergedRanges = Buffer.Buffer<(Char, Char)>(sortedRanges.size());
      for (range in sortedRanges.vals()) {
        switch (mergedRanges.removeLast()) {
          case (null) {
            mergedRanges.add(range);
          };
          case (?lastRange) {
            if (Char.toNat32(range.0) <= Char.toNat32(lastRange.1) + 1) {
              mergedRanges.add((lastRange.0, Extensions.maxChar(lastRange.1, range.1)));
            } else {
              mergedRanges.add(lastRange);
              mergedRanges.add(range);
            };
          };
        };
      };

      // Add transitions based on merged ranges
      if (isNegated) {
        var lastChar : Char = Char.fromNat32(0);
        for (range in mergedRanges.vals()) {
          if (Char.toNat32(lastChar) < Char.toNat32(range.0)) {
            transitions.add((start, #Range(lastChar, Char.fromNat32(Char.toNat32(range.0) - 1)), end));
          };
          lastChar := Char.fromNat32(Char.toNat32(range.1) + 1);
        };
        if (Char.toNat32(lastChar) <= 255) {
          transitions.add((start, #Range(lastChar, Char.fromNat32(255)), end));
        };
      } else {
        for (range in mergedRanges.vals()) {
          transitions.add((start, #Range(range.0, range.1), end));
        };
      };
      (start, end)
  };


    private func compileAnchor(anchorType : Types.AnchorType, transitions : Buffer.Buffer<(Types.State, Types.Transition, Types.State)>) : (Types.State, Types.State) {
    let start = nextState;
    nextState += 1;
    let end = nextState;
    nextState += 1;

    switch (anchorType) {
        case (#StartOfString) {
        transitions.add((start, #Epsilon, end));
        };
        case (#EndOfString) {
        transitions.add((start, #Epsilon, end));
        };
        case (#WordBoundary) {
        transitions.add((start, #Epsilon, end));
        };
        case (#NonWordBoundary) {
        transitions.add((start, #Epsilon, end));
        };
        case (#StartOfStringOnly) {
        transitions.add((start, #Epsilon, end));
        };
        case (#EndOfStringOnly) {
        transitions.add((start, #Epsilon, end));
        };
        case (#PreviousMatchEnd) {
        transitions.add((start, #Epsilon, end));
        };
    };

    (start, end)
    };


    private func compileMetacharacter(metaType : Types.MetacharacterType, transitions : Buffer.Buffer<(Types.State, Types.Transition, Types.State)>) : (Types.State, Types.State) {
    let start = nextState;
    nextState += 1;
    let end = nextState;
    nextState += 1;
    switch (metaType) {
        case (#Dot) {
            transitions.add((start, #Any, end));
        };
        case (_) {
            let metaRanges = Extensions.metacharToRanges(metaType);
            for (range in metaRanges.vals()) {
                transitions.add((start, #Range(range.0, range.1), end));
            }
        };
    };
      (start, end)
      }
    };
}