import Types "Types";
import Buffer "mo:base/Buffer";
import HashMap "mo:base/HashMap";
import Hash "mo:base/Hash";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";

/* module {
  public class Optimizer() {
    private var epsilonClosureCache = HashMap.HashMap<Types.State, Buffer.Buffer<Types.State>>(10, Nat.equal, Hash.hash);

    public func optimize(compiledNFA: Types.CompiledRegex): Types.CompiledRegex {
      let groupedTransitions = groupTransitionsByState(compiledNFA);
      let transitionsWithoutEpsilon = eliminateEpsilonTransitions(groupedTransitions);
      rebuildCompiledRegex(transitionsWithoutEpsilon, compiledNFA.startState, compiledNFA.acceptStates, compiledNFA.captureGroups);
    };

    private func eliminateEpsilonTransitions(
      stateTransitionsMap: HashMap.HashMap<Types.State, Buffer.Buffer<(Types.Transition, Types.State)>>
    ): HashMap.HashMap<Types.State, Buffer.Buffer<(Types.Transition, Types.State)>> {
      
      let newStateTransitionsMap = HashMap.HashMap<Types.State, Buffer.Buffer<(Types.Transition, Types.State)>>(
        stateTransitionsMap.size(),
       Nat.equal,
       Hash.hash
      );

      for ((state, transitions) in stateTransitionsMap.entries()) {
        let nonEpsilonTransitions = Buffer.Buffer<(Types.Transition, Types.State)>(transitions.size());
        let epsilonClosure = calculateEpsilonClosure(state, stateTransitionsMap);

        for (reachableState in epsilonClosure.vals()) {
          switch (stateTransitionsMap.get(reachableState)) {
            case (?reachableTransitions) {
              for ((transition, targetState) in reachableTransitions.vals()) {
                if (transition != #Epsilon) {
                  nonEpsilonTransitions.add((transition, targetState));
                };
              };
            };
            case null { /* This shouldn't happen if the NFA is well-formed */ };
          };
        };

        newStateTransitionsMap.put(state, nonEpsilonTransitions);
      };

      newStateTransitionsMap
    };

    private func calculateEpsilonClosure(
      state: Types.State,
      stateTransitionsMap: HashMap.HashMap<Types.State, Buffer.Buffer<(Types.Transition, Types.State)>>
    ): Buffer.Buffer<Types.State> {

      switch (epsilonClosureCache.get(state)) {
        case (?cachedClosure) { return cachedClosure; };
        case null {
          let closureBuffer = Buffer.Buffer<Types.State>(4);
          closureBuffer.add(state);
          var hasChanged = true;

          while (hasChanged) {
            hasChanged := false;
            let currentClosureSize = closureBuffer.size();
            
            for (i in Iter.range(0, currentClosureSize - 1)) {
              let currentState = closureBuffer.get(i);
              switch (stateTransitionsMap.get(currentState)) {
                case (?transitions) {
                  for ((transition, targetState) in transitions.vals()) {
                    if (transition == #Epsilon and not Buffer.contains<Types.State>(closureBuffer, targetState, Nat.equal)) {
                      closureBuffer.add(targetState);
                      hasChanged := true;
                    };
                  };
                };
                case null { /* This shouldn't happen if the NFA is well-formed */ };
              };
            };
          };

          epsilonClosureCache.put(state, closureBuffer);
          return closureBuffer;
        };
      };
    };

    private func rebuildCompiledRegex(
      stateTransitionsMap: HashMap.HashMap<Types.State, Buffer.Buffer<(Types.Transition, Types.State)>>,
      startState: Types.State,
      acceptStates: [Types.State],
      captureGroups: [Types.CaptureGroup]
    ): Types.CompiledRegex {
      let transitionsBuffer = Buffer.Buffer<(Types.State, Types.Transition, Types.State)>(stateTransitionsMap.size() * 2);

      for ((fromState, transitionBuffer) in stateTransitionsMap.entries()) {
        for ((transition, toState) in transitionBuffer.vals()) {
          transitionsBuffer.add((fromState, transition, toState));
        };
      };

      {
        transitions = Buffer.toArray(transitionsBuffer);
        startState = startState;
        acceptStates = acceptStates;
        captureGroups = captureGroups;
      }
    };

    private func groupTransitionsByState(
      nfa: Types.CompiledRegex
    ): HashMap.HashMap<Types.State, Buffer.Buffer<(Types.Transition, Types.State)>> {
      
      let stateTransitionsMap = HashMap.HashMap<Types.State, Buffer.Buffer<(Types.Transition, Types.State)>>(
        nfa.transitions.size(),
        Nat.equal,
        Hash.hash
      );

      for ((fromState, transition, toState) in nfa.transitions.vals()) {
        switch (stateTransitionsMap.get(fromState)) {
          case null {
            let newTransitionBuffer = Buffer.Buffer<(Types.Transition, Types.State)>(4);
            newTransitionBuffer.add((transition, toState));
            stateTransitionsMap.put(fromState, newTransitionBuffer);
          };
          case (?existingTransitionBuffer) {
            existingTransitionBuffer.add((transition, toState));
          };
        };
      };

      stateTransitionsMap
    };
  };
} */

