import Text "mo:base/Text";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Iter "mo:base/Iter";

module {
  public class Cursor(t : Text) {
    let string = Text.toArray(t);
    private var pos : Nat = 0;
    
    public func getPos() : Nat {
      pos
    };

    public func current() : Char {
        if (pos < string.size()) {
            string[pos]
        } else {
    Debug.trap("Attempted to access character out of bounds at position " # Nat.toText(pos));
        }
    };

    public func peek(offset : Nat) : Char {
      if (pos + offset < string.size()) {
        string[pos + offset]
      } else {
        Debug.trap("Attempted to access character out of bounds at position " # Nat.toText(pos));
      }
    };
    public func peekNext(): Char{
      if (pos + 1 < string.size()) {
        string[pos + 1]
      }else {
        Debug.trap("No more Tokens! Attempted to access character out of bounds at position " # Nat.toText(pos));
      }
    };

    public func hasNext() : Bool {
      pos < string.size()
    };

    public func inc() {
      if (pos < string.size()) {
        pos += 1;
      }
    };

    public func dec() {
      if (pos > 0) {
        pos -= 1;
      }
    };

    public func advance(n : Nat) {
      if (pos + n <= string.size()) {
        pos += n;
      } else {
        pos := string.size();
      }
    };

    public func reset() {
      pos := 0;
    };

    public func slice(start : Nat, end : ?Nat) : Text {
    let actualEnd = switch (end) {
        case (null) { string.size() };
        case (?e) { Nat.min(e, string.size()) };
    };
    if (start <= actualEnd) {
        let length = Int.abs(actualEnd - start);
        var result = "";
        for (i in Iter.range(0, length - 1)) {
        result := result # Text.fromChar(string[start + i]);
        };
        result
    } else {
        ""
    }
    };
  };
};