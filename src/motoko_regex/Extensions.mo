import Types "Types";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Char "mo:base/Char";
import Debug "mo:base/Debug";

module{
    public func maxChar(a: Char, b: Char) : Char {
    if (Char.toNat32(a) > Char.toNat32(b)) {
        a
    } else {
        b
    }
    };
    public func parseQuantifierRange(rangeStr: Text): (Nat, ?Nat) {
        let chars = Text.toIter(rangeStr);
        var min: Nat = 0;
        var max: ?Nat = null;
        var parsingMin = true;
        var currentNumber = "";
        var foundComma = false;

        label l for (char in chars) {
            switch (char) {
                case ',' {
                    if (foundComma) {
                        Debug.print("Invalid quantifier range: more than one comma");
                        return (0, null);
                    };
                    if (currentNumber != "") {
                        min := switch (Nat.fromText(currentNumber)) {
                            case (?n) n;
                            case null {
                                Debug.print("Invalid minimum in quantifier range: " # currentNumber);
                                return (0, null);
                            };
                        };
                        currentNumber := "";
                    } else {
                        Debug.print("Invalid quantifier range: comma without preceding number");
                        return (0, null);
                    };
                    parsingMin := false;
                    foundComma := true;
                    continue l;
                };
                case _ {
                    if (char >= '0' and char <= '9') {
                        currentNumber := currentNumber # Text.fromChar(char);
                    } else {
                        Debug.print("Invalid character in quantifier range: " # Text.fromChar(char));
                        return (0, null);
                    };
                };
            };
        };
        if (currentNumber != "") {
            if (parsingMin) {
                min := switch (Nat.fromText(currentNumber)) {
                    case (?n) n;
                    case null {
                        Debug.print("Invalid minimum in quantifier range: " # currentNumber);
                        return (0, null);
                    };
                };
            } else {
                max := switch (Nat.fromText(currentNumber)) {
                    case (?n) ?n;
                    case null {
                        Debug.print("Invalid maximum in quantifier range: " # currentNumber);
                        return (0, null);
                    };
                };
            };
        } else if (parsingMin) {
            Debug.print("Empty quantifier range: no values found");
            return (0, null);
        };
        switch (max) {
            case (null) {
                if (parsingMin) {
                    (min, ?min)  // Case: `{n}`
                } else {
                    (min, null)  // Case: `{n,}`
                };
            };
            case (?m) (min, ?m);  // Case: `{n,m}`
        };
    };

    public func metacharToRanges(metaType: Types.MetacharacterType) : [(Char, Char)] {
          switch metaType {
              case (#Digit) {
                  [ ('0', '9') ]
              };
              case (#NonDigit) {
                  // Match everything except digits (0-9)
                  [ (Char.fromNat32(0), '/'), (':', Char.fromNat32(255)) ]
              };
              case (#Whitespace) {
                  // Match whitespace (space, tab, newline, carriage return)
                  [ (' ', ' '), ('\t', '\t'), ('\n', '\n'), ('\r', '\r') ]
              };
              case (#NonWhitespace) {
                  // Match everything except whitespace characters
                  [ (Char.fromNat32(0), Char.fromNat32(8)), (Char.fromNat32(11), Char.fromNat32(12)), (Char.fromNat32(14), Char.fromNat32(255)) ]
              };
              case (#WordChar) {
                  [ ('a', 'z'), ('A', 'Z'), ('0', '9'), ('_', '_') ]
              };
              case (#NonWordChar) {
                  [ ('!', '/'), (':', '@'), ('[', '`'), ('{', '~') ]
              };
              case (#Dot) {
                  // Match any character except newline
                  [ (Char.fromNat32(0), Char.fromNat32(255)) ]
              };
          }
      };

    //finds character at given position 0 based indexing
    public func charAt(i : Nat, t : Text) : Char {
      let arr = Text.toArray(t);
      arr[i];
    };

    //slice a text 
    public func slice(text : Text, start : Nat, end : ?Nat) : Text {
      let chars = Text.toArray(text);
      let slicedChars = switch (end) {
        case null { Array.slice<Char>(chars, start, chars.size()) };
        case (?e) { Array.slice<Char>(chars, start, e) };
      };
      Text.fromIter(slicedChars);
    };
    public func arrayLast<T>(arr: [T]) : ?T {
      if (arr.size() == 0) {
        null
      } else {
        ?arr[arr.size() - 1]
      }
    };
    //slice an array of any type
    public func sliceArray<T>(arr: [T], start: Nat, end: Nat) : [T] {
    if (start >= arr.size() or end > arr.size() or start > end) {
        return [];
    };
    Array.tabulate<T>(end - start, func(i:Nat) { arr[start + i] })
    };
    //Error handling
    public func errorToText(error : Types.LexerError) : Text {
      switch (error) {
        case (#GenericError(text)) text;
        case (#InvalidEscapeSequence(char)) "Invalid escape sequence: " # Char.toText(char);
        case (#InvalidQuantifierRange(text)) "Invalid quantifier range: " # text;
        case (#MismatchedParenthesis(left, right)) "Mismatched parenthesis: " # Char.toText(left) # " and " # Char.toText(right);
        case (#UnexpectedCharacter(char)) "Unexpected character: " # Char.toText(char);
        case (#UnexpectedEndOfInput) "Unexpected end of input";
        case (#UnmatchedParenthesis(char)) "Unmatched parenthesis: " # Char.toText(char);
      };
    };
    //replace an element of a buffer given an index
    public func replace<T>(buffer: Buffer.Buffer<T>, index: Nat, newElement: T) {
    if (index >= buffer.size()) {
        Debug.trap("Index out of bounds");
    };
    ignore buffer.remove(index);  
    buffer.insert(index, newElement); 
  };

};
