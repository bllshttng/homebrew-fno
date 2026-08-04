# Homebrew formula for the `fno` CLI - the brew install channel (ab-d59d219a).
#
# This is the canonical source of the formula. It is copied verbatim into the
# own tap repo (github.com/<owner>/homebrew-fno) so `brew install <owner>/fno/fno`
# resolves it. Keeping the source here lets CI parse + audit it and lets the
# brew clean-machine smoke (cli/tests/smoke/brew_formula_smoke.sh) prove the
# install + symlink mechanism against a freshly built local wheel.
#
# The "py-wheel flywheel" (shared with the cargo + fno.sh channels): `fno` is the
# Python Typer CLI and only `fno-agents{,-daemon,-worker}` are Rust, so the
# formula installs the published PyPI *platform wheel* (which already bundles all
# three binaries as wheel `shared_scripts`) into a brew-managed venv. brew
# provides Python (depends_on "python@3.13"); the wheel is the single artifact
# source. brew owns the venv + symlinks, so `brew uninstall`/`brew upgrade` are
# clean (Locked Decisions 2 + 3).
#
# LAUNCH GATE: satisfied for 0.2.1 on both macOS arches. `fno` 0.2.1 is
# published to PyPI (the shared gate with cargo + fno.sh), and the arm64 +
# x86_64 `url` + `sha256` below are the real published wheels (kept in lockstep
# on every release bump). The x86_64 macOS wheel is cross-built on the macos-14
# runner (the native Intel macos-13 image is retired); see release-wheels.yml.
#
# Deps: an own-tap formula installs with network, so `pip install` resolves the
# Python deps from PyPI at install time. (Vendoring deps as offline `resource`
# blocks via `brew update-python-resources fno` is a future hardening only a
# homebrew-core submission would require - out of scope for the own tap.)
class Fno < Formula
  desc "Autonomous delivery pipeline CLI (footnote)"
  homepage "https://github.com/bllshttng/footnote"

  # The x86_64 wheel (macosx_10_12) is the top-level default so a `url` is ALWAYS
  # defined - including on Linux, where the on_macos block is skipped. Homebrew
  # validates url presence at load (before requirements), so without a top-level
  # url a Linuxbrew user would hit a confusing `stable: url is missing` instead
  # of the clean `depends_on :macos` refusal below. arm64 overrides this url (and
  # adds its Sonoma floor) inside on_macos.
  url "https://files.pythonhosted.org/packages/75/51/7bb3eb8eb5098b9d468dfca6d74f3981c4312e1a99998c8235cea09ae1f4/fno-0.3.1-py3-none-macosx_10_12_x86_64.whl", using: :nounzip
  # Explicit version: Homebrew's filename version-detect picks "64" out of the
  # x86_64 default-url tag, not 0.2.1. Pin it so `brew info`/upgrade are correct.
  version "0.3.1"
  sha256 "0db1eadfcc825717bb73a8cfe186b4fd1c678133b5e3a23789001a5ea580965f"
  license "Apache-2.0"

  # Both macOS arches ship a wheel; the macOS floor is arch-conditional. The
  # arm64 wheel is tagged macosx_14_0, so its Sonoma floor is pinned on arm only
  # (an arm64 Mac on macOS 11-13 would otherwise pass and then hit an ugly pip
  # "incompatible wheel" error); the x86_64 default targets macosx_10_12, so
  # Intel needs no extra macOS gate beyond python@3.13's own. `depends_on :macos`
  # refuses Linuxbrew, and the top-level url above makes that refusal the error a
  # Linux user actually sees instead of "url is missing".
  depends_on :macos
  depends_on "python@3.13"

  # The wheel carries native Rust binaries, so the URL must match the host arch.
  # `using: :nounzip` keeps the wheel a FILE: a .whl is a zip, and an unpacked
  # wheel dir is not pip-installable (no build backend), so the install step
  # below pip-installs the wheel file directly rather than the unpacked tree.
  # arm64 overrides the top-level x86_64 default with its own wheel + floor.
  on_macos do
    on_arm do
      # The arm64 wheel is tagged macosx_14_0, so it requires Sonoma; the x86_64
      # default targets macosx_10_12, so this floor is arm-only.
      depends_on macos: :sonoma
      url "https://files.pythonhosted.org/packages/c2/79/338d8cd270ef52e27306e092886d08ea03236f0612ebf59056c85407a3a6/fno-0.3.1-py3-none-macosx_14_0_arm64.whl", using: :nounzip
      sha256 "d6d7c6e6809fd8f567fc0591fcc744965513af8500c506fca64f414546ce88b6"
    end
  end

  def install
    # Build the venv from the python@3.13 dependency (never the host python,
    # which may be older on a clean machine).
    system Formula["python@3.13"].opt_bin/"python3.13", "-m", "venv", libexec

    # The wheel is a FILE in buildpath (url's :nounzip - an unpacked wheel dir is
    # not pip-installable), so pip-install the wheel file directly. pip resolves
    # the Python deps from PyPI (own-tap network). This is the mechanism the brew
    # smoke exercises end to end.
    system libexec/"bin/pip", "install", "--disable-pip-version-check", Dir["*.whl"].first

    # The `fno` console_script plus the three Rust binaries (which ride in the
    # wheel as `shared_scripts`) all land in the venv bin; pip links none of them
    # into the keg bin, so symlink them explicitly. The fno-agents* symlink is
    # the load-bearing step (Locked Decision 4): the CLI invokes the binaries by
    # name on PATH. Arch-agnostic via libexec.
    bin.install_symlink libexec/"bin/fno"
    bin.install_symlink Dir[libexec/"bin/fno-agents*"]
  end

  test do
    # The CLI runs from the keg bin.
    assert_match "fno", shell_output("#{bin}/fno --version")

    # All three binaries must be present + executable on the keg bin, or a
    # daemon/loop verb would 127 at runtime. Fail the test on any miss
    # (no silent success for a half-installed CLI).
    %w[fno-agents fno-agents-daemon fno-agents-worker].each do |b|
      assert_predicate bin/b, :executable?, "#{b} missing from the keg bin"
    end
  end
end
