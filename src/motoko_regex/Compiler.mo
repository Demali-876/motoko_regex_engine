import Types "Types";
import Buffer "mo:base/Buffer";
import Order "mo:base/Order";
import Iter "mo:base/Iter";
import Char "mo:base/Char";
import Array "mo:base/Array";
import Int "mo:base/Int";
import Option "mo:base/Option";
import Nat "mo:base/Nat";
import Result "mo:base/Result";
import Extensions "Extensions";
import Set "Extensions";
import Optimizer "Optimizer";

module {
  public class Compiler() {

    type State = Types.State;
    type AST = Types.AST;
    type LabeledASTNode = Types.LabeledASTNode;
    type ASTNode = Types.ASTNode;
    type NFA = Types.CompiledRegex;
    type Transition = Types.Transition;
    type TransitionTable = Types.TransitionTable;
    type CompilerError = Types.RegexError;

    public type NullableFirstLast = {
      nullable: Bool;
      firstSet: Set.Set<Nat>;
      lastSet: Set.Set<Nat>;
    };

    private var nextLabel = 0;
    func getnextLabel() : Nat {
      nextLabel += 1;
      nextLabel;
    };

    // Label the AST nodes recursively
    public func labelAST(ast: AST): LabeledASTNode {
      func labelNode(node: AST): LabeledASTNode {
        switch (node) {
          case (#Character(c)) {
            let nlabel = getnextLabel();
            { nlabel = ?nlabel; node = #Character(c) };
          };
          case (#Range(start, end)) {
            let nlabel = getnextLabel();
            { nlabel = ?nlabel; node = #Range(start, end) };
          };
          case (#Metacharacter(m)) {
            let nlabel = getnextLabel();
            { nlabel = ?nlabel; node = #Metacharacter(m) };
          };
          case (#Anchor(a)) {
            { nlabel = null; node = #Anchor(a) };
          };
          case (#Concatenation(nodes)) {
            let labeledChildren = Array.map<AST, LabeledASTNode>(nodes, labelNode);
            { nlabel = null; node = #Concatenation(labeledChildren) };
          };
          case (#Alternation(nodes)) {
            let labeledChildren = Array.map<AST, LabeledASTNode>(nodes, labelNode);
            { nlabel = null; node = #Alternation(labeledChildren) };
          };
          case (#Quantifier({ subExpr; quantifier })) {
            let labeledSubExpr = labelNode(subExpr);
            { nlabel = null; node = #Quantifier({ subExpr = labeledSubExpr; quantifier = quantifier }) };
          };
          case (#Group({ subExpr; modifier; captureIndex })) {
            let labeledSubExpr = labelNode(subExpr);
            { nlabel = null; node = #Group({ subExpr = labeledSubExpr; modifier = modifier; captureIndex = captureIndex }) };
          };
          case (#CharacterClass({ isNegated; classes })) {
            let labeledClasses = Array.map<AST, LabeledASTNode>(classes, labelNode);
            { nlabel = null; node = #CharacterClass({ isNegated = isNegated; classes = labeledClasses }) };
          };
        }
      };
      labelNode(ast);
    };

    // Compute Nullable, First, and Last Sets
    public func computeNullableFirstLast(ast: LabeledASTNode): NullableFirstLast {
      var firstSet = Set.Set<Nat>(Int.hash, Nat.equal);
      var lastSet = Set.Set<Nat>(Int.hash, Nat.equal);

      switch (ast.node) {
        case (#Character(_) or #Range(_, _) or #Metacharacter(_) or #Anchor(_)) {
          if (ast.nlabel != null) {
            let nlabel = Option.get<Nat>(ast.nlabel,0);
            firstSet.add(nlabel);
            lastSet.add(nlabel);
          };
          {
            nullable = false;
            firstSet = firstSet;
            lastSet = lastSet;
          };
        };

        case (#Concatenation(nodes)) {
          var nullable = true;

          // First Set
          label l for (i in Iter.range(0, nodes.size() - 1)) {
            let subExpr = nodes[i];
            let subResult = computeNullableFirstLast(subExpr);
            firstSet := firstSet.union(subResult.firstSet);
            if (not subResult.nullable) {
              nullable := false;
              break l;
            };
          };

          // Last Set
          nullable := true;
          label ll for (i in Iter.range(nodes.size() - 1, 0)) {
            let subExpr = nodes[i];
            let subResult = computeNullableFirstLast(subExpr);
            lastSet := lastSet.union(subResult.lastSet);
            if (not subResult.nullable) {
              nullable := false;
              break ll;
            };
          };

          // Overall Nullable
          nullable := true;
          for (subExpr in nodes.vals()) {
            let subResult = computeNullableFirstLast(subExpr);
            nullable := nullable and subResult.nullable;
          };

          {
            nullable = nullable;
            firstSet = firstSet;
            lastSet = lastSet;
          };
        };

        case (#Alternation(nodes)) {
          var nullable = false;
          for (subExpr in nodes.vals()) {
            let subResult = computeNullableFirstLast(subExpr);
            nullable := nullable or subResult.nullable;
            firstSet := firstSet.union(subResult.firstSet);
            lastSet := lastSet.union(subResult.lastSet);
          };
          {
            nullable = nullable;
            firstSet = firstSet;
            lastSet = lastSet;
          };
        };

        case (#Quantifier({ subExpr; quantifier })) {
          let subResult = computeNullableFirstLast(subExpr);
          var nullable = false;

          // Quantifier logic based on min and max
          switch (quantifier) {
            case ({ min; max = _ ; mode = _ ; }) {
              if (min == 0) {
                nullable := true;
              } else {
                nullable := subResult.nullable;
              };
            };
          };

          {
            nullable = nullable;
            firstSet = subResult.firstSet;
            lastSet = subResult.lastSet;
          };
        };

        case (#Group({ subExpr; modifier = _; captureIndex = _ ; })) {
          let subResult = computeNullableFirstLast(subExpr);
          {
            nullable = subResult.nullable;
            firstSet = subResult.firstSet;
            lastSet = subResult.lastSet;
          };
        };

        case (#CharacterClass({ isNegated = _; classes })) {
          var nullable = false;
          for (cls in classes.vals()) {
            let subResult = computeNullableFirstLast(cls);
            nullable := nullable or subResult.nullable;
            firstSet := firstSet.union(subResult.firstSet);
            lastSet := lastSet.union(subResult.lastSet);
          };
          {
            nullable = nullable;
            firstSet = firstSet;
            lastSet = lastSet;
          };
        };
      }
    };
    public func constructNFA(ast: LabeledASTNode): NFA {
      let nfl = computeNullableFirstLast(ast);
      let states = Set.Set<Nat>(Int.hash, Nat.equal);
      let transitions = Buffer.Buffer<(State, Transition, State)>(0);

      states.add(0);
      func addCharTransitions(from: State, to: State, node: LabeledASTNode) {
        switch (node.node) {
          case (#Character(c)) { transitions.add((from, #Char(c), to)); };
          case (#Range(start, end)) { transitions.add((from, #Range(start, end), to)); };
          case (#Metacharacter(_)) { transitions.add((from, #Any, to)); };
          case (#CharacterClass({ isNegated =_; classes })) {
            for (cls in classes.vals()) {
              addCharTransitions(from, to, cls);
            };
          };
          case _ {}  // Other cases don't add character transitions
        };
      };
      for (pos in nfl.firstSet.toIter()) {
        addCharTransitions(0, pos, ast);
        states.add(pos);
      };
      
      // Add transitions between positions
      func addTransitions(node: LabeledASTNode) {
        switch (node.node) {
          case (#Character(c)) {
            if (node.nlabel != null) {
              let nlabel = Option.get<Nat>(node.nlabel, 0);
              transitions.add((nlabel, #Char(c), nlabel));
            };
          };
          case (#Range(start, end)) {
            if (node.nlabel != null) {
              let nlabel = Option.get<Nat>(node.nlabel, 0);
              transitions.add((nlabel, #Range(start, end), nlabel));
            };
          };
          case (#Metacharacter(_)) {
            if (node.nlabel != null) {
              let nlabel = Option.get<Nat>(node.nlabel, 0);
              transitions.add((nlabel, #Any, nlabel));
            };
          };
          case (#Anchor(_)) {
            // Anchors don't add transitions in Glushkov's construction
          };
          case (#Concatenation(nodes)) {
            for (i in Iter.range(0, nodes.size() - 2)) {
              let current = computeNullableFirstLast(nodes[i]);
              let next = computeNullableFirstLast(nodes[i+1]);
              for (from in current.lastSet.toIter()) {
                for (to in next.firstSet.toIter()) {
                  addCharTransitions(from, to, nodes[i+1]);
                };
              };
            };
            for (subNode in nodes.vals()) { addTransitions(subNode); };
          };
          case (#Alternation(nodes)) {
            for (subNode in nodes.vals()) { addTransitions(subNode); };
          };
          case (#Quantifier({ subExpr; quantifier })) {
            addTransitions(subExpr);
            let subNFL = computeNullableFirstLast(subExpr);
            switch (quantifier) {
              case ({ min = _; max = null; mode = _ }) {
                for (from in subNFL.lastSet.toIter()) {
                  for (to in subNFL.firstSet.toIter()) {
                    addCharTransitions(from, to, subExpr);
                  };
                };
              };
              case _ {}  
            };
          };
          case (#Group({ subExpr; modifier = _; captureIndex })) {
            addTransitions(subExpr);
            let subNFL = computeNullableFirstLast(subExpr);
            transitions.add((
              Option.get(node.nlabel, 0), 
              #Group({ 
                startState = Option.get(subExpr.nlabel, 0); 
                endState = subNFL.lastSet.toArray()[subNFL.lastSet.toArray().size()-1];
                captureIndex = captureIndex 
              }), 
              subNFL.lastSet.toArray()[subNFL.lastSet.toArray().size()-1]
            ));
          };
          case (#CharacterClass({ isNegated = _; classes })) {
            for (cls in classes.vals()) { addTransitions(cls); };
          };
        };
      };
      addTransitions(ast);
      // Add final states
      let finalStates : Set.Set<Nat> = switch (nfl.nullable) {
      case (true) { 
        let tempSet = Set.Set<Nat>(Int.hash, Nat.equal).union(nfl.lastSet);
        tempSet.add(0);
        tempSet;
      };
      case (false) { nfl.lastSet };
    };
      // Add all states to the set
      for ((from, _, to) in transitions.vals()) {
        states.add(from);
        states.add(to);
      };
      return {
        states = states.toArray();
        startState = 0;
        acceptStates = finalStates.toArray();
        transitions = Buffer.toArray(transitions);
      }
    };
    public func compile(ast: AST): NFA {
        let labeledAST = labelAST(ast);
        constructNFA(labeledAST);
    };
  };
};