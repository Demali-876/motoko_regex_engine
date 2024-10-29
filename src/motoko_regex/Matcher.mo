import Types "Types";
import Result "mo:base/Result";
module{
    class Matcher(){
        type NFA = Types.CompiledRegex;
        type Flags = Types.MatchFlags;
        type Match = Types.MatchResult;
        type MatchError = Types.RegexError;

        public func match(nfa: NFA, pattern: Text, flags: ?Flags): Result.Result<Match, MatchError> {}
    }
}