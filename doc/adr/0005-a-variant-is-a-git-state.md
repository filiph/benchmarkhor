# A Variant is a git state

The **Variants** compared in a **Session** are the same **Trial** built against
different states of one repository — HEAD versus a stash, a PR branch versus its
merge base, before and after an edit still sitting in the working tree. They are
not two code paths living side by side in the tree. A project therefore owns one
Trial per thing it cares about ("scroll performance on the product list"), not
one Trial per Variant, and the **Variant APK** count is a build-time fact rather
than a source-tree fact.

The argument is that the questions people actually have are questions about
changes. "Did my optimisation help", "is this PR a regression", "which of these
three approaches is fastest" all name git states, and none of them name a widget
that could be duplicated. Encoding the Variant axis in the source tree means
first writing the change *and* a permanent forked copy of the code it changed,
then keeping the two Trials that drive them in sync by hand — an invariant
nothing checks and nothing warns about. Encoding it in git means the diff between
Variants is exactly the change under test, which is the definition of a
controlled comparison, and it costs nothing to set up.

What this buys has a price: the Trial and the whole harness it needs
(`MainActivityTest.java`, `testBuildType = "profile"`, the frame recorder) will
not exist in the older git state, and a Trial that differs between two builds
invalidates the comparison silently. Hence the harness goes in first, before any
Variant is built, and every Variant is built from a tree in which the harness
files are byte-identical. How the differing app code is produced is scaled to the
job: for a quick comparison the harness need never be committed at all — build,
edit, build again — while a project standing up a lasting performance suite
commits the harness onto a base its Variants share and builds each ref in its own
worktree.

## Consequences

`example_apk` contradicts this ADR on purpose and is the one exemption.
`expensive_route.dart` / `expensive_route_optimized.dart` and their two Trial
files exist in-tree because the **App Under Measurement** is a fixture: it has to
produce an **APK Pair** per Variant from a single checkout, with no git history to
lean on, so that the rig can be exercised by anyone who clones the repo. Read it
as a test fixture for `adb_server`, never as the recommended shape for a real
app's harness. Its README already records the cost — the two Trial files must be
kept in sync by hand and nothing warns when they drift.

Sessions become reproducible only to the extent that the git states are named.
A Session whose Variants came from uncommitted edits cannot be rebuilt later, and
`session.json` has nowhere to record a commit hash today. That is an acceptable
trade for quick comparisons and a real gap for the rigorous path.

A Variant name in `session.json` is documentation, not a reference: nothing links
`baseline` to a commit. Choosing names that say which git state they came from is
the only defence against a **Session Directory** nobody can interpret a week
later.
