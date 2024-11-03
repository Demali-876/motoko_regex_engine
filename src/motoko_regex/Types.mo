import Text "mo:base/Text";
import Char "mo:base/Char";
module{
    public type AST = ASTNode;
    public type ASTNode = {
      #Character : Char;
      #Concatenation : [AST];
      #Alternation : [AST];
      #Quantifier : {
        subExpr: AST;
        quantifier: QuantifierType;
      };
      #Range:(Char,Char);
      #Group : {
          subExpr: AST;
          modifier: ?GroupModifierType;
          captureIndex: ?Nat;
      };
      #Metacharacter : MetacharacterType;
      #CharacterClass : {
          isNegated: Bool;
          classes: [AST]; 
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
      #Concatenation;
      #Group : {
          modifier: ?GroupModifierType;
          subTokens: [Token];
          quantifier: ?QuantifierType;
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

    public type RegexError = {
      #UnexpectedCharacter: Char;
      #UnexpectedEndOfInput;
      #GenericError: Text;
      #InvalidQuantifierRange: Text;
      #InvalidEscapeSequence: Char;
      #UnmatchedParenthesis: Char;
      #MismatchedParenthesis: (Char, Char);
      #UnexpectedToken: TokenType;
      #UnclosedGroup: Text;
      #InvalidQuantifier: Text;
      #InvalidTransition: Text;
      #LabelLimitExceeded: Text;
      #StateOverflow: Text;
      #InvalidState: Text;
  };

    public type State = Nat;

  public type Transition = {
    fromState: State;
    toState: State;
    symbol: {
        #Char: Char;
        #Range: (Char, Char);
        #Epsilon;
    };
  };

  public type TransitionTable = [(State, Transition, State)];

  public type CompiledRegex = {
    states : [State];
    transitions : TransitionTable;
    startState : State;
    acceptStates : [State];
  };
  public type MatchResult = {
    status: MatchStatus;
    start: Nat;
    end: Nat;
    value: Text;
    capturedGroups: CapturedGroups;
  };
  public type CapturedGroups = ?[?Text];
  public type MatchStatus = {
    #FullMatch;
    #PartialMatch;
    #NoMatch;
  };
  public type MatchFlags = {
  caseInsensitive : ?Bool;
  multiline: ?Bool;
  };
}