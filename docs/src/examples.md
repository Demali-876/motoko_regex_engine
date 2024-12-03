# Regex Examples for Motoko Regex Engine

## Table of Contents

- [Regex Examples for Motoko Regex Engine](#regex-examples-for-motoko-regex-engine)
  - [Table of Contents](#table-of-contents)
  - [Internet Computer Identifiers](#internet-computer-identifiers)
    - [Principal ID](#principal-id)
    - [Account ID](#account-id)

## Internet Computer Identifiers

### Principal ID

Pattern to validate Principal ID format.

```motoko
// Anonymous Principal will be rejected
let principalPattern = Regex.Regex("^[a-z0-9]{5}-[a-z0-9]{5}-[a-z0-9]{5}-[a-z0-9]{5}-[a-z0-9]{3}$", null);
public func validatePrincipalId(id: Text): Bool {
    switch(principalPattern.match(id)) {
        case (#ok(result)) {
            switch(result.status) {
                case (#FullMatch) true;
                case (#NoMatch) false;
            };
        };
        case (#err(_)) false;
    };
};
```

### Account ID

Pattern to validate Account ID format.

```motoko
// Account ID (32 bytes in hexadecimal)
let accountPattern = Regex.Regex("^[0-9a-f]{64}$", null);
public func validateAccountId(id: Text): Bool {
    switch(accountPattern.match(id)) {
        case (#ok(result)) {
            switch(result.status) {
                case (#FullMatch) true;
                case (#NoMatch) false;
            };
        };
        case (#err(_)) false;
    };
};
```
