# TrioKeep for iOS

TrioKeep is an iOS wallet project forked from [`tonkeeper/ios`](https://github.com/tonkeeper/ios). The Trio network identity recorded here is chain ID `1414678863` (`0x5452494f`), with masterchain genesis root `ADzIkkcxBIvn8aI/zPEJxy+S9pmCudIIpe3WM78QbaA=` and file hash `droQpYLSTJuS5itIhuPGD1oVOoFvloeu0mDy06yWtbo=`.

This repository is derived from Tonkeeper and remains distributed under the upstream GPL-3.0 license. See [LICENSE](LICENSE) for the complete terms.

The Trio wallet is offline and is not a release build. There is no Trio RPC URL, address derivation, or signed transaction submission yet; send actions are disabled. The wallet asset list only admits IDs under `trio/mainnet/`, so TON and other chain balances are not presented as Trio.

The app requests TRI/USD from `https://investortonnft.com/api/trio/rates/TRI-USD` and accepts only the configured TON–Trio bridge source and reserve-TWAP method while the quote is valid. If the feed is missing, invalid, or expired, it shows “Unavailable” and does not use the TON rate. The endpoint currently returns HTTP 503 with `Trio bridge rate feed is not configured.`, so no TRI quote is available.

## Development

This directory is the iOS app; every command below runs from `ios/` (`cd ios`, or `make -C ios <target>` from the repository root).

## GitHub Actions build

The `TrioKeep iOS device archive` workflow archives the project for generic iPhone devices
on pushes to `main` and `codex/**`, pull requests, or a manual run. It disables code signing
and does not use signing secrets. The run uploads a zipped `.xcarchive`, an unsigned IPA
container, and the Xcode result bundle. These artifacts are build outputs for later manual
signing; the IPA is not installable until it has been properly signed and provisioned. CI
generates a build-only Firebase plist. A successful archive does not indicate that Trio
network or wallet operations are ready.

The separate `TrioKeep iOS simulator build` workflow remains available and uploads its own
simulator app artifact.

## Setup

```sh
# installs the pinned dev tools (mise.toml), downloads Debug/Release
# GoogleService-Info.plist from https://github.com/tonkeeper/ios_keys
# and sets up git hooks.
make setup
```

## Tools

`mise.toml` pins the exact versions of swiftformat, swiftgen, swiftlint and xcbeautify;
`make setup` installs them (and installs [mise](https://mise.jdx.dev) itself through
Homebrew if it is missing). Nothing depends on your `PATH`: the make targets and the git
hooks resolve each tool through `scripts/tools/tool.sh`.

To bump a version, edit `mise.toml` and rerun `make setup`. Activating mise in your own
shell is optional — do it if you also want to type `swiftformat` directly:

```sh
echo 'eval "$(mise activate zsh)"' >> ~/.zshrc
```

## Branches and commits

- Branch names follow `author/TASK/description` (e.g., `rzm/IOS-562/fix-header`) where `TASK` is uppercase letters + digits.
- The `commit-msg` hook (`shared/githooks/`, reached through the root `.githooks` symlink) prefixes commit summaries with `[TASK]`, so do not add the task id manually; a branch of another shape (or a detached HEAD) commits unprefixed. It also formats staged Swift files with the pinned swiftformat and rejects the commit if anything changed — except when concluding a merge.

## Environment

If you use Codex skills, ensure required environment values and dependencies are configured first. 
Create a `.env` file at the repository root (one level above `ios/`) with:
- a non-empty `LINEAR_API_KEY` for the Linear skill. (see https://linear.app/developers)
- install `gh` (`brew install gh`) and call `gh auth login` for `tondocs` and `pr` skill
- `ASC_KEY_ID`, `ASC_ISSUER_ID` and `ASC_PRIVATE_KEY_PATH` (path to the `AuthKey_<id>.p8`, App Manager role) for `make appstore_toolings` (attach the build, push `scripts/appstore/whats_new.txt`, submit to review). `ASC_PRIVATE_KEY_BASE64` works instead of the path (for CI).
