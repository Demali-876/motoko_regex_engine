import Types "Types";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import TrieMap "mo:base/TrieMap";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Extensions "Extensions";
import Result "mo:base/Result";

module {
  type State = Types.State;
  type Symbol = Types.Symbol;
  type Transition = Types.Transition;

  public class Compiler() {
    let assertionBuffer = Buffer.Buffer<Types.Assertion>(8);
    let namedGroupsMetadata = TrieMap.TrieMap<Text, Types.GroupsMetadata>(Text.equal, Text.hash);
    public func compile(ast : Types.ASTNode) : Result.Result<Types.CompiledRegex, Types.RegexError> {
      let startState : State = 0;
      switch (buildNFA(ast, startState)) {
        case (#err(error)) {
          #err(error);
        };
        case (#ok(flatTransitions, acceptStates)) {
          if (acceptStates.size() == 0) {
            #err(#EmptyExpression("No accept states generated"));
          } else {
            let maxState = Extensions.getMaxState(flatTransitions, acceptStates, startState);

            let transitionsByState = Array.tabulate<[Transition]>(
              maxState + 1,
              func(state) {
                let stateTransitions = Buffer.Buffer<Transition>(4);
                for (t in flatTransitions.vals()) {
                  if (t.0 == state) {
                    stateTransitions.add(t);
                  };
                };
                stateTransitions.sort(Extensions.compareTransitions);
                Buffer.toArray(stateTransitions);
              },
            );

            #ok({
              states = Array.tabulate<State>(maxState + 1, func(i) = i);
              transitionTable = transitionsByState;
              startState = startState;
              acceptStates = acceptStates;
              assertions = Buffer.toArray(assertionBuffer);
            });
          };
        };
      };
    };

    public func buildNFA(ast : Types.ASTNode, startState : State) : Result.Result<([Transition], [State]), Types.RegexError> {
      switch (ast) {

        case (#Character(char)) {
          let acceptState : State = startState + 1;
          let symbol : Symbol = #Char(char);
          let transitions : [Transition] = [(startState, symbol, acceptState, null)];
          #ok(transitions, [acceptState]);
        };

        case (#Range(from, to)) {
          let acceptState = startState + 1;
          let symbol : Symbol = #Range(from, to);
          let transitions : [Transition] = [(startState, symbol, acceptState, null)];
          #ok(transitions, [acceptState]);
        };

        case (#Metacharacter(metacharType)) {
          let acceptState : State = startState + 1;
          let transitionBuffer = Buffer.Buffer<Transition>(4);
          let ranges = Extensions.metacharToRanges(metacharType);

          for ((from, to) in ranges.vals()) {
            transitionBuffer.add((startState, #Range(from, to), acceptState, null));
          };

          #ok(Buffer.toArray(transitionBuffer), [acceptState]);
        };

        case (#CharacterClass({ isNegated; classes })) {
          let acceptState : State = startState + 1;
          let transitionBuffer = Buffer.Buffer<Transition>(4);
          let ranges = Extensions.computeClassRanges(classes, isNegated);
          for ((from, to) in ranges.vals()) {
            transitionBuffer.add((startState, #Range(from, to), acceptState, null));
          };
          #ok(Buffer.toArray(transitionBuffer), [acceptState]);
        };

        case (#Quantifier({ subExpr; quantifier = { min; max; mode } })) {
          switch (min, max) {
            case (0, null) {
              switch (buildNFA(subExpr, startState)) {
                case (#err(e)) #err(e);
                case (#ok(subTransitions, _)) {
                  let transitionBuffer = Buffer.Buffer<Transition>(subTransitions.size());

                  for (t in subTransitions.vals()) {
                    transitionBuffer.add((startState, t.1, startState, ?mode));
                  };
                  #ok(Buffer.toArray(transitionBuffer), [startState, startState + 1]);
                };
              };
            };

            case (1, null) {
              switch (buildNFA(subExpr, startState)) {
                case (#err(e)) #err(e);
                case (#ok(subTransitions, _)) {
                  let transitionBuffer = Buffer.Buffer<Transition>(subTransitions.size() * 2);

                  for (t in subTransitions.vals()) {
                    transitionBuffer.add((startState, t.1, startState + 1, ?mode));
                  };
                  for (t in subTransitions.vals()) {
                    transitionBuffer.add((startState + 1, t.1, startState + 1, ?mode));
                  };
                  #ok(Buffer.toArray(transitionBuffer), [startState + 1]);
                };
              };
            };

            case (0, ?1) {
              switch (buildNFA(subExpr, startState)) {
                case (#err(e)) #err(e);
                case (#ok(subTransitions, _)) {
                  let transitionBuffer = Buffer.Buffer<Transition>(subTransitions.size());

                  for (t in subTransitions.vals()) {
                    transitionBuffer.add((startState, t.1, startState + 1, ?mode));
                  };
                  #ok(Buffer.toArray(transitionBuffer), [startState, startState + 1]);
                };
              };
            };

            case (n, ?m) {
              if (n == m) {
                var currentState = startState;
                let transitionBuffer = Buffer.Buffer<Transition>(n * 2);

                for (_ in Iter.range(0, n - 1)) {
                  switch (buildNFA(subExpr, currentState)) {
                    case (#err(e)) return #err(e);
                    case (#ok(subTransitions, _)) {
                      for (t in subTransitions.vals()) {
                        transitionBuffer.add((currentState, t.1, currentState + 1, ?mode));
                      };
                      currentState += 1;
                    };
                  };
                };

                #ok(Buffer.toArray(transitionBuffer), [currentState]);
              } else if (n < m) {
                var currentState = startState;
                let transitionBuffer = Buffer.Buffer<Transition>(m * 2);
                let acceptStates = Buffer.Buffer<State>(m - n + 1);

                for (_ in Iter.range(0, n - 1)) {
                  switch (buildNFA(subExpr, currentState)) {
                    case (#err(e)) return #err(e);
                    case (#ok(subTransitions, _)) {
                      for (t in subTransitions.vals()) {
                        transitionBuffer.add((currentState, t.1, currentState + 1, ?mode));
                      };
                      currentState += 1;
                    };
                  };
                };

                acceptStates.add(currentState);
                for (_ in Iter.range(n, m - 1)) {
                  switch (buildNFA(subExpr, currentState)) {
                    case (#err(e)) return #err(e);
                    case (#ok(subTransitions, _)) {
                      for (t in subTransitions.vals()) {
                        transitionBuffer.add((currentState, t.1, currentState + 1, ?mode));
                      };
                      currentState += 1;
                      acceptStates.add(currentState);
                    };
                  };
                };

                #ok(Buffer.toArray(transitionBuffer), Buffer.toArray(acceptStates));
              } else {
                #err(#InvalidQuantifier("Minimum count cannot be greater than maximum"));
              };
            };

            case (n, null) {
              var currentState = startState;
              let transitionBuffer = Buffer.Buffer<Transition>(n * 2);

              for (_ in Iter.range(0, n - 1)) {
                switch (buildNFA(subExpr, currentState)) {
                  case (#err(e)) return #err(e);
                  case (#ok(subTransitions, _)) {
                    for (t in subTransitions.vals()) {
                      transitionBuffer.add((currentState, t.1, currentState + 1, ?mode));
                    };
                    currentState += 1;
                  };
                };
              };

              switch (buildNFA(subExpr, currentState)) {
                case (#err(e)) #err(e);
                case (#ok(subTransitions, _)) {
                  for (t in subTransitions.vals()) {
                    transitionBuffer.add((currentState, t.1, currentState, ?mode));
                  };
                  #ok(Buffer.toArray(transitionBuffer), [currentState]);
                };
              };
            };
          };
        };

        case (#Anchor(anchor)) {
          assertionBuffer.add({
            assertion = #Anchor({
              aType = anchor;
              position = startState;
            });
          });
          #ok([] : [Transition], [startState]);
        };
        case (#Alternation(alternatives)) {
          switch (alternatives.size()) {
            case 0 return #err(#GenericError("Empty alternation"));
            case 1 return buildNFA(alternatives[0], startState);
            case _ {
              let transitions = Buffer.Buffer<Transition>(16);
              let acceptStates = Buffer.Buffer<State>(alternatives.size());
              var currentState = startState;

              let flattenedAlts = Buffer.Buffer<[Types.ASTNode]>(alternatives.size());
              var maxLength = 0;
              for (alt in alternatives.vals()) {
                let flattened = Extensions.flattenAST(alt);
                flattenedAlts.add(flattened);
                maxLength := Nat.max(maxLength, flattened.size());
              };

              for (level in Iter.range(0, maxLength - 1)) {
                let levelTransitions = Buffer.Buffer<(Transition)>(4);
                let levelStates = Buffer.Buffer<State>(4);

                for (altNodes in flattenedAlts.vals()) {
                  if (level < altNodes.size()) {
                    switch (buildNFA(altNodes[level], currentState)) {
                      case (#err(e)) return #err(e);
                      case (#ok(nodeTransitions, _)) {
                        for (t in nodeTransitions.vals()) {
                          levelTransitions.add(t);
                          levelStates.add(t.2);
                        };
                      };
                    };
                  } else {
                    acceptStates.add(currentState);
                  };
                };
                for (t in levelTransitions.vals()) {
                  transitions.add(t);
                };

                currentState += 1;
              };
              acceptStates.add(currentState);
              Buffer.removeDuplicates<Transition>(transitions, Extensions.transitionEquals);
              #ok(Buffer.toArray(transitions), Buffer.toArray(acceptStates));
            };
          };
        };

        case (#Concatenation(exprs)) {
          switch (exprs.size()) {
            case 0 return #err(#GenericError("Empty concatenation"));
            case 1 return buildNFA(exprs[0], startState);
            case _ {
              var currentState = startState;
              let transitionBuffer = Buffer.Buffer<Transition>(exprs.size() * 4);
              let acceptStates = Buffer.Buffer<State>(4);

              switch (buildNFA(exprs[0], currentState)) {
                case (#err(e)) return #err(e);
                case (#ok(transitions, accepts)) {
                  for (t in transitions.vals()) {
                    transitionBuffer.add(t);
                  };
                  for (accept in accepts.vals()) {
                    acceptStates.add(accept);
                  };
                  currentState := accepts[0];
                };
              };

              for (i in Iter.range(1, exprs.size() - 1)) {
                let thisAccepts = Buffer.Buffer<State>(4);
                for (prevAccept in acceptStates.vals()) {
                  switch (buildNFA(exprs[i], prevAccept)) {
                    case (#err(e)) return #err(e);
                    case (#ok(transitions, accepts)) {
                      for (t in transitions.vals()) {
                        transitionBuffer.add(t);
                      };
                      for (accept in accepts.vals()) {
                        thisAccepts.add(accept);
                      };
                    };
                  };
                };

                acceptStates.clear();
                for (accept in thisAccepts.vals()) {
                  acceptStates.add(accept);
                };
              };
              Buffer.removeDuplicates<Nat>(acceptStates, Nat.compare);
              Buffer.removeDuplicates<Transition>(transitionBuffer, Extensions.transitionEquals);
              #ok(Buffer.toArray(transitionBuffer), Buffer.toArray<Nat>(acceptStates));
            };
          };
        };
        case (#Group({ name; subExpr; modifier; captureIndex })) {
          let groupStartState = startState;

          switch (modifier) {
            case (?#PositiveLookahead or ?#NegativeLookahead) {
              switch (buildNFA(subExpr, groupStartState)) {
                case (#err(e)) return #err(e);
                case (#ok(transitions, subAcceptStates)) {
                  let maxState = Array.foldLeft<Transition, Nat>(
                    transitions,
                    0,
                    func(max, t) { Nat.max(max, Nat.max(t.0, t.2)) },
                  );
                  let states = Array.tabulate<State>(
                    maxState + 1,
                    func(i) { i },
                  );
                  let transitionTable = Array.tabulate<[Transition]>(
                    maxState + 1,
                    func(state) {
                      let stateTransitions = Buffer.Buffer<Transition>(4);
                      for (t in transitions.vals()) {
                        if (t.0 == state) {
                          stateTransitions.add(t);
                        };
                      };
                      stateTransitions.sort(Extensions.compareTransitions);
                      Buffer.toArray(stateTransitions);
                    },
                  );
                  assertionBuffer.add({
                    assertion = #Lookaround({
                      states = states;
                      startState = groupStartState;
                      acceptStates = subAcceptStates;
                      transitionTable = transitionTable;
                      isPositive = modifier == ?#PositiveLookahead;
                      isAhead = true;
                      position = groupStartState;
                      length = null;
                    });
                  });

                  #ok([], [groupStartState]);
                };
              };
            };

            case (?#PositiveLookbehind or ?#NegativeLookbehind) {
              switch (Extensions.computeExpressionLength(subExpr)) {
                case (#err(e)) return #err(e);
                case (#ok(length)) {
                  switch (buildNFA(subExpr, groupStartState)) {
                    case (#err(e)) return #err(e);
                    case (#ok(transitions, subAcceptStates)) {
                      let maxState = Array.foldLeft<Transition, Nat>(
                        transitions,
                        0,
                        func(max, t) { Nat.max(max, Nat.max(t.0, t.2)) },
                      );
                      let states = Array.tabulate<State>(
                        maxState + 1,
                        func(i) { i },
                      );
                      let transitionTable = Array.tabulate<[Transition]>(
                        maxState + 1,
                        func(state) {
                          let stateTransitions = Buffer.Buffer<Transition>(4);
                          for (t in transitions.vals()) {
                            if (t.0 == state) {
                              stateTransitions.add(t);
                            };
                          };
                          stateTransitions.sort(Extensions.compareTransitions);
                          Buffer.toArray(stateTransitions);
                        },
                      );
                      assertionBuffer.add({
                        assertion = #Lookaround({
                          states = states;
                          startState = groupStartState;
                          acceptStates = subAcceptStates;
                          transitionTable = transitionTable;
                          isPositive = modifier == ?#PositiveLookbehind;
                          isAhead = false;
                          position = groupStartState;
                          length = ?length;
                        });
                      });

                      #ok([], [groupStartState]);
                    };
                  };
                };
              };
            };
            case (?#NonCapturing) {
              buildNFA(subExpr, groupStartState);
            };

            case (null) {
              let index = switch (captureIndex) {
                case (?i) i;
                case null return #err(#GenericError("Capture index is null for capturing group"));
              };

              switch (buildNFA(subExpr, groupStartState)) {
                case (#err(e)) return #err(e);
                case (#ok(subTransitions, subAcceptStates)) {
                  switch (Extensions.computeExpressionLength(subExpr)) {
                    case (#ok(length)) {
                      switch (name) {
                        case (?groupName) {
                          if (namedGroupsMetadata.get(groupName) != null) {
                            return #err(#GenericError("Duplicate named group '" # groupName # "'"));
                          };
                          namedGroupsMetadata.put(
                            groupName,
                            {
                              captureIndex = index;
                              length = length;
                              endStates = subAcceptStates;
                              name = groupName;
                              startState = groupStartState;
                            },
                          );
                        };
                        case (null) {};
                      };
                    };
                    case (#err(e)) return #err(e);
                  };
                  assertionBuffer.add({
                    assertion = #Group({
                      captureIndex = index;
                      startState = groupStartState;
                      endStates = subAcceptStates;
                    });
                  });

                  #ok(subTransitions, subAcceptStates);
                };
              };
            };
          };
        };
        case (#Backreference(name)) {
          switch (namedGroupsMetadata.get(name)) {
            case (?metadata) {
              assertionBuffer.add({
                assertion = #Backreference({
                  captureIndex = metadata.captureIndex;
                  position = startState;
                  length = metadata.length;
                });
              });

              #ok([], [startState]);
            };
            case null {
              #err(#GenericError("Backreference '" # name # "' does not match any previously defined group"));
            };
          };
        };
      };
    };
  };
};
