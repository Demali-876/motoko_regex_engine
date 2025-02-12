import Types "Types";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Debug "mo:base/Debug";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import { substring; charAt; containsState; compareChars; isInRange } "Extensions";
import Extensions "Extensions";

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
      text : ?Text;
    };

    private var mode : Bool = false;

    private func log(msg : Text) {
      if (mode) {
        Debug.print(msg);
      };
    };

    public func debugMode(bool : Bool) {
      mode := bool;
    };
    public func inspect(x : State, nfa : NFA) : Result.Result<[Types.Transition], MatchError> {
      if (containsState(nfa.states, x)) {
        return #ok(nfa.transitionTable[x]);
      } else {
        return #err(#InvalidTransition("State " # Nat.toText(x) # " is not in the NFA"));
      };
    };
    private func createMatch(text : Text, startIndex : Nat, index : Nat, captures : Buffer.Buffer<Capture>) : Result.Result<Match, MatchError> {
      var finalCaptures = Buffer.Buffer<(Text, Nat)>(0);
      for (cap in captures.vals()) {
        switch (cap.text) {
          case (?txt) { finalCaptures.add(txt, cap.groupIndex) };
          case null {};
        };
      };
      #ok({
        string = text;
        value = substring(text, startIndex, index);
        status = #FullMatch;
        position = (startIndex, index);
        capturedGroups = ?Buffer.toArray<(Text, Nat)>(finalCaptures);
        spans = [(startIndex, index)];
        lastIndex = index;
      });
    };

    public func match(nfa : NFA, text : Text, flags : ?Flags) : Result.Result<Match, MatchError> {
      var currentState = nfa.startState;
      var index = 0;
      var captures = Buffer.Buffer<Capture>(0);

      log("[match] Starting match on text = '" # text # "', length = " # debug_show (text.size()));

      for (assertion in nfa.assertions.vals()) {
        switch (assertion.assertion) {
          case (#Group(group)) {
            captures.add({
              groupIndex = group.captureIndex;
              startIndex = null;
              endIndex = null;
              text = null;
            });
            log("[match] Initialized capture group " # debug_show (group.captureIndex));
          };
          case _ {};
        };
      };

      func handleGroupTransitions(state : State, isStart : Bool) {
        for (assertion in nfa.assertions.vals()) {
          switch (assertion.assertion) {
            case (#Group(group)) {
              if (isStart and group.startState == state) {
                let cap = captures.get(group.captureIndex - 1);
                captures.put(group.captureIndex - 1, { cap with startIndex = ?index });
                log("[match] Starting capture group " # debug_show (group.captureIndex) # " at index " # debug_show (index));
              } else if (not isStart and containsState(group.endStates, state)) {
                let cap = captures.get(group.captureIndex - 1);
                switch (cap.startIndex) {
                  case (?startIdx) {
                    let capturedText = substring(text, startIdx, index);
                    captures.put(group.captureIndex - 1, { cap with endIndex = ?index; text = ?capturedText });
                    log(
                      "[match] Ending capture group " # debug_show (group.captureIndex)
                      # " at index " # debug_show (index) # " with text: '" # capturedText # "'"
                    );
                  };
                  case null {
                    log(
                      "[match] Warning: Attempted to end group "
                      # debug_show (group.captureIndex) # " without start index"
                    );
                  };
                };
              };
            };
            case _ {};
          };
        };
      };

      func checkBackreference(captureIndex : Nat) : Bool {
        let cap = captures.get(captureIndex - 1);
        switch (cap.text) {
          case (?capturedText) {
            let requestedEnd = index + capturedText.size();
            if (requestedEnd > text.size()) {
              log("[match] Backreference check failed: would read beyond end of text");
              return false;
            };
            let slicedText = substring(text, index, requestedEnd);
            log(
              "[match] Checking backreference group "
              # debug_show (captureIndex)
              # ": expected='" # capturedText # "', found='" # slicedText
              # "' at current index = " # debug_show (index)
            );
            if (slicedText != capturedText) {
              log("[match] Backreference mismatch");
              return false;
            };
            index += capturedText.size();
            return true;
          };
          case null {
            log(
              "[match] Backreference group " # debug_show (captureIndex)
              # " skipped: no captured text yet"
            );
            return false;
          };
        };
      };

      func checkAssertions() : Bool {
        let absPos = index;
        let totalSize = text.size();

        for (assertion in nfa.assertions.vals()) {
          switch (assertion.assertion) {
            case (#Backreference({ captureIndex })) {
              log("[match] Checking backreference to group " # debug_show (captureIndex));
              if (not checkBackreference(captureIndex)) {
                log("[match] Backreference assertion failed");
                return false;
              };
            };
            case (#Lookaround(la)) {
              log(
                "[match] Checking lookaround, isAhead=" # debug_show (la.isAhead)
                # ", isPositive=" # debug_show (la.isPositive)
                # ", length=" # debug_show (la.length)
              );
              if (la.isAhead) {
                switch (la.length) {
                  case (?len) {
                    if (absPos + len > totalSize) {
                      log("[match] Not enough text ahead for positive lookahead");
                      return not la.isPositive;
                    };
                    let lookaheadText = substring(text, absPos, absPos + len);
                    log("[match] Lookahead text = '" # lookaheadText # "'");
                    let succeeded = runSubNFA(la, lookaheadText, flags);
                    if (succeeded != la.isPositive) {
                      log("[match] Lookahead assertion failed");
                      return false;
                    };
                  };
                  case null {
                    let lookaheadText = substring(text, absPos, totalSize);
                    log("[match] Unbounded lookahead text = '" # lookaheadText # "'");
                    let succeeded = runSubNFA(la, lookaheadText, flags);
                    if (succeeded != la.isPositive) {
                      log("[match] Lookahead assertion failed");
                      return false;
                    };
                  };
                };
              } else {
                switch (la.length) {
                  case (?len) {
                    if (absPos < len) {
                      log("[match] Not enough text behind for positive lookbehind");
                      return not la.isPositive;
                    };
                    let behindStart : Nat = absPos - len;
                    let lookbehindText = substring(text, behindStart, absPos);
                    log("[match] Lookbehind text = '" # lookbehindText # "'");
                    let succeeded = runSubNFA(la, lookbehindText, flags);
                    if (succeeded != la.isPositive) {
                      log("[match] Lookbehind assertion failed");
                      return false;
                    };
                  };
                  case null {
                    log("[match] Variable-length lookbehind not supported");
                    return false;
                  };
                };
              };
            };
            case (#Anchor({ aType; position })) {
              switch (aType) {
                case (#StartOfString or #StartOfStringOnly) {
                  let startOfLine : Nat = if (Extensions.isMultiline(flags) and aType == #StartOfString) {
                    // TODO
                    // Start of the line
                    Debug.trap("Multiline with ^ is not supported yet");
                  } else 0; // Otherwise, it's the start of the string
                  if (position != startOfLine) {
                    log("[match] Start of string anchor assertion failed. Expected position " #Nat.toText(startOfLine) # ", got " # Nat.toText(position));
                    return false;
                  };
                };
                case (#EndOfString or #EndOfStringOnly) {
                  let endOfLine : Nat = if (Extensions.isMultiline(flags) and aType == #EndOfString) {
                    // TODO
                    // End of the line
                    Debug.trap("Multiline with $ is not supported yet");
                  } else totalSize; // Otherwise, it's the end of the string
                  if (position != endOfLine) {
                    log("[match] End anchor assertion failed. Expected position " # Nat.toText(endOfLine) # ", got " # Nat.toText(position));
                    return false;
                  };
                };
                case _ {};
              };
            };
            case _ {};
          };
        };
        return true;
      };

      func runSubNFA(
        la : {
          startState : State;
          states : [State];
          transitionTable : [[Types.Transition]];
          acceptStates : [State];
          isPositive : Bool;
          isAhead : Bool;
          position : State;
          length : ?Nat;
        },
        textChunk : Text,
        flags : ?Flags,
      ) : Bool {
        var currentState = la.startState;
        var i = 0;
        label traverse while (i < textChunk.size()) {
          let char = charAt(i, textChunk);
          let transitions = la.transitionTable[currentState];
          var foundTransition = false;

          label transitionsLoop for (transition in transitions.vals()) {
            if (transition.0 == currentState) {
              switch (transition.1) {
                case (#Char(c)) {
                  if (compareChars(char, c, flags)) {
                    currentState := transition.2;
                    foundTransition := true;
                    i += 1;
                    break transitionsLoop;
                  };
                };
                case (#Range((start, end))) {
                  if (isInRange(char, start, end, flags)) {
                    currentState := transition.2;
                    foundTransition := true;
                    i += 1;
                    break transitionsLoop;
                  };
                };
              };
            };
          };
          if (not foundTransition) {
            log(
              "[match] runSubNFA failed at local index " # debug_show (i)
              # ", currentState=" # debug_show (currentState)
            );
            return false;
          };
        };
        let accepted = containsState(la.acceptStates, currentState);
        log(
          "[match] runSubNFA ended with currentState="
          # debug_show (currentState)
          # ", accepted=" # debug_show (accepted)
        );
        return accepted;
      };

      log("[match] Entering main matching loop...");

      label matching while (index < text.size()) {
        let char = charAt(index, text);
        let possibleTransitions = nfa.transitionTable[currentState];
        var matched = false;
        var nextState = currentState;

        log(
          "[match] At index=" # debug_show (index)
          # ", currentState=" # debug_show (currentState)
          # ", char='" # Text.fromChar(char) # "'"
        );

        handleGroupTransitions(currentState, true);

        label charTransitions for (t in possibleTransitions.vals()) {
          if (t.0 == currentState) {
            switch (t.1) {
              case (#Char(c)) {
                if (compareChars(char, c, flags)) {
                  matched := true;
                  nextState := t.2;
                  log(
                    "[match] Transition on exact char '" # Text.fromChar(c)
                    # "' -> nextState=" # debug_show (t.2)
                  );
                  break charTransitions;
                };
              };
              case (#Range((start, end))) {
                if (isInRange(char, start, end, flags)) {
                  matched := true;
                  nextState := t.2;
                  log(
                    "[match] Transition on range ["
                    # debug_show (start) # "-" # debug_show (end)
                    # "] -> nextState=" # debug_show (t.2)
                  );
                  break charTransitions;
                };
              };
            };
          };
        };

        if (matched) {
          currentState := nextState;
          index += 1;
          handleGroupTransitions(currentState, false);

          if (containsState(nfa.acceptStates, currentState)) {
            log(
              "[match] Reached accept state=" # debug_show (currentState)
              # ", checking assertions..."
            );
            if (not checkAssertions()) {
              log(
                "[match] Assertion check failed at accept state="
                # debug_show (currentState) # ", aborting"
              );
              return #ok({
                string = text;
                value = "";
                status = #NoMatch;
                position = (0, 0);
                capturedGroups = null;
                spans = [];
                lastIndex = index;
              });
            };
          };
        } else {
          log(
            "[match] No valid transition from state="
            # debug_show (currentState)
            # " with char='" # Text.fromChar(char) # "' at index="
            # debug_show (index) # ", breaking out"
          );
          break matching;
        };
      };

      if (containsState(nfa.acceptStates, currentState)) {
        log(
          "[match] Finished loop in accept state=" # debug_show (currentState)
          # ", creating final match"
        );
        return createMatch(text, 0, index, captures);
      };

      log("[match] No match found, returning #NoMatch");
      #ok({
        string = text;
        value = "";
        status = #NoMatch;
        position = (0, 0);
        capturedGroups = null;
        spans = [];
        lastIndex = index;
      });
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
                validStart := true;
              };
            };
            case (#Range((start, end))) {
              if (isInRange(char, start, end, flags)) {
                validStart := true;
              };
            };
          };
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
                    lastIndex = startIndex + matchResult.lastIndex;
                  });
                };
                case (#NoMatch) {};
              };
            };
            case (#err(e)) return #err(e);
          };
        };
        startIndex += 1;
      };

      #ok({
        string = text;
        value = "";
        status = #NoMatch;
        position = (0, 0);
        capturedGroups = null;
        spans = [];
        lastIndex = 0;
      });
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
                  lastIndex = startIndex + matchResult.lastIndex;
                };
                matches.add(adjustedMatch);
                startIndex := adjustedMatch.position.1;
              };
              case (#NoMatch) {
                startIndex += 1;
              };
            };
          };
          case (#err(e)) {
            return #err(e);
          };
        };
      };
      return #ok(Buffer.toArray(matches));
    };

    public func findIter(nfa : NFA, text : Text, flags : ?Flags) : Result.Result<Iter.Iter<Match>, MatchError> {
      switch (findAll(nfa, text, flags)) {
        case (#ok(matches)) {
          let matchIter : Iter.Iter<Match> = Iter.fromArray(matches);
          return #ok(matchIter);
        };
        case (#err(e)) {
          return #err(e);
        };
      };
    };
    public func split(nfa : NFA, text : Text, maxSplit : ?Nat, flags : ?Flags) : Result.Result<[Text], MatchError> {
      let splitLimit = switch (maxSplit) {
        case (null) 0;
        case (?val) val;
      };

      if (text.size() == 0) {
        return #err(#EmptyExpression("Empty expression"));
      };

      switch (findAll(nfa, text, flags)) {
        case (#err(e)) #err(e);
        case (#ok(delimiterMatches)) {
          let results = Buffer.Buffer<Text>(delimiterMatches.size());
          var lastIndex = 0;
          var splitCount = 0;

          label splitting for (delimMatch in delimiterMatches.vals()) {
            if (splitLimit > 0 and splitCount >= splitLimit) {
              break splitting;
            };
            if (delimMatch.position.0 == delimMatch.position.1 and delimMatch.position.0 == 0) {
              continue splitting;
            };
            if (lastIndex < delimMatch.position.0) {
              results.add(substring(text, lastIndex, delimMatch.position.0));
            };
            switch (delimMatch.capturedGroups) {
              case (?groups) {
                if (groups.size() > 0) {
                  results.add(delimMatch.value);
                };
              };
              case (null) {};
            };

            lastIndex := delimMatch.position.1;
            splitCount += 1;
          };
          if (lastIndex < text.size()) {
            results.add(substring(text, lastIndex, text.size()));
          };

          #ok(Buffer.toArray(results));
        };
      };
    };
    public func replace(nfa : NFA, text : Text, replacement : Text, maxReplace : ?Nat, flags : ?Flags) : Result.Result<Text, MatchError> {
      if (
        Text.contains(replacement, #char '\\') or Text.contains(replacement, #char '*') or Text.contains(replacement, #char '+') or
        Text.contains(replacement, #char '?') or Text.contains(replacement, #char '.') or Text.contains(replacement, #char '^') or
        Text.contains(replacement, #char '$') or Text.contains(replacement, #char '[') or Text.contains(replacement, #char ']') or
        Text.contains(replacement, #char '(') or Text.contains(replacement, #char ')')
      ) {
        return #err(#GenericError("Replacement must be a string literal it cannot contain reserved regex symbols, use sub() instead"));
      };

      let replaceLimit = switch (maxReplace) {
        case (null) 0;
        case (?val) val;
      };
      if (text.size() == 0) {
        return #err(#EmptyExpression("Empty expression"));
      };
      switch (findAll(nfa, text, flags)) {
        case (#err(e)) #err(e);
        case (#ok(matches)) {
          let result = Buffer.Buffer<Text>(text.size());
          var lastIndex = 0;
          var replaceCount = 0;

          label replacing for (match in matches.vals()) {
            if (replaceLimit > 0 and replaceCount >= replaceLimit) {
              break replacing;
            };
            if (lastIndex < match.position.0) {
              result.add(substring(text, lastIndex, match.position.0));
            };
            let processedReplacement = switch (match.capturedGroups) {
              case (?groups) {
                var repText = replacement;
                for ((text, index) in groups.vals()) {
                  let groupRef = "\\" # Nat.toText(index);
                  repText := Text.replace(repText, #text groupRef, text);
                };
                repText;
              };
              case (null) replacement;
            };
            result.add(processedReplacement);
            lastIndex := match.position.1;
            replaceCount += 1;
          };
          if (lastIndex < text.size()) {
            result.add(substring(text, lastIndex, text.size()));
          };

          #ok(Text.join("", result.vals()));
        };
      };
    };
    public func sub(nfa : NFA, text : Text, replacement : Text, maxReplace : ?Nat, flags : ?Flags) : Result.Result<Text, MatchError> {
      if (text.size() == 0) {
        return #err(#EmptyExpression("Empty expression"));
      };

      switch (findAll(nfa, text, flags)) {
        case (#err(e)) #err(e);
        case (#ok(matches)) {
          let result = Buffer.Buffer<Text>(text.size());
          var lastIndex = 0;
          var replaceCount = 0;

          let replaceLimit = switch (maxReplace) {
            case (null) 0;
            case (?val) val;
          };

          label replacing for (match in matches.vals()) {
            if (replaceLimit > 0 and replaceCount >= replaceLimit) {
              break replacing;
            };

            if (lastIndex < match.position.0) {
              result.add(substring(text, lastIndex, match.position.0));
            };

            let processedReplacement = switch (match.capturedGroups) {
              case (?groups) {
                var repText = replacement;
                for ((text, index) in groups.vals()) {
                  let groupRef = "\\" # Nat.toText(index);
                  repText := Text.replace(repText, #text groupRef, text);
                };
                repText;
              };
              case (null) replacement;
            };

            result.add(processedReplacement);
            lastIndex := match.position.1;
            replaceCount += 1;
          };

          if (lastIndex < text.size()) {
            result.add(substring(text, lastIndex, text.size()));
          };

          #ok(Text.join("", result.vals()));
        };
      };
    };
  };
};
