import Types "Types";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Extensions "Extensions";
import Optimizer "Optimizer";
import Result "mo:base/Result";

module {
  public type CompilerError = Types.RegexError;
  type State = Types.State;
  type NFA = Types.CompiledRegex;
  type Symbol = Types.Symbol;
  type Transition = Types.Transition;

  public class Compiler() {
    public func compile(ast: Types.ASTNode): Result.Result<NFA, CompilerError> {
      let startState: State = 0;
      switch(buildNFA(ast, startState)) {
        case (#err(error)) {
          #err(error)
        };
        case (#ok(transitionTable, acceptStates)) {
          if (acceptStates.size() == 0) {
            #err(#EmptyExpression("No accept states generated"))
          } else {
            let maxState = Extensions.getMaxState(transitionTable, acceptStates, startState);
            // Create array of transition arrays, indexed by state
            let transitionsByState = Array.tabulate<[Transition]>(maxState + 1, func(state) {
              let stateTransitions = Buffer.Buffer<Transition>(4);
              for (t in transitionTable.vals()) {
                if (t.0 == state) {
                  stateTransitions.add(t);
                };
              };
              Buffer.toArray(stateTransitions)
            });
            #ok({
              states = Array.tabulate<State>(maxState + 1, func(i) = i);
              transitions = transitionTable;
              transitionsByState = transitionsByState;
              startState = startState;
              acceptStates = acceptStates;
            })
          }
        };
      }
    };

    public func buildNFA(ast: Types.ASTNode, startState: State): Result.Result<([Transition], [State]), CompilerError> {
      switch (ast) {

        case (#Character(char)) {
          let acceptState: State = startState + 1;
          let symbol: Symbol = #Char(char);
          let transitions: [Transition] = [(startState, symbol, acceptState)];
          #ok(transitions, [acceptState])
        };

        case (#Range(from, to)) {
          let acceptState = startState + 1;
          let symbol: Symbol = #Range(from, to);
          let transitions: [Transition] = [(startState, symbol, acceptState)];
          #ok(transitions, [acceptState])
        };

        case (#Metacharacter(metacharType)) {
          let acceptState: State = startState + 1;
          let transitionBuffer = Buffer.Buffer<Transition>(4);
          let ranges = Extensions.metacharToRanges(metacharType);
          
          for ((from, to) in ranges.vals()) {
            transitionBuffer.add((startState, #Range(from, to), acceptState));
          };
          
          #ok(Buffer.toArray(transitionBuffer), [acceptState])
        };

        case (#CharacterClass({ isNegated; classes })) {
          let acceptState: State = startState + 1;
          let transitionBuffer = Buffer.Buffer<Transition>(4);
          let ranges = Extensions.computeClassRanges(classes, isNegated);
          for ((from, to) in ranges.vals()) {
            transitionBuffer.add((startState, #Range(from, to), acceptState));
          };
          #ok(Buffer.toArray(transitionBuffer), [acceptState])
        };
        case (#Quantifier({ subExpr; quantifier = { min; max; mode=_; } })) {
        switch (min, max) {
          case (0, null) { // * (zero or more)
            switch(buildNFA(subExpr, startState)) {
              case (#err(e)) #err(e);
              case (#ok(subTransitions, _)) {
                let transitionBuffer = Buffer.Buffer<Transition>(subTransitions.size());
                
                // Add transitions that loop back to start state
                for (t in subTransitions.vals()) {
                  transitionBuffer.add((startState, t.1, startState));
                };
                
                // Start state is accepting since we can match zero occurrences
                #ok(Buffer.toArray(transitionBuffer), [startState])
              };
            }
          };

          case (1, null) { // + (one or more)
            switch(buildNFA(subExpr, startState)) {
              case (#err(e)) #err(e);
              case (#ok(subTransitions, _)) {
                let transitionBuffer = Buffer.Buffer<Transition>(subTransitions.size() * 2);
                
                // Add initial transitions to state 1
                for (t in subTransitions.vals()) {
                  transitionBuffer.add((startState, t.1, startState + 1));
                };
                
                // Add looping transitions at state 1
                for (t in subTransitions.vals()) {
                  transitionBuffer.add((startState + 1, t.1, startState + 1));
                };
                
                #ok(Buffer.toArray(transitionBuffer), [startState + 1])
              };
            }
          };

          case (0, ?1) { // ? (zero or one)
            switch(buildNFA(subExpr, startState)) {
              case (#err(e)) #err(e);
              case (#ok(subTransitions, _)) {
                let transitionBuffer = Buffer.Buffer<Transition>(subTransitions.size());
                
                // Add transitions to accepting state
                for (t in subTransitions.vals()) {
                  transitionBuffer.add((startState, t.1, startState + 1));
                };
                
                // Both states are accepting since we can match zero or one
                #ok(Buffer.toArray(transitionBuffer), [startState, startState + 1])
              };
            }
          };

          case (n, ?m) { // Fixed count {n} or range {n,m}
            if (n == m) { // Fixed count {n}
              var currentState = startState;
              let transitionBuffer = Buffer.Buffer<Transition>(n * 2);
              
              // Build n copies of the subexpression
              for (i in Iter.range(0, n-1)) {
                switch(buildNFA(subExpr, currentState)) {
                  case (#err(e)) return #err(e);
                  case (#ok(subTransitions, _)) {
                    for (t in subTransitions.vals()) {
                      transitionBuffer.add((currentState, t.1, currentState + 1));
                    };
                    currentState += 1;
                  };
                };
              };
              
              #ok(Buffer.toArray(transitionBuffer), [currentState])
            } else if (n < m) { // Range {n,m}
              var currentState = startState;
              let transitionBuffer = Buffer.Buffer<Transition>(m * 2);
              let acceptStates = Buffer.Buffer<State>(m - n + 1);
              
              // Build states up to n
              for (i in Iter.range(0, n-1)) {
                switch(buildNFA(subExpr, currentState)) {
                  case (#err(e)) return #err(e);
                  case (#ok(subTransitions, _)) {
                    for (t in subTransitions.vals()) {
                      transitionBuffer.add((currentState, t.1, currentState + 1));
                    };
                    currentState += 1;
                  };
                };
              };
              
              // Add states from n to m, all accepting
              acceptStates.add(currentState);
              for (i in Iter.range(n, m-1)) {
                switch(buildNFA(subExpr, currentState)) {
                  case (#err(e)) return #err(e);
                  case (#ok(subTransitions, _)) {
                    for (t in subTransitions.vals()) {
                      transitionBuffer.add((currentState, t.1, currentState + 1));
                    };
                    currentState += 1;
                    acceptStates.add(currentState);
                  };
                };
              };
              
              #ok(Buffer.toArray(transitionBuffer), Buffer.toArray(acceptStates))
            } else {
              #err(#InvalidQuantifier("Minimum count cannot be greater than maximum"))
            }
          };

          case (n, null) { // {n,} - n or more
            var currentState = startState;
            let transitionBuffer = Buffer.Buffer<Transition>(n * 2);
            
            // Build first n states
            for (i in Iter.range(0, n-1)) {
              switch(buildNFA(subExpr, currentState)) {
                case (#err(e)) return #err(e);
                case (#ok(subTransitions, _)) {
                  for (t in subTransitions.vals()) {
                    transitionBuffer.add((currentState, t.1, currentState + 1));
                  };
                  currentState += 1;
                };
              };
            };
            
            // Add final state that loops back on itself
            switch(buildNFA(subExpr, currentState)) {
              case (#err(e)) #err(e);
              case (#ok(subTransitions, _)) {
                for (t in subTransitions.vals()) {
                  transitionBuffer.add((currentState, t.1, currentState));
                };
                #ok(Buffer.toArray(transitionBuffer), [currentState])
              };
            }
          };
        }
      };
        case (#Anchor(_)) {
          // No need to create states or transitions
          // Just return empty transitions with current state as accept state
          // The matcher will handle the anchor checking
          #ok([] : [Transition], [startState])
        };
        case (#Alternation(alternatives)) {
        switch(alternatives.size()) {
          case 0 return #err(#GenericError("Empty alternation"));
          case 1 return buildNFA(alternatives[0], startState);
          case _ {
            let transitionBuffer = Buffer.Buffer<Transition>(16);
            var currentState = startState;
            var acceptStates = Buffer.Buffer<State>(alternatives.size());
            
            // Build NFA for each alternative
            for (alt in alternatives.vals()) {
              switch(buildNFA(alt, currentState)) {
                case (#err(e)) return #err(e);
                case (#ok(transitions, altAccepts)) {
                  // Add all transitions for this alternative
                  for (t in transitions.vals()) {
                    transitionBuffer.add(t);
                  };
                  
                  // Add accept states
                  for (accept in altAccepts.vals()) {
                    acceptStates.add(accept);
                  };
                  
                  // Update current state for next alternative
                  currentState += transitions.size() + 1;
                };
              };
            };
            
            #ok(Buffer.toArray(transitionBuffer), Buffer.toArray(acceptStates))
          };
        }
      };
        case (#Concatenation(exprs)) {
          switch(exprs.size()) {
            case 0 return #err(#GenericError("Empty concatenation"));
            case 1 return buildNFA(exprs[0], startState);
            case _ {
              var currentState = startState;
              let transitionBuffer = Buffer.Buffer<Transition>(exprs.size());
              
              // Build NFA for each expression in sequence
              for (i in Iter.range(0, exprs.size() - 1)) {
                switch(buildNFA(exprs[i], currentState)) {
                  case (#err(e)) return #err(e);
                  case (#ok(transitions, _)) {
                    // Add transitions for this expression
                    for (t in transitions.vals()) {
                      transitionBuffer.add(t);
                    };
                    currentState += 1;
                  };
                };
              };
              
              // Only the final state is accepting
              #ok(Buffer.toArray(transitionBuffer), [currentState])
            };
          }
        };
        case (#Group({ subExpr; modifier = _; captureIndex = _ })) {
          // Just process the subexpression - grouping is handled by matcher
          buildNFA(subExpr, startState)
        };
      }
    };
  };
};