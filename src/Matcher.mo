import Types "Types";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Debug "mo:base/Debug";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import {substring; charAt; containsState; compareChars; isInRange} "Extensions";

module {
  public class Matcher() {
    type NFA = Types.CompiledRegex;
    type Flags = Types.Flags;
    type Match = Types.Match;
    type MatchError = Types.RegexError;
    type State = Types.State;
    type Symbol = Types.Symbol;
    type AnchorType = Types.AnchorType;
    type Capture = {
      groupIndex : Nat;
      startIndex : ?Nat;
      endIndex : ?Nat;
      text : ?Text
    };

    private var mode : Bool = false;

    private func log(msg : Text) {
      if (mode) {
        Debug.print(msg)
      }
    };

    public func debugMode(bool : Bool) {
      mode := bool
    };
    public func inspect(x :State, nfa:NFA): Result.Result<[Types.Transition], MatchError> {
      if (containsState(nfa.states, x)) {
        return #ok(nfa.transitionTable[x])
      } else {
        return #err(#InvalidTransition("State " # Nat.toText(x) # " is not in the NFA"))
      }
    };
    private func createMatch(text : Text, startIndex : Nat, index : Nat, captures : Buffer.Buffer<Capture>) : Result.Result<Match, MatchError> {
      var finalCaptures = Buffer.Buffer<(Text, Nat)>(0);
      for (cap in captures.vals()) {
        switch (cap.text) {
          case (?txt) {finalCaptures.add(txt, cap.groupIndex)};
          case null {}
        }
      };
      #ok({
        string = text;
        value = substring(text, startIndex, index);
        status = #FullMatch;
        position = (startIndex, index);
        capturedGroups = ?Buffer.toArray<(Text, Nat)>(finalCaptures);
        spans = [(startIndex, index)];
        lastIndex = index
      })
    };

    public func match(nfa : NFA, text : Text, flags : ?Flags) : Result.Result<Match, MatchError> {
      var currentState = nfa.startState;
      var index = 0;

      var captures = Buffer.Buffer<Capture>(0);
      for (assertion in nfa.assertions.vals()) {
        switch (assertion.assertion) {
          case (#Group(group)) {
            captures.add({
              groupIndex = group.captureIndex;
              startIndex = null;
              endIndex = null;
              text = null
            });
            log("Initialized capture group " # debug_show(group.captureIndex));
          };
          case _ {}
        }
      };

      func handleGroupStarts(state : State) {
        for (assertion in nfa.assertions.vals()) {
          switch (assertion.assertion) {
            case (#Group(group)) {
              if (group.startState == state) {
                let cap = captures.get(group.captureIndex - 1);
                captures.put(
                  group.captureIndex - 1,
                  {
                    groupIndex = cap.groupIndex;
                    startIndex = ?index;
                    endIndex = cap.endIndex;
                    text = cap.text
                  }
                );
                log("Starting capture group " # debug_show(group.captureIndex) # " at index " # debug_show(index));
              }
            };
            case _ {}
          }
        }
      };

      func handleGroupEnds(state : State) {
        for (assertion in nfa.assertions.vals()) {
          switch (assertion.assertion) {
            case (#Group(group)) {
              if (containsState(group.endStates, state)) {
                let cap = captures.get(group.captureIndex - 1);
                switch (cap.startIndex) {
                  case (?startIdx) {
                    let capturedText = substring(text, startIdx, index);
                    captures.put(
                      group.captureIndex - 1,
                      {
                        groupIndex = cap.groupIndex;
                        startIndex = cap.startIndex;
                        endIndex = ?index;
                        text = ?capturedText
                      }
                    );
                    log("Ending capture group " # debug_show(group.captureIndex) # " at index " # debug_show(index) # " with text: " # capturedText);
                  };
                  case null {
                    log("Warning: Attempted to end group " # debug_show(group.captureIndex) # " without start index");
                  }
                }
              }
            };
            case _ {}
          }
        }
      };

      log("Starting match with text: " # text);

      label matching while (index < text.size()) {
        log("Starting new character iteration at index " # debug_show(index) # " of " # debug_show(text.size()));
        let char = charAt(index, text);
        let possibleTransitions = nfa.transitionTable[currentState];
        var matched = false;
        var nextState = currentState;

        handleGroupStarts(currentState);

        var isAcceptState = false;
        if (containsState(nfa.acceptStates, currentState)) {
            log("Current state " # debug_show(currentState) # " is an accept state");
            isAcceptState := true;
        } else {
            log("Current state " # debug_show(currentState) # " is not an accept state");
        };

        log("At index " # debug_show (index) # " with char '" # Text.fromChar(char) # "' in state " # debug_show (currentState));

        label charTransitions for (t in possibleTransitions.vals()) {
          if (t.0 == currentState) {
            switch (t.1) {
              case (#Char(c)) {
                if (compareChars(char, c, flags)) {
                  matched := true;
                  nextState := t.2;
                  let quantifierMode = t.3;
                  let isGreedy = quantifierMode == null or quantifierMode == ? #Greedy;
                  log("Found exact char match - transitioning to state " # debug_show (t.2));

                  if (not isGreedy and isAcceptState) {
                    log("Lazy match at accept state - returning early");
                    return createMatch(text, 0, index, captures)
                  };

                  if (not isGreedy) {
                    log("Lazy match - breaking character transitions");
                    break charTransitions
                  } 
                }else {
                  log("Character '" # Text.fromChar(char) # "' did not match expected '" # Text.fromChar(c) # "'");
                }
              };
              case _ {}
            }
          }
        };

        if (not matched) {
          log("No exact character matches found, checking range matches");
          label rangeTransitions for (t in possibleTransitions.vals()) {
            if (t.0 == currentState) {
              switch (t.1) {
                case (#Range((start, end))) {
                  if (isInRange(char, start, end, flags)) {
                    matched := true;
                    nextState := t.2;
                    let quantifierMode = t.3;
                    let isGreedy = quantifierMode == null or quantifierMode == ? #Greedy;
                    log("Found range match - transitioning to state " # debug_show (t.2));

                    if (not isGreedy and isAcceptState) {
                      log("Lazy range match at accept state - returning early");
                      return createMatch(text, 0, index, captures)
                    };

                    if (not isGreedy) {
                      log("Lazy range match - breaking range transitions");
                      break rangeTransitions
                    }
                  }else {
                    log("Character '" # Text.fromChar(char) # "' not in range '" # Text.fromChar(start) # "'-'" # Text.fromChar(end) # "'");
                  }
                };
                case _ {}
              }
            }
          }
        };

        if (matched) {
          currentState := nextState;
          index += 1;
          handleGroupEnds(currentState);
          log("Match succeeded at index " # debug_show(index) # " with char '" # Text.fromChar(char) # "' - moving to state " # debug_show(nextState));
          if (isAcceptState and index < text.size()) {
            let nextChar = charAt(index, text);
            var canContinue = false;
            log("Checking if can continue past accept state with next char '" # Text.fromChar(nextChar) # "'");
            for (t in nfa.transitionTable[currentState].vals()) {
              switch (t.1) {
                case (#Char(c)) if (compareChars(nextChar, c, flags)) canContinue := true;
                case (#Range((start, end))) if (isInRange(nextChar, start, end, flags)) canContinue := true
              }
            };
            if (not canContinue) {
              log("No valid transitions for next character - returning match");
              return createMatch(text, 0, index, captures)
            };
            log("Found valid continuation - proceeding with match");
          }
        } else {
          log("Match failed at index " # debug_show(index) # " - no valid transitions found for char '" # Text.fromChar(char) # "' from state " # debug_show(currentState));
          break matching
        }
      };
      log("Reached end of matching at index " # debug_show(index) # " in state " # debug_show(currentState) # " - checking if in accept state");
      if (containsState(nfa.acceptStates, currentState)) {
        log("Match succeeded - in accept state at end of input");
        return createMatch(text, 0, index, captures)
      };
      log("No match found - stopped at index " # debug_show(index) # " in state " # debug_show(currentState));
      #ok({
        string = text;
        value = "";
        status = #NoMatch;
        position = (0, 0);
        capturedGroups = null;
        spans = [];
        lastIndex = index
      })
    };

    public func search(nfa : NFA, text : Text, flags : ?Flags) : Result.Result<Match, MatchError> {
      var startIndex = 0;
      let textSize = text.size();

      while (startIndex < textSize) {
        let char = charAt(startIndex, text);
        let transitions = nfa.transitionTable[nfa.startState];
        var validStart = false;

        for (t in transitions.vals()) {
          switch (t.1) {
            case (#Char(c)) {
              if (compareChars(char, c, flags)) {
                validStart := true
              }
            };
            case (#Range((start, end))) {
              if (isInRange(char, start, end, flags)) {
                validStart := true
              }
            }
          }
        };

        if (validStart) {
          switch (match(nfa, substring(text, startIndex, textSize), flags)) {
            case (#ok(matchResult)) {
              switch (matchResult.status) {
                case (#FullMatch) {
                  return #ok({
                    string = text;
                    value = matchResult.value;
                    status = #FullMatch;
                    position = (startIndex + matchResult.position.0, startIndex + matchResult.position.1);
                    capturedGroups = matchResult.capturedGroups;
                    spans = [(startIndex + matchResult.position.0, startIndex + matchResult.position.1)];
                    lastIndex = startIndex + matchResult.lastIndex
                  })
                };
                case (#NoMatch) {}
              }
            };
            case (#err(e)) return #err(e)
          }
        };
        startIndex += 1
      };

      #ok({
        string = text;
        value = "";
        status = #NoMatch;
        position = (0, 0);
        capturedGroups = null;
        spans = [];
        lastIndex = 0
      })
    };

    public func findAll(nfa : NFA, text : Text, flags : ?Flags) : Result.Result<[Match], MatchError> {
      var startIndex = 0;
      let textSize = text.size();
      var matches = Buffer.Buffer<Match>(0);

      while (startIndex < textSize) {
        switch (search(nfa, substring(text, startIndex, textSize), flags)) {
          case (#ok(matchResult)) {
            switch (matchResult.status) {
              case (#FullMatch) {
                let adjustedMatch = {
                  string = text;
                  value = matchResult.value;
                  status = #FullMatch;
                  position = (startIndex + matchResult.position.0, startIndex + matchResult.position.1);
                  capturedGroups = matchResult.capturedGroups;
                  spans = matchResult.spans;
                  lastIndex = startIndex + matchResult.lastIndex
                };
                matches.add(adjustedMatch);
                startIndex := adjustedMatch.position.1
              };
              case (#NoMatch) {
                startIndex += 1
              }
            }
          };
          case (#err(e)) {
            return #err(e)
          }
        }
      };
      return #ok(Buffer.toArray(matches))
    };

    public func findIter(nfa : NFA, text : Text, flags : ?Flags) : Result.Result<Iter.Iter<Match>, MatchError> {
      switch (findAll(nfa, text, flags)) {
        case (#ok(matches)) {
          let matchIter : Iter.Iter<Match> = Iter.fromArray(matches);
          return #ok(matchIter)
        };
        case (#err(e)) {
          return #err(e)
        }
      }
    };
    public func split(nfa : NFA, text : Text, maxSplit : ?Nat, flags : ?Flags) : Result.Result<[Text], MatchError> {
      let splitLimit = switch (maxSplit) {
        case (null) 0;
        case (?val) val
      };

      if (text.size() == 0) {
        return #err(#EmptyExpression("Empty expression"))
      };

      switch (findAll(nfa, text, flags)) {
        case (#err(e)) #err(e);
        case (#ok(delimiterMatches)) {
          let results = Buffer.Buffer<Text>(delimiterMatches.size());
          var lastIndex = 0;
          var splitCount = 0;

          label splitting for (delimMatch in delimiterMatches.vals()) {
            if (splitLimit > 0 and splitCount >= splitLimit) {
              break splitting
            };
            if (delimMatch.position.0 == delimMatch.position.1 and delimMatch.position.0 == 0) {
              continue splitting
            };
            if (lastIndex < delimMatch.position.0) {
              results.add(substring(text, lastIndex, delimMatch.position.0))
            };
            switch (delimMatch.capturedGroups) {
              case (?groups) {
                if (groups.size() > 0) {
                  results.add(delimMatch.value)
                }
              };
              case (null) {}
            };

            lastIndex := delimMatch.position.1;
            splitCount += 1
          };
          if (lastIndex < text.size()) {
            results.add(substring(text, lastIndex, text.size()))
          };

          #ok(Buffer.toArray(results))
        }
      }
    };
    public func replace(nfa : NFA, text : Text, replacement : Text, maxReplace : ?Nat, flags : ?Flags) : Result.Result<Text, MatchError> {
      if (
        Text.contains(replacement, #char '\\') or Text.contains(replacement, #char '*') or Text.contains(replacement, #char '+') or
        Text.contains(replacement, #char '?') or Text.contains(replacement, #char '.') or Text.contains(replacement, #char '^') or
        Text.contains(replacement, #char '$') or Text.contains(replacement, #char '[') or Text.contains(replacement, #char ']') or
        Text.contains(replacement, #char '(') or Text.contains(replacement, #char ')')
      ) {
        return #err(#GenericError("Replacement must be a string literal it cannot contain reserved regex symbols, use sub() instead"))
      };

      let replaceLimit = switch (maxReplace) {
        case (null) 0;
        case (?val) val
      };
      if (text.size() == 0) {
        return #err(#EmptyExpression("Empty expression"))
      };
      switch (findAll(nfa, text, flags)) {
        case (#err(e)) #err(e);
        case (#ok(matches)) {
          let result = Buffer.Buffer<Text>(text.size());
          var lastIndex = 0;
          var replaceCount = 0;

          label replacing for (match in matches.vals()) {
            if (replaceLimit > 0 and replaceCount >= replaceLimit) {
              break replacing
            };
            if (lastIndex < match.position.0) {
              result.add(substring(text, lastIndex, match.position.0))
            };
            let processedReplacement = switch (match.capturedGroups) {
              case (?groups) {
                var repText = replacement;
                for ((text, index) in groups.vals()) {
                  let groupRef = "\\" # Nat.toText(index);
                  repText := Text.replace(repText, #text groupRef, text)
                };
                repText
              };
              case (null) replacement
            };
            result.add(processedReplacement);
            lastIndex := match.position.1;
            replaceCount += 1
          };
          if (lastIndex < text.size()) {
            result.add(substring(text, lastIndex, text.size()))
          };

          #ok(Text.join("", result.vals()))
        }
      }
    };
    public func sub(nfa : NFA, text : Text, replacement : Text, maxReplace : ?Nat, flags : ?Flags) : Result.Result<Text, MatchError> {
      if (text.size() == 0) {
        return #err(#EmptyExpression("Empty expression"))
      };

      switch (findAll(nfa, text, flags)) {
        case (#err(e)) #err(e);
        case (#ok(matches)) {
          let result = Buffer.Buffer<Text>(text.size());
          var lastIndex = 0;
          var replaceCount = 0;

          let replaceLimit = switch (maxReplace) {
            case (null) 0;
            case (?val) val
          };

          label replacing for (match in matches.vals()) {
            if (replaceLimit > 0 and replaceCount >= replaceLimit) {
              break replacing
            };

            if (lastIndex < match.position.0) {
              result.add(substring(text, lastIndex, match.position.0))
            };

            let processedReplacement = switch (match.capturedGroups) {
              case (?groups) {
                var repText = replacement;
                for ((text, index) in groups.vals()) {
                  let groupRef = "\\" # Nat.toText(index);
                  repText := Text.replace(repText, #text groupRef, text)
                };
                repText
              };
              case (null) replacement
            };

            result.add(processedReplacement);
            lastIndex := match.position.1;
            replaceCount += 1
          };

          if (lastIndex < text.size()) {
            result.add(substring(text, lastIndex, text.size()))
          };

          #ok(Text.join("", result.vals()))
        }
      }
    };
  }
}