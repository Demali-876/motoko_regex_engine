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
      #EmptyExpression: Text;
      #UnsupportedASTNode: Text;
      #InvalidTransition: Text;
      #NotCompiled
  };
  //NFA Types
  public type State = Nat;
  public type Symbol ={
    #Range : (Char, Char);
    #Char :Char;
  };
  public type Transition = (State, Symbol, State);
  

  public type CompiledRegex = {
    states : [State];
    transitions : [Transition];
    transitionsByState : [[Transition]];
    startState : State;
    acceptStates : [State];
  };

  //Matcher Types
  public type Match = {
    string: Text;
    value: Text;
    status: {
        #FullMatch;
        #NoMatch;
    };
    position: (Nat, Nat);
    capturedGroups: ?[?Text];
    spans: [(Nat, Nat)];
    lastIndex: Nat;
  };
public type Flags = {
    caseInsensitive: ?Bool;
    multiline: ?Bool;
  };
}