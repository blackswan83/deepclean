# DeepClean has moved into Deep Recovery

DeepClean's cleanup, uninstall, analyze, optimize and status features now live in the
[deeprecovery](https://github.com/blackswan83/deeprecovery) repository, on top of a
shared engine (`DeepCore`) that also does file recovery. One app, one CLI.

Why the merge: the assessment in `deeprecovery/docs/ASSESSMENT.md` found that this
repository's deletion paths were not what the README promised (permanent
`removeItem` instead of Trash, no journal, wholesale cache wipes, substring-based
leftover matching that could remove other apps' data, root `rm -rf` through an
AppleScript string). Rather than patch those in place, the features were rebuilt on
a rule engine with risk levels, dry runs, Trash-by-default and a JSON journal, and
the uninstaller now uses the Homebrew cask leftover database plus exact bundle-id
matching.

What to use instead:

```
deeprecovery/Sources/DeepCore/Cleanup/     rules, planner, leftover database
deeprecovery/Sources/DeepRecovery/Views/   CleanView, UninstallView, AnalyzeView, OptimizeView, StatusView
deeprecovery/Sources/deep/                 `deep clean --list`, `deep clean --max-risk safe`, `deep clean --run`
```

Getting a build: the merged repository builds a signed-ready `.dmg` on GitHub's
macOS runners, so no Mac is needed to produce one. Push a `v*` tag there, or open
any workflow run under
[Actions](https://github.com/blackswan83/deeprecovery/actions) and download the
`DeepRecovery-dmg` artifact.

This repository is kept for history. Do not build or run the code here for real
cleanups; see the findings above for why.
