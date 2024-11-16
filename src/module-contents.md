# Module Contents

The Motoko Regex Engine module includes the following components:

1. **Lexer**: Tokenizes the input regex pattern.
2. **Parser**: Converts tokens into an Abstract Syntax Tree (AST).
3. **Compiler**: Compiles the AST into an NFA (Non-deterministic Finite Automaton).
4. **Matcher**: Simulates the NFA on the input string.
