# homebrew-fno

Homebrew tap for [`fno`](https://github.com/bllshttng/footnote) - the footnote CLI.

```sh
brew install bllshttng/fno/fno
```

That installs the `fno` Python CLI plus the bundled `fno-agents` Rust binaries from the published PyPI platform wheel (arm64 and x86_64 macOS). For the `/fno:*` Claude Code slash commands, install the plugin instead - see the [footnote README](https://github.com/bllshttng/footnote#install).

`Formula/fno.rb` is generated from `scripts/install/homebrew/fno.rb` in the footnote repo; it is re-synced (url + sha256 bumped in lockstep) on every release.
