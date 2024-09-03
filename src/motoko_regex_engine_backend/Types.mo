import Text "mo:base/Text";
import Array "mo:base/Array";
module{
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
    public type ASTNode = {
    #Character : Char;
    #Concatenation : (AST, AST); 
    #Alternation : (AST, AST); 
    #Quantifier : (QuantifierType, AST); 
    #Group : AST;
    #Metacharacter :MetacharacterType;
    #CharacterClass : (Bool, [CharacterClass]); 
    #Anchor : AnchorType;
  };

  public type AST = {
    #node : ASTNode;
  };
  public type TokenType = {
    #Character : Char;
    #Metacharacter : MetacharacterType;
    #Quantifier : QuantifierType;
    #GroupStart;
    #GroupEnd;
    #QuantifierRange;
    #GroupModifier : GroupModifierType;
    #CharacterClass : (Bool, [CharacterClass]);
    #Anchor : AnchorType;
    #Alternation;
  };

  public type MetacharacterType = {
    #Dot;
    #WordChar;
    #NonWordChar;
    #Digit;
    #NonDigit;
    #Whitespace;
    #NonWhitespace;
  };

  public type CharacterClass = {
    #Single : Char;
    #Range : (Char, Char);
  };
  public type QuantifierType = {
    #ZeroOrMore;
    #OneOrMore;
    #ZeroOrOne;
    #Range : (Nat, ?Nat);
    #Lazy;
    #Possessive;
  };

  public type GroupModifierType = {
    #NonCapturing;
    #PositiveLookahead;
    #NegativeLookahead;
    #PositiveLookbehind;
    #NegativeLookbehind;
  };

  public type AnchorType = {
    #StartOfString;
    #EndOfString;
    #WordBoundary;
    #NonWordBoundary;
    #StartOfStringOnly;
    #EndOfStringOnly;
    #PreviousMatchEnd;
  };

  public type Token = {
    tokenType : TokenType;
    value : Text;
    position : Nat;
  };

  public type LexerError = {
    #UnexpectedCharacter : Char;
    #UnexpectedEndOfInput;
    #GenericError :Text;
    #InvalidQuantifierRange : Text;
    #InvalidEscapeSequence : Char;
    #UnmatchedParenthesis : Char;
    #MismatchedParenthesis : (Char, Char);
  };

  public type State = Nat;
  public type TransitionTable = [(State, Transition, State)];

  public type Transition = {
    #Char : Char;
    #Range : (Char, Char);
    #Any;
    #Epsilon;
  };

  public type CompiledRegex = {
    transitions : TransitionTable;
    startState : State;
    acceptStates : [State];
    captureGroups : [CaptureGroup];
  };

  public type CaptureGroup = {
    startState : State;
    endState : State;
  };
}