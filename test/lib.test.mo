import { test; expect } "mo:test";
import Bool "mo:base/Bool";
import Text "mo:base/Text";
import Result "mo:base/Result";
import Types "../src/Types";
import Regex "../src/lib";

func runTestCases(title : Text, flags : Regex.Flags, testCases : [(Text, Text, Result.Result<Types.Match, Types.RegexError>)]) {
    for ((value, regexText, expected) in testCases.vals()) {
        test(
            title # " - Value: " # value # " Regex: " # regexText,
            func() {
                let regex = Regex.Regex(regexText, ?flags);
                // regex.enableDebug(true);
                let result = regex.match(value);

                expect.result<Types.Match, Types.RegexError>(
                    result,
                    func(t : Result.Result<Types.Match, Types.RegexError>) : Text = debug_show (t),
                    func(x : Result.Result<Types.Match, Types.RegexError>, y : Result.Result<Types.Match, Types.RegexError>) : Bool = x == y,
                ).equal(expected);
            },
        );
    };
};

runTestCases(
    "Single Line Match",
    { caseSensitive = true; multiline = false },
    [
        ("/index.html", "^/index\\.htm$", #ok({ capturedGroups = null; lastIndex = 10; position = (0, 0); spans = []; status = #NoMatch; string = "/index.html"; value = "" })),
        ("/index.html", "^index\\.html$", #ok({ capturedGroups = null; lastIndex = 0; position = (0, 0); spans = []; status = #NoMatch; string = "/index.html"; value = "" })),
        ("/index.htm", "^/index\\.htm$", #ok({ capturedGroups = ?[]; lastIndex = 10; position = (0, 10); spans = [(0, 10)]; status = #FullMatch; string = "/index.htm"; value = "/index.htm" })),
        ("/index.html", "^/index\\.html$", #ok({ capturedGroups = ?[]; lastIndex = 11; position = (0, 11); spans = [(0, 11)]; status = #FullMatch; string = "/index.html"; value = "/index.html" })),
        ("/index.html", "\\A/index\\.html\\z", #ok({ capturedGroups = ?[]; lastIndex = 11; position = (0, 11); spans = [(0, 11)]; status = #FullMatch; string = "/index.html"; value = "/index.html" })),
        ("/index.html\n", "^/index\\.html$", #ok({ capturedGroups = null; lastIndex = 11; position = (0, 0); spans = []; status = #NoMatch; string = "/index.html\n"; value = "" })),

        ("file.txt", "^[^/]*\\.txt$", #ok({ capturedGroups = ?[]; lastIndex = 8; position = (0, 8); spans = [(0, 8)]; status = #FullMatch; string = "file.txt"; value = "file.txt" })),
    ],
);

runTestCases(
    "Multi Line Match",
    { caseSensitive = true; multiline = true },
    [
        ("/index.html", "\\A/index\\.html\\z", #ok({ capturedGroups = ?[]; lastIndex = 11; position = (0, 11); spans = [(0, 11)]; status = #FullMatch; string = "/index.html"; value = "/index.html" })),
        ("\n/index.html\n", "\\A/index\\.html\\z", #ok({ capturedGroups = null; lastIndex = 0; position = (0, 0); spans = []; status = #NoMatch; string = "\n/index.html\n"; value = "" })),

        // TODO Broken tests
        // ("\n/index.html\n", "^/index\\.html$", #ok({ capturedGroups = ?[]; lastIndex = 11; position = (0, 10); spans = [(0, 10)]; status = #FullMatch; string = "\n/index.html\n"; value = "/index.html" })),
        // ("/index.html", "^/index\\.html$", #ok({ capturedGroups = ?[]; lastIndex = 11; position = (0, 11); spans = [(0, 11)]; status = #FullMatch; string = "/index.html"; value = "/index.html" })),
    ],
);
