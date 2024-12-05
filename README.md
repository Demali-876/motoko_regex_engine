# Motoko Regex Engine

A NFA based regular expression engine implemented in Motoko.

⚠️ **Note**: This project is currently under development and not intended for production use.

## Architecture

The following diagram illustrates the core components and data flow of the regex engine:

```mermaid
graph TD
    subgraph Input
        input[TEXT INPUT]
        cursor[EXTERNAL CURSOR]
    end

    subgraph Engine Core
        lexer[LEXER]
        parser[PARSER]
        compiler[COMPILER]
        matcher[MATCHER]
        api[REGEX API]
    end

    subgraph Outputs
        tokens[Tokens]
        ast[AST]
        nfa[NFA]
        result[MATCH RESULT]
    end

    %% Input flow
    input --> cursor
    cursor --> lexer

    %% Main processing flow
    lexer --> tokens
    tokens --> parser
    parser --> ast
    ast --> compiler
    compiler --> nfa
    nfa --> matcher
    matcher --> result

    %% API connections
    api --> lexer
    api --> parser
    api --> compiler
    api --> matcher

    %% Styling
    classDef core fill:#f5f5f5,stroke:#333,stroke-width:2px
    classDef output fill:#e1f5fe,stroke:#333
    classDef api fill:#fff3e0,stroke:#333,stroke-width:2px

    class lexer,parser,compiler,matcher core
    class tokens,ast,nfa,result output
    class api api
```

### Component Description

1. **Input Processing**:
   - Text Input: Raw regular expression string
   - External Cursor: Character-by-character stream processor

2. **Core Components**:
   - **Lexer**: Tokenizes the input stream into meaningful regex components
   - **Parser**: Builds an Abstract Syntax Tree (AST) from tokens
   - **Compiler**: Transforms the AST into a Non-deterministic Finite Automaton (NFA)
   - **Matcher**: Executes pattern matching using the compiled NFA

3. **Intermediate Outputs**:
   - Tokens: Lexical units of the regex pattern
   - AST: Tree representation of the pattern structure
   - NFA: State machine for pattern matching
   - Match Result: Final output indicating match success/failure and captures

## Installation

You can install the regex engine using [MOPS](https://mops.one/):

```bash
mops add regex
```

## Import

```motoko
import Regex "mo:regex";
```

## Documentation

For full documentation, visit [Motoko Regex Engine Docs](https://demali-876.github.io/motoko_regex_engine/introduction.html).

## Support & Acknowledgements

This project was developed with the support of a developer grant from the DFINITY Foundation.

### Community Feedback

Your feedback is invaluable in improving this and future projects. Feel free to share your thoughts and suggestions through issues or discussions.

### Support the Developer

If you find this project valuable and would like to support my work on this and other open-source initiatives, you can send ICP donations to:

```motoko
8c4ebbad19bf519e1906578f820ca4f6732ceecc1d5396e5a5713046dca251c1
```
