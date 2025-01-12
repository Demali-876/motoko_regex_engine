import Types "Types";
module {
    public func formatNFA(regex: Types.CompiledRegex) : Text {
        var output = "\n=== NFA State Machine ===\n";
        
        output #= "Initial State → " # debug_show(regex.startState) # "\n";
        output #= "Accept States → " # debug_show(regex.acceptStates) # "\n";
        
        output #= "\n=== Transitions ===\n";
        for (stateIdx in regex.states.keys()) {
            let transitions = regex.transitionTable[stateIdx];
            if (transitions.size() > 0) {
                output #= formatStateTransitions(stateIdx, transitions);
            };
        };
        
        if (regex.assertions.size() > 0) {
            output #= "\n=== Assertions ===\n";
            for (assertion in regex.assertions.vals()) {
                output #= formatAssertion(assertion);
            };
        };
        
        output
    };
    
    public func formatStateTransitions(state: Types.State, transitions: [Types.Transition]) : Text {
        var output = "From State " # debug_show(state) # ":\n";
        
        for ((fromState, symbol, toState, quantifier) in transitions.vals()) {
            output #= "  " # debug_show(symbol) # " → " # debug_show(toState);
            switch(quantifier) {
                case (null) {};
                case (?mode) output #= " (" # debug_show(mode) # ")";
            };
            output #= "\n";
        };
        output
    };
    
    public func formatAssertion(assertion: Types.Assertion) : Text {
        var output = "";
        
        switch(assertion.assertion) {
            case (#Anchor(a)) {
                output #= "Anchor: " # debug_show(a) # "\n";
            };
            case (#Lookaround(l)) {
                output #= "Lookaround:\n";
                output #= "  Position: " # debug_show(l.position) # "\n";
                output #= "  Direction: " # (if (l.isAhead) "ahead" else "behind") # "\n";
                output #= "  Type: " # (if (l.isPositive) "positive" else "negative") # "\n";
                output #= "  Start: " # debug_show(l.startState) # "\n";
                output #= "  Accept: " # debug_show(l.acceptStates) # "\n";
            };
            case (#Group(g)) {
                output #= "Group " # debug_show(g.captureIndex) # ":\n";
                output #= "  Start: " # debug_show(g.startState) # "\n";
                output #= "  End: " # debug_show(g.endStates) # "\n";
            };
        };
        output
    };
}