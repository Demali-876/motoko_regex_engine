import Types "Types";
import Buffer "mo:base/Buffer";
import HashMap "mo:base/HashMap";
import Hash "mo:base/Hash";
import Order "mo:base/Order";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Array "mo:base/Array";
import Option "mo:base/Option";
import Bool "mo:base/Bool";
import LRU "mo:lrucache/lru-cache";
import Extensions "Extensions";
/*
module {
  public class Optimizer() {
    type State = Types.State;
    type NFA = Types.CompiledRegex;
    type Transition = Types.Transition;
    type TransitionTable = Types.TransitionTable;

    private var parent = HashMap.HashMap<State, State>(10, Nat.equal, Hash.hash);
    private var rank = HashMap.HashMap<State, Nat>(10, Nat.equal, Hash.hash);
    private let comparisonCache = LRU.LRU<(State, State), Bool>(100, Extensions.tupleEqual, Extensions.tupleHash);

    private func initializeUnionFind(states: [State]) {
      for (state in states.vals()) {
        parent.put(state, state);
        rank.put(state, 0);
      };
    };

    private func find(state: State): State {
      switch (parent.get(state)) {
        case (?p) {
          if (p != state) {
            let root = find(p);
            parent.put(state, root); // Path compression
            return root;
          };
          return p;
        };
        case null { return state };
      };
    };

    private func union(state1: State, state2: State) {
      let root1 = find(state1);
      let root2 = find(state2);

      if (root1 != root2) {
        let rank1 = Option.get(rank.get(root1), 0);
        let rank2 = Option.get(rank.get(root2), 0);

        if (rank1 > rank2) {
          parent.put(root2, root1);
        } else if (rank1 < rank2) {
          parent.put(root1, root2);
        } else {
          parent.put(root2, root1);
          rank.put(root1, rank1 + 1);
        };
      };
    };

    public func optimize(compiledNFA: NFA): NFA {
      let groupedTransitions = groupTransitionsByState(compiledNFA);
      let transitionsWithoutEpsilon = eliminateEpsilonTransitions(groupedTransitions);

      let refinedPartition = bisimulationRefine(
        initializePartition(transitionsWithoutEpsilon, compiledNFA.acceptStates),
        transitionsWithoutEpsilon
      );

      rebuildNFA(refinedPartition, transitionsWithoutEpsilon, compiledNFA.startState, compiledNFA.acceptStates);
    };

    private func eliminateEpsilonTransitions(
      stateTransitionsMap: HashMap.HashMap<State, Buffer.Buffer<(Transition, State)>>
    ): HashMap.HashMap<State, Buffer.Buffer<(Transition, State)>> {
      initializeUnionFind(Iter.toArray(stateTransitionsMap.keys()));

      for ((state, transitions) in stateTransitionsMap.entries()) {
        for ((transition, targetState) in transitions.vals()) {
          if (transition == #Epsilon) {
            union(state, targetState);
          };
        };
      };

      let newStateTransitionsMap = HashMap.HashMap<State, Buffer.Buffer<(Transition, State)>>(
        stateTransitionsMap.size(),
        Nat.equal,
        Hash.hash
      );

      for ((state, transitions) in stateTransitionsMap.entries()) {
        let nonEpsilonTransitions = Buffer.Buffer<(Transition, State)>(transitions.size());
        let representativeState = find(state);

        for ((transition, targetState) in transitions.vals()) {
          if (transition != #Epsilon) {
            let representativeTargetState = find(targetState);
            if (Option.isNull(Array.find(Buffer.toArray(nonEpsilonTransitions), func (existing: (Transition, State)): Bool {
              existing == (transition, representativeTargetState)
            }))) {
              nonEpsilonTransitions.add((transition, representativeTargetState));
            };
          };
        };

        switch (newStateTransitionsMap.get(representativeState)) {
          case (?existing) {
            for (transition in nonEpsilonTransitions.vals()) {
              existing.add(transition);
            };
          };
          case null {
            newStateTransitionsMap.put(representativeState, nonEpsilonTransitions);
          };
        };
      };

      newStateTransitionsMap
    };

    private func initializePartition(
      stateTransitionsMap: HashMap.HashMap<State, Buffer.Buffer<(Transition, State)>>,
      acceptStates: [State]
    ): Buffer.Buffer<[State]> {
      let partition = Buffer.Buffer<[State]>(2);
      let acceptPartition = Buffer.Buffer<State>(acceptStates.size());
      let nonAcceptPartition = Buffer.Buffer<State>(stateTransitionsMap.size());

      for (state in stateTransitionsMap.keys()) {
        if (Array.find<State>(acceptStates, func x = x == state) != null) {
          acceptPartition.add(state);
        } else {
          nonAcceptPartition.add(state);
        };
      };

      if (acceptPartition.size() > 0) {
        partition.add(Buffer.toArray(acceptPartition));
      };
      if (nonAcceptPartition.size() > 0) {
        partition.add(Buffer.toArray(nonAcceptPartition));
      };

      partition
    };

    private func bisimulationRefine(
      partition: Buffer.Buffer<[State]>,
      transitions: HashMap.HashMap<State, Buffer.Buffer<(Transition, State)>>
    ): Buffer.Buffer<[State]> {
      var currentPartition = partition;
      var iterationCount = 0;
      let maxIterations = 1000; // Safeguard against infinite loops

      label l loop {
        let newPartition = Buffer.Buffer<[State]>(currentPartition.size());
        var changed = false;

        for (block in currentPartition.vals()) {
          if (block.size() > 0) {
            let (refinedBlock, refinedRest) = refineBlock(block, transitions, currentPartition);
            if (refinedRest.size() > 0) {
              newPartition.add(refinedBlock);
              newPartition.add(refinedRest);
              changed := true;
            } else {
              newPartition.add(block);
            };
          };
        };
        
        if (not changed or iterationCount >= maxIterations) {
          break l;
        };

        currentPartition := newPartition;
        iterationCount += 1;
      };

      currentPartition
    };

    private func refineBlock(
      block: [State],
      transitions: HashMap.HashMap<State, Buffer.Buffer<(Transition, State)>>,
      partition: Buffer.Buffer<[State]>
    ): ([State], [State]) {
      if (block.size() == 0) {
        return ([], []);
      };

      let refinedBlock = Buffer.Buffer<State>(block.size());
      let refinedRest = Buffer.Buffer<State>(block.size());

      let baseTransitions = transitions.get(block[0]);

      for (state in block.vals()) {
        let cacheKey = (block[0], state);
        switch (comparisonCache.get(cacheKey, null)) {
          case (?true) {
            refinedBlock.add(state);
          };
          case (?false) {
            refinedRest.add(state);
          };
          case null {
            if (compareTransitions(state, baseTransitions, transitions)) {
              refinedBlock.add(state);
              comparisonCache.put(cacheKey, true);
            } else {
              refinedRest.add(state);
              comparisonCache.put(cacheKey, false);
            };
          };
        };
      };

      (Buffer.toArray(refinedBlock), Buffer.toArray(refinedRest))
    };

    private func compareTransitions(
      state: State,
      baseTransitions: ?Buffer.Buffer<(Transition, State)>,
      transitions: HashMap.HashMap<State, Buffer.Buffer<(Transition, State)>>
    ): Bool {
      let stateTransitions = transitions.get(state);

      switch (baseTransitions, stateTransitions) {
        case (null, null) { true };
        case (?base, ?state) {
          let baseTransitionsOnly = Buffer.map<(Transition, State), Transition>(base, func(pair: (Transition, State)): Transition {
            pair.0
          });
          let stateTransitionsOnly = Buffer.map<(Transition, State), Transition>(state, func(pair: (Transition, State)): Transition {
            pair.0
          });

          let sortedBase = Array.sort<Transition>(Buffer.toArray<Transition>(baseTransitionsOnly), Extensions.compareTransition);
          let sortedState = Array.sort<Transition>(Buffer.toArray<Transition>(stateTransitionsOnly), Extensions.compareTransition);

          if (sortedBase.size() != sortedState.size()) { return false };
          for (i in Iter.range(0, sortedBase.size() - 1)) {
            if (sortedBase[i] != sortedState[i]) { return false };
          };
          true
        };
        case _ { false };
      }
    };

    private func rebuildNFA(
      refinedPartition: Buffer.Buffer<[State]>,
      stateTransitionsMap: HashMap.HashMap<State, Buffer.Buffer<(Transition, State)>>,
      startState: State,
      acceptStates: [State],
    ): Types.CompiledRegex {
      let transitionsBuffer = Buffer.Buffer<(State, Transition, State)>(stateTransitionsMap.size() * 2);
      let stateRenumbering = HashMap.HashMap<State, State>(stateTransitionsMap.size(), Nat.equal, Hash.hash);
      var newStateCounter: State = 1; // Start from 1 to match the desired output

      // First, ensure the start state is numbered 0
      stateRenumbering.put(startState, 0);

      // Then, number the rest of the states
      for (block in refinedPartition.vals()) {
        for (state in block.vals()) {
          if (Option.isNull(stateRenumbering.get(state)) and state != startState) {
            stateRenumbering.put(state, newStateCounter);
            newStateCounter += 1;
          };
        };
      };

      // Rebuild transitions with renumbered states
      for ((fromState, transitionBuffer) in stateTransitionsMap.entries()) {
        let renumberedFromState = Option.get(stateRenumbering.get(fromState), fromState);

        for ((transition, toState) in transitionBuffer.vals()) {
          let renumberedToState = Option.get(stateRenumbering.get(toState), toState);
          transitionsBuffer.add((renumberedFromState, transition, renumberedToState));
        };
      };

      // Renumber accept states
      let renumberedAcceptStates = Array.map(acceptStates, func (acceptState: State): State {
        Option.get(stateRenumbering.get(acceptState), acceptState)
      });

      // Sort transitions to ensure consistent ordering
      let sortedTransitions = Array.sort(Buffer.toArray(transitionsBuffer), func (a: (State, Transition, State), b: (State, Transition, State)): Order.Order {
        if (a.0 < b.0) { #less }
        else if (a.0 > b.0) { #greater }
        else if (a.2 < b.2) { #less }
        else if (a.2 > b.2) { #greater }
        else { #equal }
      });

      {
        transitions = sortedTransitions;
        startState = 0; // Ensure start state is always 0
        acceptStates = renumberedAcceptStates;
      }
    };

    private func groupTransitionsByState(nfa: NFA): HashMap.HashMap<State, Buffer.Buffer<(Transition, State)>> {
      let stateTransitionsMap = HashMap.HashMap<State, Buffer.Buffer<(Transition, State)>>(
        nfa.transitions.size(),
        Nat.equal,
        Hash.hash
      );

      for ((fromState, transition, toState) in nfa.transitions.vals()) {
        switch (stateTransitionsMap.get(fromState)) {
          case null {
            let newTransitionBuffer = Buffer.Buffer<(Transition, State)>(4);
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
};

*/
