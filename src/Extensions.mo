import Types "Types";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Iter "mo:base/Iter";
import Char "mo:base/Char";
import Debug "mo:base/Debug";
import Order "mo:base/Order";

module {
  type State = Types.State;
  type Transition = Types.Transition;
  type AST = Types.AST;

  public func maxChar(a : Char, b : Char) : Char {
    if (Char.toNat32(a) > Char.toNat32(b)) {a} else {b}
  };

  public func charAt(i : Nat, t : Text) : Char {
    let arr = Text.toArray(t);
    arr[i]
  };

  public func slice(text : Text, start : Nat, end : ?Nat) : Text {
    let chars = Text.toArray(text);
    let slicedChars = switch (end) {
      case null {Array.slice<Char>(chars, start, chars.size())};
      case (?e) {Array.slice<Char>(chars, start, e)}
    };
    Text.fromIter(slicedChars)
  };

  public func compareChars(char1: Char, char2: Char, flags: ?Types.Flags) : Bool {
    switch (flags) {
      case (?f) {
        if (not f.caseSensitive) {
          Text.toLowercase(Text.fromChar(char1)) == Text.toLowercase(Text.fromChar(char2))
        } else {
          char1 == char2
        }
      };
      case null { char1 == char2 };
    };
  };

  public func isInRange(char: Char, start: Char, end: Char, flags: ?Types.Flags) : Bool {
    switch (flags) {
      case (?f) {
        if (not f.caseSensitive) {
          let lowerChar = Text.toLowercase(Text.fromChar(char));
          let lowerStart = Text.toLowercase(Text.fromChar(start));
          let lowerEnd = Text.toLowercase(Text.fromChar(end));
          lowerChar >= lowerStart and lowerChar <= lowerEnd
        } else {
          char >= start and char <= end
        }
      };
      case null { char >= start and char <= end };
    };
  };
  
  public func substring(text : Text, start : Nat, end : Nat) : Text {
    let chars = Text.toArray(text);
    assert (start <= end);
    assert (end <= chars.size());
    if (start == end) return "";
    Text.fromIter(Array.slice<Char>(chars, start, end))
  };

  public func textToNat(txt : Text) : Nat {
    assert (txt.size() > 0);
    let chars = txt.chars();
    var num : Nat = 0;
    for (v in chars) {
      let charToNum = Nat32.toNat(Char.toNat32(v) -48);
      assert (charToNum >= 0 and charToNum <= 9);
      num := num * 10 + charToNum
    };
    num
  };
  public func arrayLast<T>(arr : [T]) : ?T {
    if (arr.size() == 0) {null} else {?arr[arr.size() - 1]}
  };

  public func sliceArray<T>(arr : [T], start : Nat, end : Nat) : [T] {
    if (start >= arr.size() or end > arr.size() or start > end) {
      return []
    };
    Array.tabulate<T>(end - start, func(i : Nat) {arr[start + i]})
  };

  public func isReservedSymbol(char : Char) : Bool {
    switch char {
      case (
        '(' or ')' or '[' or ']' or '{' or '}' or
        '*' or '+' or '?' or '.' or '^' or '$' or
        '|' or '\\'
      ) {true};
      case _ {false}
    }
  };
  
  public func isValidEscapeSequence(char : Char, inClass : Bool) : Bool {
    if (inClass) {
      switch (char) {
        case (
          'd' or 'D' or 'w' or 'W' or 's' or 'S' or
          '[' or ']' or '^' or '-' or '\\'
        ) {true};
        case _ {false}
      }
    } else {
      switch (char) {
        case (
          'w' or 'W' or 'd' or 'D' or 's' or 'S' or
          'b' or 'B' or 'A' or 'z' or 'G' or
          '(' or ')' or '[' or ']' or '{' or '}' or
          '*' or '+' or '?' or '.' or '^' or '$' or
          '|' or '\\'
        ) {true};
        case _ {false}
      }
    }
  };
  public func parseQuantifierRange(rangeStr : Text) : (Nat, ?Nat) {
    let chars = Text.toIter(rangeStr);
    var min : Nat = 0;
    var max : ?Nat = null;
    var parsingMin = true;
    var currentNumber = "";
    var foundComma = false;

    label l for (char in chars) {
      switch (char) {
        case ',' {
          if (foundComma) {
            Debug.print("Invalid quantifier range: more than one comma");
            return (0, null)
          };
          if (currentNumber != "") {
            min := switch (Nat.fromText(currentNumber)) {
              case (?n) n;
              case null {
                Debug.trap("Invalid minimum in quantifier range: " # currentNumber);
                return (0, null)
              }
            };
            currentNumber := ""
          } else {
            Debug.trap("Invalid quantifier range: comma without preceding number");
            return (0, null)
          };
          parsingMin := false;
          foundComma := true;
          continue l
        };
        case _ {
          if (char >= '0' and char <= '9') {
            currentNumber := currentNumber # Text.fromChar(char)
          } else {
            Debug.trap("Invalid character in quantifier range: " # Text.fromChar(char));
            return (0, null)
          }
        }
      }
    };
    if (currentNumber != "") {
      if (parsingMin) {
        min := switch (Nat.fromText(currentNumber)) {
          case (?n) n;
          case null {
            Debug.trap("Invalid minimum in quantifier range: " # currentNumber);
            return (0, null)
          }
        }
      } else {
        max := switch (Nat.fromText(currentNumber)) {
          case (?n) ?n;
          case null {
            Debug.trap("Invalid maximum in quantifier range: " # currentNumber);
            return (0, null)
          }
        }
      }
    } else if (parsingMin) {
      Debug.trap("Empty quantifier range: no values found");
      return (0, null)
    };
    switch (max) {
      case (null) {
        if (parsingMin) {
          (min, ?min) // Case: `{n}`
        } else {
          (min, null) // Case: `{n,}`
        }
      };
      case (?m) (min, ?m); // Case: `{n,m}`
    }
  };

  public func metacharToRanges(metaType : Types.MetacharacterType) : [(Char, Char)] {
    switch metaType {
      case (#Digit) {[('0', '9')]};
      case (#NonDigit) {
        // Match everything except digits (0-9)
        [(Char.fromNat32(0), '/'), (':', Char.fromNat32(255))]
      };
      case (#Whitespace) {
        // Match whitespace (space, tab, newline, carriage return)
        [(' ', ' '), ('\t', '\t'), ('\n', '\n'), ('\r', '\r')]
      };
      case (#NonWhitespace) {
        // Match everything except whitespace characters
        [(Char.fromNat32(0), Char.fromNat32(8)), (Char.fromNat32(11), Char.fromNat32(12)), (Char.fromNat32(14), Char.fromNat32(255))]
      };
      case (#WordChar) {[('a', 'z'), ('A', 'Z'), ('0', '9'), ('_', '_')]};
      case (#NonWordChar) {[('!', '/'), (':', '@'), ('[', '`'), ('{', '~')]};
      case (#Dot) {
        // Match any character except newline
        [(Char.fromNat32(0), Char.fromNat32(255))]
      }
    }
  };
  public func computeClassRanges(nodes : [AST], isNegated : Bool) : [(Char, Char)] {
    let ranges = Buffer.Buffer<(Char, Char)>(16);
    for (node in nodes.vals()) {
      switch (node) {
        case (#Character(c)) {
          ranges.add((c, c))
        };
        case (#Range(start, end)) {
          ranges.add((start, end))
        };
        case (#Metacharacter(m)) {
          let metaRanges = metacharToRanges(m);
          for (range in metaRanges.vals()) {
            ranges.add(range)
          }
        };
        case _ {}
      }
    };
    let sortedRanges = Array.sort<(Char, Char)>(
      Buffer.toArray(ranges),
      func(a : (Char, Char), b : (Char, Char)) : Order.Order {
        Nat32.compare(Char.toNat32(a.0), Char.toNat32(b.0))
      }
    );

    // Merge overlapping ranges
    let mergedRanges = Buffer.Buffer<(Char, Char)>(sortedRanges.size());
    if (sortedRanges.size() > 0) {
      var current = sortedRanges[0];
      for (i in Iter.range(1, sortedRanges.size() - 1)) {
        let next = sortedRanges[i];
        if (Char.toNat32(current.1) + 1 >= Char.toNat32(next.0)) {
          // Ranges overlap or are adjacent, merge them
          current := (
            current.0,
            if (Char.toNat32(current.1) > Char.toNat32(next.1)) current.1 else next.1
          )
        } else {
          // No overlap, add current range and start new one
          mergedRanges.add(current);
          current := next
        }
      };
      mergedRanges.add(current)
    };

    if (not isNegated) {
      Buffer.toArray(mergedRanges)
    } else {
      // Compute complement ranges
      let complementRanges = Buffer.Buffer<(Char, Char)>(mergedRanges.size() + 1);
      let mergedArray = Buffer.toArray(mergedRanges);

      if (mergedArray.size() > 0) {
        let firstStart = Char.toNat32(mergedArray[0].0);
        if (firstStart > 0) {
          complementRanges.add((
            Char.fromNat32(0),
            Char.fromNat32(firstStart - 1)
          ))
        };

        // Add ranges between merged ranges
        for (i in Iter.range(0, mergedArray.size() - 2)) {
          let currentEnd = Char.toNat32(mergedArray[i].1);
          let nextStart = Char.toNat32(mergedArray[i + 1].0);
          if (currentEnd + 1 < nextStart) {
            complementRanges.add((
              Char.fromNat32(currentEnd + 1),
              Char.fromNat32(nextStart - 1)
            ))
          }
        };

        // Add range from last range end to max Unicode if needed
        let lastEnd = Char.toNat32(mergedArray[mergedArray.size() - 1].1);
        if (lastEnd < 255) {
          complementRanges.add((
            Char.fromNat32(lastEnd + 1),
            Char.fromNat32(255)
          ))
        }
      } else {
        complementRanges.add((
          Char.fromNat32(0),
          Char.fromNat32(255)
        ))
      };

      Buffer.toArray(complementRanges)
    }
  };
  public func getMaxState(transitions : [Transition], acceptStates : [State], startState : State) : State {
    var maxState = startState;
    for ((from, _, to, _) in transitions.vals()) {
      if (from > maxState) maxState := from;
      if (to > maxState) maxState := to
    };
    for (state in acceptStates.vals()) {
      if (state > maxState) maxState := state
    };
    maxState
  };
  public func containsState(array : [Nat], state : Nat) : Bool {
    for (item in array.vals()) {
      if (item == state) {
        return true
      }
    };
    false
  };

  public func flattenAST(ast : Types.ASTNode) : [Types.ASTNode] {
    switch (ast) {
      case (#Concatenation(exprs)) {
        var result = [] : [Types.ASTNode];
        for (expr in exprs.vals()) {
          result := Array.append<Types.ASTNode>(result, flattenAST(expr))
        };
        result
      };
      case _ {[ast]}
    }
  };
    public func compareTransitions(a : Transition, b : Transition) : Order.Order {
    switch (a.1, b.1) {
        case (#Char(_), #Range(_)) #less;
        case (#Range(_), #Char(_)) #greater;
        case (#Char(charA), #Char(charB)) {
            if (charA < charB) #less
            else if (charA > charB) #greater
            else {
                let modeA = switch (a.3) {case (?m) m; case null #Greedy};
                let modeB = switch (b.3) {case (?m) m; case null #Greedy};
                switch (modeA, modeB) {
                    case (#Lazy, #Greedy) #less;
                    case (#Greedy, #Lazy) #greater;
                    case _ #equal
                }
            }
        };
        case (#Range((startA, endA)), #Range((startB, endB))) {
            if (startA < startB) #less
            else if (startA > startB) #greater
            else if (endA < endB) #less
            else if (endA > endB) #greater
            else {
                let modeA = switch (a.3) {case (?m) m; case null #Greedy};
                let modeB = switch (b.3) {case (?m) m; case null #Greedy};
                switch (modeA, modeB) {
                    case (#Lazy, #Greedy) #less;
                    case (#Greedy, #Lazy) #greater;
                    case _ #equal
                }
            }
        };
    }
};

    public func sortTransitionsInPlace(transitions : [var Transition]) {
      Array.sortInPlace<Transition>(
        transitions,
        func(a : Transition, b : Transition) {
          compareTransitions(a, b)
        }
      )
    };
}