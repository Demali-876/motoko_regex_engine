import Types "Types";
import Buffer "mo:base/Buffer";
import Order "mo:base/Order";
import Iter "mo:base/Iter";
import Char "mo:base/Char";
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
            #ok({
              states = Array.tabulate<State>(maxState + 1, func(i) = i);
              transitions = transitionTable;
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
          let transitionBuffer = Buffer.Buffer<Transition>(subTransitions.size() + 3);
          
          // Add subexpression transitions
          for (t in subTransitions.vals()) {
            transitionBuffer.add(t);
          };
          
          // Add epsilon from start state to accept state for zero case
          transitionBuffer.add((startState, #Epsilon, startState + 1));
          
          // Add epsilon from accept state back to start for repetition
          transitionBuffer.add((startState + 1, #Epsilon, startState));
          
          #ok(Buffer.toArray(transitionBuffer), [startState, startState + 1])
        };
      }
    };

    case (1, null) { // + (one or more)
      switch(buildNFA(subExpr, startState)) {
        case (#err(e)) #err(e);
        case (#ok(subTransitions, _)) {
          let transitionBuffer = Buffer.Buffer<Transition>(subTransitions.size() + 1);
          
          // Add the subexpression transitions
          for (t in subTransitions.vals()) {
            transitionBuffer.add(t);
          };
          
          // Add epsilon from accept state back to start for repetition
          transitionBuffer.add((startState + 1, #Epsilon, startState));
          
          #ok(Buffer.toArray(transitionBuffer), [startState + 1])
        };
      }
    };

    case (0, ?1) { // ? (zero or one)
      switch(buildNFA(subExpr, startState)) {
        case (#err(e)) #err(e);
        case (#ok(subTransitions, _)) {
          let transitionBuffer = Buffer.Buffer<Transition>(subTransitions.size() + 1);
          
          // Add subexpression transitions
          for (t in subTransitions.vals()) {
            transitionBuffer.add(t);
          };
          
          // Add epsilon from start to accept for zero case
          transitionBuffer.add((startState, #Epsilon, startState + 1));
          
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
                transitionBuffer.add(t);
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
        
        // Build required n states
        for (i in Iter.range(0, n-1)) {
          switch(buildNFA(subExpr, currentState)) {
            case (#err(e)) return #err(e);
            case (#ok(subTransitions, _)) {
              for (t in subTransitions.vals()) {
                transitionBuffer.add(t);
              };
              currentState += 1;
            };
          };
        };
        
        // Add accept state for n
        acceptStates.add(currentState);
        
        // Build optional states from n+1 to m
        for (i in Iter.range(n, m-1)) {
          switch(buildNFA(subExpr, currentState)) {
            case (#err(e)) return #err(e);
            case (#ok(subTransitions, _)) {
              for (t in subTransitions.vals()) {
                transitionBuffer.add(t);
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
      
      // Build required n states
      for (i in Iter.range(0, n-1)) {
        switch(buildNFA(subExpr, currentState)) {
          case (#err(e)) return #err(e);
          case (#ok(subTransitions, _)) {
            for (t in subTransitions.vals()) {
              transitionBuffer.add(t);
            };
            currentState += 1;
          };
        };
      };
      
      // Add plus behavior after n states
      switch(buildNFA(subExpr, currentState)) {
        case (#err(e)) #err(e);
        case (#ok(subTransitions, _)) {
          for (t in subTransitions.vals()) {
            transitionBuffer.add(t);
          };
          // Add epsilon transition for repetition
          transitionBuffer.add((currentState + 1, #Epsilon, currentState));
          #ok(Buffer.toArray(transitionBuffer), [currentState + 1])
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
        
        case (_) {
          #err(#UnsupportedASTNode("AST node is not recognizable/Unsupported"))
        };
      }
    };
  };
};