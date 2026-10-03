# lpa-gtk with a persistent SIT backend

Based on Alpine's lpa-gtk 0.4 aport. `sit-session.patch` adds one unprivileged
`sit-lpa --session` helper per application, using private JSON pipes. It keeps
proxy approval alive across slot discovery and lpac operations, serializes
foreground/background work, and closes the helper on EOF or failed transport.
Other explicitly selected lpa-gtk backends retain their upstream behavior.

Requires `exynos-modem-lpa` providing `sit-lpa-session=1`, including version-2
proxy authorization, and the local lpac 2.3.0-r1 stdio fixes. Polkit remains an
optional exynos-modem subpackage. With it installed/enabled, one approval is
bound to the live helper's connections; without it, raw socket permissions
apply. The app automatically selects SIT when its proxy and helper exist.

This upgrades the existing `lpa-gtk`/`lpa-gtk-pyc` packages and keeps the same
application ID, icon and desktop file. The matching exynos-modem-lpa package
removes the former separate SIT desktop entry. Close the old app after upgrade.

Build exynos-modem from the worktree first, then
`pmbootstrap build lpa-gtk --arch aarch64 --force`. Install both lpa-gtk subpackages together. The aport's
`check-session.py` tests real helper subprocesses without GTK or hardware;
Meson's appstream/desktop checks also run during the package build.

Patch base: https://codeberg.org/lucaweiss/lpa-gtk/releases/tag/0.4
(commit 35e272af38405ef1e138d89bce7acb5ac8e305fb).
