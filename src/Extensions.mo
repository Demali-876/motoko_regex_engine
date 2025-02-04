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
import Result "mo:base/Result";

module {
  type State = Types.State;
  type Transition = Types.Transition;
  type AST = Types.AST;

  public func maxChar(a : Char, b : Char) : Char {
    if (Char.toNat32(a) > Char.toNat32(b)) { a } else { b };
  };

  public func charAt(i : Nat, t : Text) : Char {
    let arr = Text.toArray(t);
    arr[i];
  };

  public func slice(text : Text, start : Nat, end : ?Nat) : Text {
    let chars = Text.toArray(text);
    let slicedChars = switch (end) {
      case null { Array.slice<Char>(chars, start, chars.size()) };
      case (?e) { Array.slice<Char>(chars, start, e) };
    };
    Text.fromIter(slicedChars);
  };

  public func compareChars(char1 : Char, char2 : Char, flags : ?Types.Flags) : Bool {
    switch (flags) {
      case (?f) {
        if (not f.caseSensitive) {
          Text.toLowercase(Text.fromChar(char1)) == Text.toLowercase(Text.fromChar(char2));
        } else {
          char1 == char2;
        };
      };
      case null { char1 == char2 };
    };
  };

  public func isInRange(char : Char, start : Char, end : Char, flags : ?Types.Flags) : Bool {
    switch (flags) {
      case (?f) {
        if (not f.caseSensitive) {
          let lowerChar = Text.toLowercase(Text.fromChar(char));
          let lowerStart = Text.toLowercase(Text.fromChar(start));
          let lowerEnd = Text.toLowercase(Text.fromChar(end));
          lowerChar >= lowerStart and lowerChar <= lowerEnd;
        } else {
          char >= start and char <= end
        };
      };
      case null { char >= start and char <= end };
    };
  };

  public func substring(text : Text, start : Nat, end : Nat) : Text {
    let chars = Text.toArray(text);
    assert (start <= end);
    assert (end <= chars.size());
    if (start == end) return "";
    Text.fromIter(Array.slice<Char>(chars, start, end));
  };

  public func textToNat(txt : Text) : Nat {
    assert (txt.size() > 0);
    let chars = txt.chars();
    var num : Nat = 0;
    for (v in chars) {
      let charToNum = Nat32.toNat(Char.toNat32(v) -48);
      assert (charToNum >= 0 and charToNum <= 9);
      num := num * 10 + charToNum;
    };
    num;
  };
  public func arrayLast<T>(arr : [T]) : ?T {
    if (arr.size() == 0) { null } else { ?arr[arr.size() - 1] };
  };

  public func sliceArray<T>(arr : [T], start : Nat, end : Nat) : [T] {
    if (start >= arr.size() or end > arr.size() or start > end) {
      return [];
    };
    Array.tabulate<T>(end - start, func(i : Nat) { arr[start + i] });
  };

  public func isReservedSymbol(char : Char) : Bool {
    switch char {
      case (
        '(' or ')' or '[' or ']' or '{' or '}' or
        '*' or '+' or '?' or '.' or '^' or '$' or
        '|' or '\\'
      ) { true };
      case _ { false };
    };
  };

  public func isValidEscapeSequence(char : Char, inClass : Bool) : Bool {
    if (inClass) {
      switch (char) {
        case (
          'd' or 'D' or 'w' or 'W' or 's' or 'S' or
          '[' or ']' or '^' or '-' or '\\'
        ) { true };
        case _ { false };
      };
    } else {
      switch (char) {
        case (
          'w' or 'W' or 'd' or 'D' or 's' or 'S' or
          'b' or 'B' or 'A' or 'z' or 'G' or
          '(' or ')' or '[' or ']' or '{' or '}' or
          '*' or '+' or '?' or '.' or '^' or '$' or
          '|' or '\\' or 'p' or 'P' or 'k'
        ) { true };
        case _ { false };
      };
    };
  };
  public func isValidUnicodeProperty(property : Text) : Bool {
    let supportedProperties = [
      "L",
      "Ll",
      "Lu",
      "N",
      "P",
      "Zs",
      "Emoji",
    ];
    Array.find<Text>(supportedProperties, func(p : Text) { p == property }) != null;
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
            return (0, null);
          };
          if (currentNumber != "") {
            min := switch (Nat.fromText(currentNumber)) {
              case (?n) n;
              case null {
                Debug.trap("Invalid minimum in quantifier range: " # currentNumber);
                return (0, null);
              };
            };
            currentNumber := "";
          } else {
            Debug.trap("Invalid quantifier range: comma without preceding number");
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
            Debug.trap("Invalid character in quantifier range: " # Text.fromChar(char));
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
            Debug.trap("Invalid minimum in quantifier range: " # currentNumber);
            return (0, null);
          };
        };
      } else {
        max := switch (Nat.fromText(currentNumber)) {
          case (?n) ?n;
          case null {
            Debug.trap("Invalid maximum in quantifier range: " # currentNumber);
            return (0, null);
          };
        };
      };
    } else if (parsingMin) {
      Debug.trap("Empty quantifier range: no values found");
      return (0, null);
    };
    switch (max) {
      case (null) {
        if (parsingMin) {
          (min, ?min) // Case: `{n}`
        } else {
          (min, null) // Case: `{n,}`
        };
      };
      case (?m) (min, ?m); // Case: `{n,m}`
    };
  };

  public func metacharToRanges(metaType : Types.MetacharacterType) : [(Char, Char)] {
    switch metaType {
      case (#Digit) { [('0', '9')] };

      case (#NonDigit) {
        [(Char.fromNat32(0), '/'), (':', Char.fromNat32(0x10FFFF))];
      };

      case (#Whitespace) {
        [
          (' ', ' '),
          ('\t', '\t'),
          ('\n', '\n'),
          ('\r', '\r'),
          (Char.fromNat32(0x00A0), Char.fromNat32(0x00A0)),
          (Char.fromNat32(0x1680), Char.fromNat32(0x1680)),
          (Char.fromNat32(0x2000), Char.fromNat32(0x200A)),
          (Char.fromNat32(0x202F), Char.fromNat32(0x202F)),
          (Char.fromNat32(0x205F), Char.fromNat32(0x205F)),
          (Char.fromNat32(0x3000), Char.fromNat32(0x3000)),
        ];
      };

      case (#NonWhitespace) {
        [
          (Char.fromNat32(0), Char.fromNat32(0x09)),
          (Char.fromNat32(0x0B), Char.fromNat32(0x0C)),
          (Char.fromNat32(0x0E), Char.fromNat32(0x167F)),
          (Char.fromNat32(0x1681), Char.fromNat32(0x1FFF)),
          (Char.fromNat32(0x200B), Char.fromNat32(0x202E)),
          (Char.fromNat32(0x2030), Char.fromNat32(0x205E)),
          (Char.fromNat32(0x2060), Char.fromNat32(0x2FFF)),
          (Char.fromNat32(0x3010), Char.fromNat32(0x10FFFF)),
        ];
      };

      case (#WordChar) {
        [
          (Char.fromNat32(0x0030), Char.fromNat32(0x0039)),
          (Char.fromNat32(0x0041), Char.fromNat32(0x005A)),
          (Char.fromNat32(0x0061), Char.fromNat32(0x007A)),
          ('_', '_'),
          (Char.fromNat32(0x00C0), Char.fromNat32(0x00D6)),
          (Char.fromNat32(0x00D8), Char.fromNat32(0x00F6)),
          (Char.fromNat32(0x00F8), Char.fromNat32(0x02AF)),
          (Char.fromNat32(0x0370), Char.fromNat32(0x1FFF)),
          (Char.fromNat32(0x2C00), Char.fromNat32(0xD7FF)),
          (Char.fromNat32(0xF900), Char.fromNat32(0xFFFD)),
        ];
      };

      case (#NonWordChar) {
        [
          (Char.fromNat32(0), Char.fromNat32(0x002F)),
          (Char.fromNat32(0x003A), Char.fromNat32(0x0040)),
          (Char.fromNat32(0x005B), Char.fromNat32(0x0060)),
          (Char.fromNat32(0x007B), Char.fromNat32(0x00BF)),
          (Char.fromNat32(0x02B0), Char.fromNat32(0x036F)),
          (Char.fromNat32(0x2000), Char.fromNat32(0x2BFF)),
          (Char.fromNat32(0x3000), Char.fromNat32(0x10FFFF)),
        ];
      };

      case (#Dot) { [(Char.fromNat32(0), Char.fromNat32(0x10FFFF))] };
      case (#UnicodeProperty(negated, property)) {
        let ranges = switch property {
          case "L" {
            [('A', 'Z'), ('a', 'z'), (Char.fromNat32(0x00C0), Char.fromNat32(0x02AF))];
          };
          case "Ll" {
            [('a', 'z'), (Char.fromNat32(0x00DF), Char.fromNat32(0x00F6))];
          };
          case "Lu" {
            [('A', 'Z'), (Char.fromNat32(0x00C0), Char.fromNat32(0x00D6))];
          };
          case "N" {
            [('0', '9'), (Char.fromNat32(0x0660), Char.fromNat32(0x0669))];
          };
          case "P" { [('!', '/'), (':', '@'), ('[', '`'), ('{', '~')] };
          case "Zs" {
            [(' ', ' '), (Char.fromNat32(0x00A0), Char.fromNat32(0x00A0))];
          };
          case "Emoji" { [(Char.fromNat32(0x1F600), Char.fromNat32(0x1F64F))] };
          case _ { [] };
        };
        if (negated) {
          return subtractRanges(ranges);
        } else {
          return ranges;
        };
      };
    };
  };
  public func subtractRanges(remove : [(Char, Char)]) : [(Char, Char)] {
    let maxCode : Nat32 = 0x10FFFF;
    let result = Buffer.Buffer<(Char, Char)>(16);
    var last : Nat32 = 0;

    for (range in remove.vals()) {
      let rStart = Char.toNat32(range.0);
      let rEnd = Char.toNat32(range.1);
      if (last < rStart) {
        result.add((Char.fromNat32(last), Char.fromNat32(rStart - 1)));
      };
      last := rEnd + 1;
    };

    if (last <= maxCode) {
      result.add((Char.fromNat32(last), Char.fromNat32(maxCode)));
    };

    return Buffer.toArray(result);
  };

  public func computeClassRanges(nodes : [AST], isNegated : Bool) : [(Char, Char)] {
    let ranges = Buffer.Buffer<(Char, Char)>(16);
    for (node in nodes.vals()) {
      switch (node) {
        case (#Character(c)) {
          ranges.add((c, c));
        };
        case (#Range(start, end)) {
          ranges.add((start, end));
        };
        case (#Metacharacter(m)) {
          let metaRanges = metacharToRanges(m);
          for (range in metaRanges.vals()) {
            ranges.add(range);
          };
        };
        case _ {};
      };
    };
    let sortedRanges = Array.sort<(Char, Char)>(
      Buffer.toArray(ranges),
      func(a : (Char, Char), b : (Char, Char)) : Order.Order {
        Nat32.compare(Char.toNat32(a.0), Char.toNat32(b.0));
      },
    );

    let mergedRanges = Buffer.Buffer<(Char, Char)>(sortedRanges.size());
    if (sortedRanges.size() > 0) {
      var current = sortedRanges[0];
      for (i in Iter.range(1, sortedRanges.size() - 1)) {
        let next = sortedRanges[i];
        if (Char.toNat32(current.1) + 1 >= Char.toNat32(next.0)) {
          current := (
            current.0,
            if (Char.toNat32(current.1) > Char.toNat32(next.1)) current.1 else next.1,
          );
        } else {
          mergedRanges.add(current);
          current := next;
        };
      };
      mergedRanges.add(current);
    };

    if (not isNegated) {
      Buffer.toArray(mergedRanges);
    } else {
      let complementRanges = Buffer.Buffer<(Char, Char)>(mergedRanges.size() + 1);
      let mergedArray = Buffer.toArray(mergedRanges);

      if (mergedArray.size() > 0) {
        let firstStart = Char.toNat32(mergedArray[0].0);
        if (firstStart > 0) {
          complementRanges.add((
            Char.fromNat32(0),
            Char.fromNat32(firstStart - 1),
          ));
        };

        for (i in Iter.range(0, mergedArray.size() - 2)) {
          let currentEnd = Char.toNat32(mergedArray[i].1);
          let nextStart = Char.toNat32(mergedArray[i + 1].0);
          if (currentEnd + 1 < nextStart) {
            complementRanges.add((
              Char.fromNat32(currentEnd + 1),
              Char.fromNat32(nextStart - 1),
            ));
          };
        };

        let lastEnd = Char.toNat32(mergedArray[mergedArray.size() - 1].1);
        if (lastEnd < 255) {
          complementRanges.add((
            Char.fromNat32(lastEnd + 1),
            Char.fromNat32(255),
          ));
        };
      } else {
        complementRanges.add((
          Char.fromNat32(0),
          Char.fromNat32(255),
        ));
      };

      Buffer.toArray(complementRanges);
    };
  };
  public func getMaxState(transitions : [Transition], acceptStates : [State], startState : State) : State {
    var maxState = startState;
    for ((from, _, to, _) in transitions.vals()) {
      if (from > maxState) maxState := from;
      if (to > maxState) maxState := to;
    };
    for (state in acceptStates.vals()) {
      if (state > maxState) maxState := state;
    };
    maxState;
  };
  public func containsState(array : [Nat], state : Nat) : Bool {
    for (item in array.vals()) {
      if (item == state) {
        return true;
      };
    };
    false;
  };
  public func computeExpressionLength(ast : Types.ASTNode) : Result.Result<Nat, Types.RegexError> {
    switch (ast) {
      case (#Character(_)) {
        #ok(1);
      };

      case (#Range(_, _)) {
        #ok(1);
      };

      case (#Metacharacter(_)) {
        #ok(1);
      };

      case (#CharacterClass(_)) {
        #ok(1);
      };

      case (#Concatenation(subExprs)) {
        var totalLength = 0;
        for (expr in subExprs.vals()) {
          switch (computeExpressionLength(expr)) {
            case (#err(e)) return #err(e);
            case (#ok(len)) { totalLength += len };
          };
        };
        #ok(totalLength);
      };

      case (#Alternation(_)) {
        #err(#GenericError("Alternations in lookbehind must be fixed-length"));
      };

      case (#Quantifier({ quantifier = { min; max; mode = _ } })) {
        switch (min, max) {
          case (n, ?m) {
            if (n == m) { #ok(n) } else {
              #err(#GenericError("Variable-length quantifiers are not allowed in lookbehind"));
            };
          };
          case (_, null) {
            #err(#GenericError("Unbounded quantifiers are not allowed in lookbehind"));
          };
        };
      };

      case (#Group({ subExpr; modifier = _ })) {
        switch (computeExpressionLength(subExpr)) {
          case (#err(e)) return #err(e);
          case (#ok(len)) { #ok(len) };
        };
      };

      case (_) {
        #err(#GenericError("Unsupported construct in lookbehind"));
      };
    };
  };
  public func flattenAST(ast : Types.ASTNode) : [Types.ASTNode] {
    switch (ast) {
      case (#Concatenation(exprs)) {
        var result = [] : [Types.ASTNode];
        for (expr in exprs.vals()) {
          result := Array.append<Types.ASTNode>(result, flattenAST(expr));
        };
        result;
      };
      case _ { [ast] };
    };
  };
  public func compareTransitions(a : Transition, b : Transition) : Order.Order {
    switch (a.1, b.1) {
      case (#Char(_), #Range(_)) #less;
      case (#Range(_), #Char(_)) #greater;
      case (#Char(charA), #Char(charB)) {
        if (charA < charB) #less else if (charA > charB) #greater else {
          let modeA = switch (a.3) { case (?m) m; case null #Greedy };
          let modeB = switch (b.3) { case (?m) m; case null #Greedy };
          switch (modeA, modeB) {
            case (#Lazy, #Greedy) #less;
            case (#Greedy, #Lazy) #greater;
            case _ #equal;
          };
        };
      };
      case (#Range((startA, endA)), #Range((startB, endB))) {
        if (startA < startB) #less else if (startA > startB) #greater else if (endA < endB) #less else if (endA > endB) #greater else {
          let modeA = switch (a.3) { case (?m) m; case null #Greedy };
          let modeB = switch (b.3) { case (?m) m; case null #Greedy };
          switch (modeA, modeB) {
            case (#Lazy, #Greedy) #less;
            case (#Greedy, #Lazy) #greater;
            case _ #equal;
          };
        };
      };
    };
  };
  public func transitionEquals(a : Transition, b : Transition) : Order.Order {
    if (a.0 < b.0) return #less;
    if (a.0 > b.0) return #greater;
    if (a.2 < b.2) return #less;
    if (a.2 > b.2) return #greater;
    if (a.1 != b.1) return #less;
    if (a.3 != b.3) return #less;
    #equal;
  };
  public func sortTransitionsInPlace(transitions : [var Transition]) {
    Array.sortInPlace<Transition>(
      transitions,
      func(a : Transition, b : Transition) {
        compareTransitions(a, b);
      },
    );
  };
};
