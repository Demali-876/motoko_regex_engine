import Text "mo:base/Text";
import Char "mo:base/Char";
module{
  public type AST = {
    node: ASTNode;
  };
  public type ASTNode = {
    #Character : Char;
    #Concatenation : [AST];
    #Alternation : [AST];
    #Quantifier : {
        subExpr: AST;
        min: Nat;
        max: ?Nat;
        mode: QuantifierMode;
    };
    #Group : {
        subExpr: AST;
        modifier: GroupModifierType;
        captureIndex: ?Nat;
    };
    #Metacharacter : MetacharacterType;
    #CharacterClass : {
        isNegated: Bool;
        classes: [CharacterClass]; 
    };
    #Anchor : AnchorType;
  };
  public type TokenType = {
    #Character : Char;
    #Metacharacter : MetacharacterType;
    #Quantifier : QuantifierType;
    #GroupModifier : GroupModifierType;
    #CharacterClass : (Bool, [CharacterClass]);
    #Anchor : AnchorType;
    #Alternation;
    #Group : {
        modifier: ?GroupModifierType;
        subTokens: [Token];
    };
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
    #Metacharacter : MetacharacterType;
    #Quantified : (CharacterClass, QuantifierType);
  };
  public type QuantifierMode = {
    #Greedy;
    #Lazy;
    #Possessive;
};

public type QuantifierType = {
    min : Nat;
    max : ?Nat;
    mode : QuantifierMode;
  };
  public type Position={
    #Instance :Nat;
    #Span : (Nat, Nat);
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
    position : Position;
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