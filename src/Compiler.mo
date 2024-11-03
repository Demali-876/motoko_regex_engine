import Types "Types";
import Buffer "mo:base/Buffer";
import Order "mo:base/Order";
import Iter "mo:base/Iter";
import Char "mo:base/Char";
import Array "mo:base/Array";
import Extensions "Extensions";
import Optimizer "Optimizer";

module { /*
 public class Compiler() {
  type State = Types.State;
  type NFA = Types.CompiledRegex;
  type Transition = Types.Transition;
  type TransitionTable = Types.TransitionTable;

    public func compile(ast: Types.ASTNode): NFA {
      let startState: State = 0;
      let (transitionTable, acceptStates) = buildNFA(ast, startState);
      {
        transitions = transitionTable;
        startState = startState;
        acceptStates = acceptStates;
      }
    };

    public func buildNFA(ast: Types.ASTNode, startState: State): (TransitionTable, [State]) {
      switch (ast) {

        case (#Character(char)) {
          let acceptState: State = startState + 1;
          let transition: Transition = #Char(char);
          let transitionTable: TransitionTable = [(startState, transition, acceptState)];
          (transitionTable, [acceptState]);
        };

        case (#Concatenation(subExprs)) {
          var currentStartState: State = startState;
          let transitionBuffer = Buffer.Buffer<(State, Transition, State)>(subExprs.size());
          var acceptStates: [State] = [];

          for (subExpr in subExprs.vals()) {
            let (subTransitionTable, subAcceptStates) = buildNFA(subExpr, currentStartState);
            for ((fromState, transition, toState) in subTransitionTable.vals()) {
              transitionBuffer.add((fromState, transition, toState));
            };
            currentStartState := subAcceptStates[0];
            acceptStates := subAcceptStates;
          };

          (Buffer.toArray(transitionBuffer), acceptStates);
        };

        case (#Alternation(subExprs)) {
          let newStartState: State = startState;
          let newAcceptState: State = newStartState + subExprs.size() + 1;
          let transitionBuffer = Buffer.Buffer<(State, Transition, State)>(subExprs.size() * 2);
          var acceptStates: [State] = [newAcceptState];

          for (subExpr in subExprs.vals()) {
            let (subTransitionTable, subAcceptStates) = buildNFA(subExpr, newStartState + 1);
            transitionBuffer.add((newStartState, #Epsilon, subTransitionTable[0].0));

            for ((fromState, transition, toState) in subTransitionTable.vals()) {
              transitionBuffer.add((fromState, transition, toState));
            };

            for (acceptState in subAcceptStates.vals()) {
              transitionBuffer.add((acceptState, #Epsilon, newAcceptState));
            };
          };

          (Buffer.toArray(transitionBuffer), acceptStates);
        };

       case (#Quantifier { subExpr; min; max; mode }) {
        let transitionBuffer = Buffer.Buffer<(State, Transition, State)>(10);
        let (subTransitionTable, subAcceptStates) = buildNFA(subExpr, startState + 1);
        let quantifierStartState: State = startState;
        let quantifierAcceptState: State = startState + subTransitionTable.size() + 2;

        // Assign default max value (100) if max is null
        let maxVal = switch (max) {
          case (null) 100;
          case (?value) value;
        };

        for ((fromState, transition, toState) in subTransitionTable.vals()) {
          transitionBuffer.add((fromState, transition, toState));
        };

        if (min == 0 and max == null) {
          switch (mode) {
            case (#Greedy) {
              transitionBuffer.add((quantifierStartState, #Epsilon, subTransitionTable[0].0));
              for (acceptState in subAcceptStates.vals()) {
                transitionBuffer.add((acceptState, #Epsilon, quantifierAcceptState)); // Exit loop
                transitionBuffer.add((acceptState, #Epsilon, quantifierStartState)); // Loop back
              };
            };
            case (#Lazy) {
              transitionBuffer.add((quantifierStartState, #Epsilon, quantifierAcceptState)); // Match 0 times first
              transitionBuffer.add((quantifierStartState, #Epsilon, subTransitionTable[0].0)); // Try to match sub-expression
              for (acceptState in subAcceptStates.vals()) {
                transitionBuffer.add((acceptState, #Epsilon, quantifierStartState)); // Loop back for more matches
              };
            };
            case (#Possessive) {
              transitionBuffer.add((quantifierStartState, #Epsilon, subTransitionTable[0].0));
              for (acceptState in subAcceptStates.vals()) {
                transitionBuffer.add((acceptState, #Epsilon, quantifierAcceptState)); // Exit loop, no backtracking
              };
            };
          };
        } else if (min == 1 and max == null) {
          switch (mode) {
            case (#Greedy) {
              transitionBuffer.add((quantifierStartState, #Epsilon, subTransitionTable[0].0));
              for (acceptState in subAcceptStates.vals()) {
                transitionBuffer.add((acceptState, #Epsilon, quantifierAcceptState));
                transitionBuffer.add((acceptState, #Epsilon, quantifierStartState));
              };
            };
            case (#Lazy) {
              transitionBuffer.add((quantifierStartState, #Epsilon, subTransitionTable[0].0));
              transitionBuffer.add((quantifierStartState, #Epsilon, quantifierAcceptState)); // Try to match 0 times
              for (acceptState in subAcceptStates.vals()) {
                transitionBuffer.add((acceptState, #Epsilon, quantifierStartState));
              };
            };
            case (#Possessive) {
              transitionBuffer.add((quantifierStartState, #Epsilon, subTransitionTable[0].0));
              for (acceptState in subAcceptStates.vals()) {
                transitionBuffer.add((acceptState, #Epsilon, quantifierAcceptState));
              };
            };
          };
        } else if (min == 0 and max == ?1) {
          switch (mode) {
            case (#Greedy) {
              transitionBuffer.add((quantifierStartState, #Epsilon, subTransitionTable[0].0));
              for (acceptState in subAcceptStates.vals()) {
                transitionBuffer.add((acceptState, #Epsilon, quantifierAcceptState));
              };
            };
            case (#Lazy) {
              transitionBuffer.add((quantifierStartState, #Epsilon, quantifierAcceptState)); // Match 0 times first
              transitionBuffer.add((quantifierStartState, #Epsilon, subTransitionTable[0].0)); // Try to match 1 time
            };
            case (#Possessive) {
              transitionBuffer.add((quantifierStartState, #Epsilon, subTransitionTable[0].0));
              for (acceptState in subAcceptStates.vals()) {
                transitionBuffer.add((acceptState, #Epsilon, quantifierAcceptState)); // Exit, no backtracking
              };
            };
          };
        } else if (min > 0 and max != null) {
          var currentStartState = quantifierStartState;
          for (i in Iter.range(0, min - 1)) {
            let (subTrans, subAcc) = buildNFA(subExpr, currentStartState + 1);
            for ((fromState, transition, toState) in subTrans.vals()) {
              transitionBuffer.add((fromState, transition, toState));
            };
            currentStartState := subAcc[0];
          };

          for (i in Iter.range(min, maxVal - 1)) {
            let (subTrans, subAcc) = buildNFA(subExpr, currentStartState + 1);
            for ((fromState, transition, toState) in subTrans.vals()) {
              transitionBuffer.add((fromState, transition, toState));
            };
            currentStartState := subAcc[0];
          };
        };

        (Buffer.toArray(transitionBuffer), [quantifierAcceptState]);
      };

        case (#Group { subExpr; captureIndex; modifier }) {
          let transitionBuffer = Buffer.Buffer<(State, Transition, State)>(10);
          let groupStartState: State = startState;
          let groupEndState: State = groupStartState + 1;

          switch (modifier) {
            case null {
              let (subTransitionTable, subAcceptStates) = buildNFA(subExpr, groupStartState + 1);

              for ((fromState, transition, toState) in subTransitionTable.vals()) {
                transitionBuffer.add((fromState, transition, toState));
              };

              for (acceptState in subAcceptStates.vals()) {
                transitionBuffer.add((acceptState, #Epsilon, groupEndState));
              };

              if (captureIndex != null) {
                transitionBuffer.add((groupStartState, #Group {startState = groupStartState; endState = groupEndState; captureIndex}, groupEndState));
              };

              (Buffer.toArray(transitionBuffer), [groupEndState]);
            };

            case (?#NonCapturing) {
              let (subTransitionTable, subAcceptStates) = buildNFA(subExpr, groupStartState + 1);

              for ((fromState, transition, toState) in subTransitionTable.vals()) {
                transitionBuffer.add((fromState, transition, toState));
              };

              for (acceptState in subAcceptStates.vals()) {
                transitionBuffer.add((acceptState, #Epsilon, groupEndState));
              };

              (Buffer.toArray(transitionBuffer), [groupEndState]);
            };

            case (?#PositiveLookahead) {
              let (subTransitionTable, _) = buildNFA(subExpr, groupStartState);

              for ((fromState, transition, toState) in subTransitionTable.vals()) {
                transitionBuffer.add((fromState, transition, toState));
              };

              (Buffer.toArray(transitionBuffer), [groupStartState]);
            };

            case (?#NegativeLookahead) {
              let (subTransitionTable, _) = buildNFA(subExpr, groupStartState);

              for ((fromState, transition, toState) in subTransitionTable.vals()) {
                transitionBuffer.add((fromState, transition, toState));
              };

              (Buffer.toArray(transitionBuffer), [groupStartState]); // Group ends without advancing
            };

            case (?#PositiveLookbehind) {
              let (subTransitionTable, _) = buildNFA(subExpr, groupStartState);

              for ((fromState, transition, toState) in subTransitionTable.vals()) {
                transitionBuffer.add((fromState, transition, toState));
              };

              (Buffer.toArray(transitionBuffer), [groupStartState]);
            };

            case (?#NegativeLookbehind) {
              let (subTransitionTable, _) = buildNFA(subExpr, groupStartState);

              for ((fromState, transition, toState) in subTransitionTable.vals()) {
                transitionBuffer.add((fromState, transition, toState));
              };

              (Buffer.toArray(transitionBuffer), [groupStartState]);
            };
          };
        };

        case (#Metacharacter metacharType) {
          let transitionBuffer = Buffer.Buffer<(State, Transition, State)>(1);
          let acceptState: State = startState + 1;
          switch (metacharType) {
            case (#Dot) {
              transitionBuffer.add((startState, #Any, acceptState));
            };
            case (_) {
              let metaRanges = Extensions.metacharToRanges(metacharType);
              for (range in metaRanges.vals()) {
                transitionBuffer.add((startState, #Range(range.0, range.1), acceptState));
              };
            };
          };
          (Buffer.toArray(transitionBuffer), [acceptState]);
        };

        case (#CharacterClass { isNegated; classes }) {
          let transitionBuffer = Buffer.Buffer<(State, Transition, State)>(classes.size());
          let acceptState: State = startState + 1;
          let ranges = Buffer.Buffer<(Char, Char)>(classes.size());

          for (charClass in classes.vals()) {
            switch (charClass) {
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
                ignore buildNFA(#Quantifier {
                  subExpr = #CharacterClass({isNegated = isNegated; classes = [charClass]});
                  min = quantType.min;
                  max = quantType.max;
                  mode = quantType.mode;
                }, startState);
              };

            };
          };

          if (isNegated) {
            var lastChar: Char = Char.fromNat32(0);
            let sortedRanges = Buffer.toArray(ranges);
            ignore Array.sort<(Char, Char)>(sortedRanges, func(a: (Char, Char), b: (Char, Char)) : Order.Order {
              Char.compare(a.0, b.0)
            });
            for (range in sortedRanges.vals()) {
              if (Char.toNat32(lastChar) < Char.toNat32(range.0)) {
                transitionBuffer.add((startState, #Range(lastChar, Char.fromNat32(Char.toNat32(range.0) - 1)), acceptState));
              };
              lastChar := Char.fromNat32(Char.toNat32(range.1) + 1);
            };
            if (Char.toNat32(lastChar) <= 255) {
              transitionBuffer.add((startState, #Range(lastChar, Char.fromNat32(255)), acceptState));
            };
          } else {
            for (range in ranges.vals()) {
              transitionBuffer.add((startState, #Range(range.0, range.1), acceptState));
            };
          };

          (Buffer.toArray(transitionBuffer), [acceptState]);
        };

        case (#Anchor anchorType) {
          let transitionBuffer = Buffer.Buffer<(State, Transition, State)>(1);
          let acceptState: State = startState + 1;
          switch (anchorType) {
            case (#StartOfString) {
              transitionBuffer.add((startState, #Epsilon, acceptState));
            };
            case (#EndOfString) {
              transitionBuffer.add((startState, #Epsilon, acceptState));
            };
            case (#WordBoundary) {
              transitionBuffer.add((startState, #Epsilon, acceptState));
            };
            case (#NonWordBoundary) {
              transitionBuffer.add((startState, #Epsilon, acceptState));
            };
            case (#StartOfStringOnly) {
              transitionBuffer.add((startState, #Epsilon, acceptState));
            };
            case (#EndOfStringOnly) {
              transitionBuffer.add((startState, #Epsilon, acceptState));
            };
            case (#PreviousMatchEnd) {
              transitionBuffer.add((startState, #Epsilon, acceptState));
            };
          };
          (Buffer.toArray(transitionBuffer), [acceptState]);
        };
      }
    };
  };*/
};