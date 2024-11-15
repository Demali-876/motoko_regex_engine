import Types "Types";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Debug "mo:base/Debug";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import {substring} "Extensions";
import {charAt} "Extensions";
import {containsState} "Extensions";

module {
  public class Matcher() {
    type NFA = Types.CompiledRegex;
    type Flags = Types.Flags;
    type Match = Types.Match;
    type MatchError = Types.RegexError;
    type State = Types.State;
    type Symbol = Types.Symbol;
    type AnchorType = Types.AnchorType;

    private var mode : Bool = false;
    private var regex : NFA = {
      startState = 0;
      acceptStates = [];
      transitionTable = [];
      assertions = [];
      states = [];
      transitions = []
    };

    private func log(msg : Text) {
      if (mode) {
        Debug.print(msg)
      }
    };

    public func debugMode(bool : Bool) {
      mode := bool
    };

    public func match(nfa : NFA, text : Text, flags : ?Flags) : Result.Result<Match, MatchError> {
      regex := nfa;
      var currentState = nfa.startState;
      var chars = Text.toIter(text);
      var index = 0;

      type Capture = {
        groupIndex : Nat;
        startIndex : ?Nat;
        endIndex : ?Nat;
        text : ?Text
      };

      var captures = Buffer.Buffer<Capture>(0);
      for (assertion in nfa.assertions.vals()) {
        switch (assertion.assertion) {
          case (#Group(group)) {
            captures.add({
              groupIndex = group.captureIndex;
              startIndex = null;
              endIndex = null;
              text = null
            })
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
                  group.captureIndex -1,
                  {
                    groupIndex = cap.groupIndex;
                    startIndex = ?index;
                    endIndex = cap.endIndex;
                    text = cap.text
                  }
                );
                log("Group " # debug_show (group.captureIndex) # " starts at index " # debug_show (index))
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
                let cap = captures.get(group.captureIndex -1);
                switch (cap.startIndex) {
                  case (?startIdx) {
                    let capturedText = substring(text, startIdx, index);
                    captures.put(
                      group.captureIndex -1,
                      {
                        groupIndex = cap.groupIndex;
                        startIndex = cap.startIndex;
                        endIndex = ?index;
                        text = ?capturedText
                      }
                    );
                    log("Group " # debug_show (group.captureIndex) # " ends at index " # debug_show (index) # " with text: " # capturedText)
                  };
                  case null {}
                }
              }
            };
            case _ {}
          }
        }
      };

      func checkAnchor(aType : AnchorType) : Bool {
        switch (aType) {
          case (#StartOfString) {
            switch (flags) {
              case (?f) {
                if (f.multiline) {
                  index == 0 or (index > 0 and charAt(index - 1, text) == '\n')
                } else {
                  index == 0
                }
              };
              case null {index == 0}
            }
          };
          case (#EndOfString) {
            switch (flags) {
              case (?f) {
                if (f.multiline) {
                  index == text.size() or charAt(index, text) == '\n'
                } else {
                  index == text.size()
                }
              };
              case null {index == text.size()}
            }
          };
          case _ {
            true //TODO: Implement other anchors
          }
        }
      };

      log("Starting match with start state: " # debug_show (currentState));

      label matching for (char in chars) {
        let possibleTransitions = nfa.transitionTable[currentState];
        var matched = false;

        handleGroupStarts(currentState);

        for (assertion in nfa.assertions.vals()) {
          switch (assertion.assertion) {
            case (#Anchor({aType; position})) {
              if (position == currentState and not checkAnchor(aType)) {
                return #ok({
                  string = text;
                  value = "";
                  status = #NoMatch;
                  position = (0, 0);
                  capturedGroups = null;
                  spans = [];
                  lastIndex = index
                })
              }
            };
            case (#Lookaround(l)) {
              if (l.position == currentState) {
                // TODO: Implement lookaround matching
              }
            };
            case _ {}
          }
        };

        label transitions for (t in possibleTransitions.vals()) {
          if (t.0 == currentState) {
            switch (t.1) {
              case (#Char(c)) {
                log("Comparing with transition: " # debug_show (t));

                let matchChar = switch (flags) {
                  case (?f) {
                    if (not f.caseSensitive) {
                      Text.toLowercase(Text.fromChar(char)) == Text.toLowercase(Text.fromChar(c))
                    } else {
                      char == c
                    }
                  };
                  case null {char == c}
                };

                if (matchChar) {
                  let nextState = t.2;
                  matched := true;
                  log("Matched! Moving to state " # debug_show (nextState));
                  index += 1;

                  currentState := nextState;
                  handleGroupEnds(currentState);

                  break transitions
                }
              };
              case _ {}
            }
          }
        };

        if (not matched) {
          log("No match found - ending search");
          break matching
        };

        for (accept in nfa.acceptStates.vals()) {
          if (accept == currentState) {
            log("Reached accept state " # debug_show (currentState));

            var finalCaptures = Buffer.Buffer<(Text, Nat)>(0);
            for (cap in captures.vals()) {
              switch (cap.text) {
                case (?txt) {
                  finalCaptures.add(txt, cap.groupIndex)
                };
                case null {}
              }
            };

            return #ok({
              string = text;
              value = substring(text, 0, index);
              status = #FullMatch;
              position = (0, index);
              capturedGroups = ?Buffer.toArray<(Text, Nat)>(finalCaptures);
              spans = [(0, index)];
              lastIndex = index
            })
          }
        }
      };

      log("No full match found");
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
      regex := nfa;
      var startIndex = 0;
      let textSize = text.size();

      while (startIndex < textSize) {
        let remainingstring : Text = substring(text, startIndex, textSize);

        switch (match(nfa, remainingstring, flags)) {
          case (#ok(matchResult)) {
            switch (matchResult.status) {
              case (#FullMatch) {
                let adjustedMatch = {
                  string = text;
                  value = matchResult.value;
                  status = #FullMatch;
                  position = (startIndex, startIndex + matchResult.position.1);
                  capturedGroups = matchResult.capturedGroups;
                  spans = matchResult.spans;
                  lastIndex = startIndex + matchResult.lastIndex
                };
                return #ok(adjustedMatch)
              };
              case (#NoMatch) {}
            }
          };
          case (#err(e)) {
            return #err(e)
          }
        };
        startIndex += 1
      };
      return #ok({
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
      regex := nfa;
      var startIndex = 0;
      let textSize = text.size();
      var matches = Buffer.Buffer<Match>(0);

      while (startIndex < textSize) {
        let remainingString : Text = substring(text, startIndex, textSize);
        switch (search(nfa, remainingString, flags)) {
          case (#ok(matchResult)) {
            switch (matchResult.status) {
              case (#FullMatch) {
                let adjustedMatch = {
                  string = text;
                  value = matchResult.value;
                  status = #FullMatch;
                  position = (startIndex, startIndex + matchResult.position.1);
                  capturedGroups = matchResult.capturedGroups;
                  spans = matchResult.spans;
                  lastIndex = startIndex + matchResult.lastIndex
                };
                matches.add(adjustedMatch);
                startIndex := adjustedMatch.lastIndex
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
    }
  }
}
