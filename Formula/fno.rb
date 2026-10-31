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
  url "https://files.pythonhosted.org/packages/74/63/784d521d4bbee1c6b8c6909fead6364c7a9d6ee3ea323bbbe477fda5d677/fno-0.4.5-py3-none-macosx_10_12_x86_64.whl", using: :nounzip
  # Explicit version: Homebrew's filename version-detect picks "64" out of the
  # x86_64 default-url tag, not 0.2.1. Pin it so `brew info`/upgrade are correct.
  version "0.4.5"
  sha256 "399ac849e508614e6c6865f70ff9520ee0ee3d72721de3ae39dbf9f688f4c9e6"
  license "Apache-2.0"

  # Both macOS arches ship a wheel; the macOS floor is arch-conditional. The
  # arm64 wheel is tagged macosx_15_0, so its Sequoia floor is pinned on arm only
  # (an arm64 Mac on macOS 11-14 would otherwise pass and then hit an ugly pip
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
      # The arm64 wheel is tagged macosx_15_0, so it requires Sequoia; the x86_64
      # default targets macosx_10_12, so this floor is arm-only.
      depends_on macos: :sequoia
      url "https://files.pythonhosted.org/packages/68/23/663b51ac565ab063c381c5fd5423fc1606703948deb87c3537d54a7543ec/fno-0.4.5-py3-none-macosx_15_0_arm64.whl", using: :nounzip
      sha256 "4d742e72f44b564ebd10b1622869b0b12d03c0f4f5f22d9179f69a2f0527dcbe"
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
