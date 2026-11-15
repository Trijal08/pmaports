# Release Timeline

The calendar week (CW) numbers in this document get updated before the next
release cycle starts. Get the current CW with `date +%V`. During the release
cycle we try to follow this plan closely, but it can happen that we run
over the planned CWs.

## 1. Pre-Build

CW 48 <small>(2026-11-23 - 2026-11-29)</small>

Release branches are not yet in feature freeze, but we should avoid making
major changes to main.

Team:
* Create the [infrastructure
  issue](https://gitlab.nura.eco/nura/pmaports/-/issues/new?description_template=Release_Infrastructure)
  (which has more detailed tasks for the team for each phase, the document here
  just gives a rough overview).
* Create the release branch in pmaports.
* Start building of binary packages early, so we can get through it for sure.

## 2. Branch

CW 49 <small>(2026-11-30 - 2026-12-06)</small>

The release branch is in **feature freeze**:

We can cherry pick fixes where it makes sense, but can't add features to the
release branch anymore (exceptions can be made if there is a good reason).

Team:
* Rebase the release branch on main once
* Build binary packages and images (configure BPO for that)

## 3. Test

CW 50 <small>(2026-12-07 - 2026-12-13)</small>

Maintainers:
* Test your devices and UIs (test yourself if you can and/or coordinate with
  the [Testing Team](https://wiki.nura.eco/wiki/Testing_Team))
* Report back in the issue ([template for devices](https://wiki.nura.eco/wiki/Kernel_upgrade_testing#Stable_release_testing))
* Fix stuff that is broken by creating MRs against pmaports main and assigning
  the `backport-to-YY.MM` label

## 4. Release

CW 51 <small>(2026-12-14 - 2026-12-20)</small>

Team:
* Write the release blog post.

Team + Maintainers:
* Celebrate with party hats and get wasted.
