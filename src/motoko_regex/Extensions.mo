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

    // Use a labeled loop for more control over flow
    label l for (char in chars) {
        switch (char) {
            case '{' { continue l; };  // Ignore the opening brace
            case '}' { break l; };     // Break when closing brace is found
            case ',' { 
                parsingMin := false;   // Switch from parsing min to max
                continue l;
            };
            case _ {
                // Try to convert character to a digit
                switch (Nat.fromText(Text.fromChar(char))) {
                    case (?digit) {
                        if (parsingMin) {
                            min := min * 10 + digit;  // Accumulate digits for min
                        } else {
                            max := switch (max) {
                                case (null) ?digit;     // Start max with the first digit
                                case (?m) ?(m * 10 + digit); // Accumulate digits for max
                            };
                        };
                    };
                    case (null) {
                        Debug.print("Invalid character in quantifier range: " # Text.fromChar(char));
                        return (0, null);  // Return (0, null) on invalid input
                    };
                };
            };
        };
    };

    // Return the parsed range
    switch (max) {
        case (null) (min, ?min);  // If no max is provided, min == max
        case (?m) (min, ?m);      // Return the parsed min and max
        }
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
