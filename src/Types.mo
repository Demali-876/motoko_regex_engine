import Text "mo:base/Text";
import Char "mo:base/Char";
module {
  //Lexer Token Types
  public type Token = {
    tokenType : TokenType;
    value : Text;
    position : Position;
  };
  public type Position = {
    #Instance : Nat;
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
      modifier : ?GroupModifierType;
      subTokens : [Token];
      quantifier : ?QuantifierType;
      name : ?Text;
    };
    #Backreference;
  };
  public type MetacharacterType = {
    #Dot;
    #WordChar;
    #NonWordChar;
    #Digit;
    #NonDigit;
    #Whitespace;
    #NonWhitespace;
    #UnicodeProperty : (Bool, Text);
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
      subExpr : AST;
      quantifier : QuantifierType;
    };
    #Range : (Char, Char);
    #Group : {
      subExpr : AST;
      modifier : ?GroupModifierType;
      captureIndex : ?Nat;
      name : ?Text;
    };
    #Metacharacter : MetacharacterType;
    #CharacterClass : {
      isNegated : Bool;
      classes : [AST];
    };
    #Anchor : AnchorType;
    #Backreference : Text;
  };

  //Error Types
  public type RegexError = {
    #UnexpectedCharacter : Char;
    #UnexpectedEndOfInput;
    #GenericError : Text;
    #InvalidQuantifierRange : Text;
    #InvalidEscapeSequence : Char;
    #UnmatchedParenthesis : Char;
    #MismatchedParenthesis : (Char, Char);
    #UnexpectedToken : TokenType;
    #UnclosedGroup : Text;
    #InvalidQuantifier : Text;
    #EmptyExpression : Text;
    #UnsupportedASTNode : Text;
    #InvalidTransition : Text;
    #NotCompiled;
  };
  //NFA Types
  public type State = Nat;
  public type Symbol = {
    #Range : (Char, Char);
    #Char : Char;
  };
  public type Transition = (State, Symbol, State, ?QuantifierMode);

  public type Assertion = {
    assertion : {
      #Anchor : {
        aType : AnchorType;
        position : State;
      };
      #Lookaround : {
        startState : State;
        states : [State];
        transitionTable : [[Transition]];
        acceptStates : [State];
        isPositive : Bool;
        isAhead : Bool;
        position : State;
        length : ?Nat;
      };
      #Backreference : {
        captureIndex : Nat;
        position : State;
        length : Nat;
      };
      #Group : {
        captureIndex : Nat;
        startState : State;
        endStates : [State];
      };
    };
  };

  public type GroupsMetadata = {
    name : Text;
    captureIndex : Nat;
    startState : State;
    endStates : [State];
    length : Nat;
  };
  public type CompiledRegex = {
    states : [State];
    transitionTable : [[Transition]];
    startState : State;
    acceptStates : [State];
    assertions : [Assertion];
  };

  //Matcher Types
  public type Match = {
    string : Text;
    value : Text;
    status : {
      #FullMatch;
      #NoMatch;
    };
    position : (Nat, Nat);
    capturedGroups : ?[(Text, Nat)];
    spans : [(Nat, Nat)];
    lastIndex : Nat;
  };
  public type Flags = {
    caseSensitive : Bool;
    multiline : Bool;
  };
};
