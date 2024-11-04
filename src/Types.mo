import Text "mo:base/Text";
import Char "mo:base/Char";
module{
   //Lexer Token Types
    public type Token = {
      tokenType : TokenType;
      value : Text;
      position : Position;
    };
    public type Position={
      #Instance :Nat;
      #Span : (Nat, Nat);
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

    //AST Types
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

    //Error Types
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
  //NFA Types
  public type State = Nat;
  public type Sybmol ={
    #Range : (Char, Char);
    #Char :Char;
    #Epsilon;
  };
  public type Transition = (State, Sybmol, State);
  

  public type CompiledRegex = {
    states : [State];
    transitions : [Transition];
    startState : State;
    acceptStates : [State];
  };
  //Matcher Types
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