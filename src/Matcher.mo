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

        private var debugMode = false;

        private func log(msg: Text) {
            if (debugMode) {
                Debug.print(msg);
            };
        };

        public func setDebugMode(bool: Bool) {
            debugMode := bool;
        };

        public func match(nfa: NFA, text: Text, flags: ?Flags): Result.Result<Match, MatchError> {
            var currentState = nfa.startState;
            let chars = Text.toIter(text);
            var index = 0;

            log("Starting match with start state: " # debug_show(currentState));
            log("Accept states are: " # debug_show(nfa.acceptStates));

            // Process each character
            label matching
            for (char in chars) {
                let possibleTransitions = nfa.transitionsByState[currentState];
                var matched = false;

                log("Processing char: '" # debug_show(char) # "' at index " # debug_show(index));
                log("Current state: " # debug_show(currentState));
                log("Possible transitions: " # debug_show(possibleTransitions));

                label transitions
                for (t in possibleTransitions.vals()) {
                    if (t.0 == currentState) {
                        switch(t.1) {
                            case (#Char(c)) {
                                log("Comparing with transition: " # debug_show(t));
                                if (char == c) {
                                    currentState := t.2;
                                    matched := true;
                                    log("Matched! Moving to state " # debug_show(currentState));
                                    break transitions;
                                };
                            };
                            case _ {};
                        };
                    };
                };
                
                if (not matched) {
                    log("No match found - ending search");
                    break matching;
                };
                index += 1;
                
                // Check if we've reached an accept state
                for (accept in nfa.acceptStates.vals()) {
                    if (accept == currentState) {
                        log("Reached accept state " # debug_show(currentState));
                        return #ok({
                            string = text;
                            value = substring(text, 0, index);
                            status = #FullMatch;
                            position = (0, index);
                            capturedGroups = null;
                            spans = [(0, index)];
                            lastIndex = index;
                        });
                    };
                };
            };
            
            log("No full match found");
            #ok({
                string = text;
                value = "";
                status = #NoMatch;
                position = (0, 0);
                capturedGroups = null;
                spans = [];
                lastIndex = index;
            })
        };
    };
};