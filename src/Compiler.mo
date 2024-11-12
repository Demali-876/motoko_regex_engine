import Types "Types";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Extensions "Extensions";
import Result "mo:base/Result";

module {
  type State = Types.State;
  type Symbol = Types.Symbol;
  type Transition = Types.Transition;

  public class Compiler() {

    public func compile(ast : Types.ASTNode) : Result.Result<Types.CompiledRegex, Types.RegexError> {
      let startState : State = 0;
      switch (buildNFA(ast, startState)) {
        case (#err(error)) {
          #err(error)
        };
        case (#ok(transitionTable, acceptStates)) {
          if (acceptStates.size() == 0) {
            #err(#EmptyExpression("No accept states generated"))
          } else {
            let maxState = Extensions.getMaxState(transitionTable, acceptStates, startState);
            let transitionsByState = Array.tabulate<[Transition]>(
              maxState + 1,
              func(state) {
                let stateTransitions = Buffer.Buffer<Transition>(4);
                for (t in transitionTable.vals()) {
                  if (t.0 == state) {
                    stateTransitions.add(t)
                  }
                };
                Buffer.toArray(stateTransitions)
              }
            );
            #ok({
              states = Array.tabulate<State>(maxState + 1, func(i) = i);
              transitions = transitionTable;
              transitionsByState = transitionsByState;
              startState = startState;
              acceptStates = acceptStates
            })
          }
        }
      }
    };

    public func buildNFA(ast : Types.ASTNode, startState : State) : Result.Result<([Transition], [State]), Types.RegexError> {
      switch (ast) {

        case (#Character(char)) {
          let acceptState : State = startState + 1;
          let symbol : Symbol = #Char(char);
          let transitions : [Transition] = [(startState, symbol, acceptState)];
          #ok(transitions, [acceptState])
        };

        case (#Range(from, to)) {
          let acceptState = startState + 1;
          let symbol : Symbol = #Range(from, to);
          let transitions : [Transition] = [(startState, symbol, acceptState)];
          #ok(transitions, [acceptState])
        };

        case (#Metacharacter(metacharType)) {
          let acceptState : State = startState + 1;
          let transitionBuffer = Buffer.Buffer<Transition>(4);
          let ranges = Extensions.metacharToRanges(metacharType);

          for ((from, to) in ranges.vals()) {
            transitionBuffer.add((startState, #Range(from, to), acceptState))
          };

          #ok(Buffer.toArray(transitionBuffer), [acceptState])
        };

        case (#CharacterClass({isNegated; classes})) {
          let acceptState : State = startState + 1;
          let transitionBuffer = Buffer.Buffer<Transition>(4);
          let ranges = Extensions.computeClassRanges(classes, isNegated);
          for ((from, to) in ranges.vals()) {
            transitionBuffer.add((startState, #Range(from, to), acceptState))
          };
          #ok(Buffer.toArray(transitionBuffer), [acceptState])
        };

        case (#Quantifier({subExpr; quantifier = {min; max; mode = _}})) {
          switch (min, max) {
            case (0, null) {
              switch (buildNFA(subExpr, startState)) {
                case (#err(e)) #err(e);
                case (#ok(subTransitions, _)) {
                  let transitionBuffer = Buffer.Buffer<Transition>(subTransitions.size());

                  for (t in subTransitions.vals()) {
                    transitionBuffer.add((startState, t.1, startState))
                  };
                  #ok(Buffer.toArray(transitionBuffer), [startState])
                }
              }
            };

            case (1, null) {
              switch (buildNFA(subExpr, startState)) {
                case (#err(e)) #err(e);
                case (#ok(subTransitions, _)) {
                  let transitionBuffer = Buffer.Buffer<Transition>(subTransitions.size() * 2);

                  for (t in subTransitions.vals()) {
                    transitionBuffer.add((startState, t.1, startState + 1))
                  };
                  for (t in subTransitions.vals()) {
                    transitionBuffer.add((startState + 1, t.1, startState + 1))
                  };
                  #ok(Buffer.toArray(transitionBuffer), [startState + 1])
                }
              }
            };

            case (0, ?1) {
              switch (buildNFA(subExpr, startState)) {
                case (#err(e)) #err(e);
                case (#ok(subTransitions, _)) {
                  let transitionBuffer = Buffer.Buffer<Transition>(subTransitions.size());

                  for (t in subTransitions.vals()) {
                    transitionBuffer.add((startState, t.1, startState + 1))
                  };
                  #ok(Buffer.toArray(transitionBuffer), [startState, startState + 1])
                }
              }
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
                        transitionBuffer.add((currentState, t.1, currentState + 1))
                      };
                      currentState += 1
                    }
                  }
                };

                #ok(Buffer.toArray(transitionBuffer), [currentState])
              } else if (n < m) {
                var currentState = startState;
                let transitionBuffer = Buffer.Buffer<Transition>(m * 2);
                let acceptStates = Buffer.Buffer<State>(m - n + 1);

                for (_ in Iter.range(0, n - 1)) {
                  switch (buildNFA(subExpr, currentState)) {
                    case (#err(e)) return #err(e);
                    case (#ok(subTransitions, _)) {
                      for (t in subTransitions.vals()) {
                        transitionBuffer.add((currentState, t.1, currentState + 1))
                      };
                      currentState += 1
                    }
                  }
                };

                acceptStates.add(currentState);
                for (_ in Iter.range(n, m - 1)) {
                  switch (buildNFA(subExpr, currentState)) {
                    case (#err(e)) return #err(e);
                    case (#ok(subTransitions, _)) {
                      for (t in subTransitions.vals()) {
                        transitionBuffer.add((currentState, t.1, currentState + 1))
                      };
                      currentState += 1;
                      acceptStates.add(currentState)
                    }
                  }
                };

                #ok(Buffer.toArray(transitionBuffer), Buffer.toArray(acceptStates))
              } else {
                #err(#InvalidQuantifier("Minimum count cannot be greater than maximum"))
              }
            };

            case (n, null) {
              var currentState = startState;
              let transitionBuffer = Buffer.Buffer<Transition>(n * 2);

              for (_ in Iter.range(0, n - 1)) {
                switch (buildNFA(subExpr, currentState)) {
                  case (#err(e)) return #err(e);
                  case (#ok(subTransitions, _)) {
                    for (t in subTransitions.vals()) {
                      transitionBuffer.add((currentState, t.1, currentState + 1))
                    };
                    currentState += 1
                  }
                }
              };

              switch (buildNFA(subExpr, currentState)) {
                case (#err(e)) #err(e);
                case (#ok(subTransitions, _)) {
                  for (t in subTransitions.vals()) {
                    transitionBuffer.add((currentState, t.1, currentState))
                  };
                  #ok(Buffer.toArray(transitionBuffer), [currentState])
                }
              }
            }
          }
        };

        case (#Anchor(_)) {
          // No need to create states or transitions
          // The matcher will handle the anchor checking
          #ok([] : [Transition], [startState])
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
                maxLength := Nat.max(maxLength, flattened.size())
              };

              for (level in Iter.range(0, maxLength - 1)) {
                let levelTransitions = Buffer.Buffer<(State, Symbol, State)>(4);
                let levelStates = Buffer.Buffer<State>(4);

                for (altNodes in flattenedAlts.vals()) {
                  if (level < altNodes.size()) {
                    switch (buildNFA(altNodes[level], currentState)) {
                      case (#err(e)) return #err(e);
                      case (#ok(nodeTransitions, _)) {
                        for (t in nodeTransitions.vals()) {
                          levelTransitions.add(t);
                          levelStates.add(t.2)
                        }
                      }
                    }
                  } else {
                    acceptStates.add(currentState)
                  }
                };
                for (t in levelTransitions.vals()) {
                  transitions.add(t)
                };

                currentState += 1
              };
              acceptStates.add(currentState);

              #ok(Buffer.toArray(transitions), Buffer.toArray(acceptStates))
            }
          }
        };

        case (#Concatenation(exprs)) {
          switch (exprs.size()) {
            case 0 return #err(#GenericError("Empty concatenation"));
            case 1 return buildNFA(exprs[0], startState);
            case _ {
              var currentState = startState;
              let transitionBuffer = Buffer.Buffer<Transition>(exprs.size() * 4);

              for (i in Iter.range(0, exprs.size() - 2)) {
                switch (buildNFA(exprs[i], currentState)) {
                  case (#err(e)) return #err(e);
                  case (#ok(transitions, accepts)) {
                    // Add transitions
                    for (t in transitions.vals()) {
                      transitionBuffer.add(t)
                    };
                    currentState := accepts[accepts.size() - 1]
                  }
                }
              };
              let lastIndex = exprs.size() - 1;
              switch (buildNFA(exprs[lastIndex], currentState)) {
                case (#err(e)) return #err(e);
                case (#ok(transitions, accepts)) {
                  for (t in transitions.vals()) {
                    transitionBuffer.add(t)
                  };
                  #ok(Buffer.toArray(transitionBuffer), accepts)
                }
              }
            }
          }
        };
        case (#Group({subExpr; modifier = _; captureIndex = _})) {
          // Just process the subexpression - grouping is handled by matcher
          buildNFA(subExpr, startState)
        }
      }
    }
  }
}