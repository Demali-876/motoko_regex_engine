import Types "Types";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Debug "mo:base/Debug";
import {substring} "Extensions";

module {
    public class Matcher() {
        type NFA = Types.CompiledRegex;
        type Flags = Types.Flags;
        type Match = Types.Match;
        type MatchError = Types.RegexError;

        public func match(nfa: NFA, text: Text, flags: ?Flags): Result.Result<Match, MatchError> {
            var currentState = nfa.startState;
            let chars = Text.toIter(text);
            var index = 0;
            
            Debug.print("Starting match with start state: " # debug_show(currentState));
            Debug.print("Accept states are: " # debug_show(nfa.acceptStates));
            
            // Process each character
            label matching
            for (char in chars) {
                let possibleTransitions = nfa.transitionsByState[currentState];
                var matched = false;
                
                label transitions
                for (t in possibleTransitions.vals()) {
                    if (t.0 == currentState) {
                        switch(t.1) {
                            case (#Char(c)) {
                                if (char == c) {
                                    currentState := t.2;
                                    matched := true;
                                    Debug.print("Matched '" # debug_show(char) # "' - Moving to state " # debug_show(currentState));
                                    break transitions;
                                };
                            };
                            case _ {};
                        };
                    };
                };
                
                if (not matched) {
                    break matching;
                };
                index += 1;
                // Check if we've reached an accept state
                for (accept in nfa.acceptStates.vals()) {
                    if (accept == currentState) {
                        return #ok({
                            status = #FullMatch;
                            position = (0, index);
                            value = substring(text, 0, index);
                            capturedGroups = null;
                        });
                    };
                };
            };
            
            #ok({
                status = #NoMatch;
                position = (0, index);
                value = "";
                capturedGroups = null;
            })
        };
    };
};