# Approval Rules

pmaports follows the general
[code review and merge](https://docs.nura.eco/policies-and-processes/development/code-review-and-merge.html)
guidelines, but has its own rules for approving merge requests.

## Testing requirements

Some MRs require testing due to changes affecting multiple devices. In such
cases, the following is required in addition to the approval rules listed
further below.

* **edge**: any person in a MR thread confirms that a MR works.
* **stable**: one person from the team confirms that a MR works. On
  device-specific MRs that the team can't test, instead require confirmation of
  device maintainer that it works.

## Merge request types

### Critical or trivial

Require one approval by any team member.

### Common

#### Package without maintainer

Require two approvals by any team members.

#### Package with one maintainer

Require approval by the package maintainer, and by any other team member.

If the author of the merge request is the package maintainer, require an
approval by any team member.

#### Package with multiple maintainers

Require approval by any package maintainer.

If the author of the MR is a package maintainer, co-maintainers must be given a
48-hour review window (starting when they're notified, typically via the
automated GitLab ping). After this window expires, the merge request can
proceed with any two approvals from team members. The submitting maintainer may
choose to block the merge request to wait for co-maintainer review beyond the
48-hour window if desired.

#### Package with idle maintainer(s)

If no package maintainer replies within two weeks from the time the MR was
opened, then any two approvals are required. When you merge a MR with no
maintainer response, open a
[maintainership status issue](https://gitlab.nura.eco/nura/pmaports/-/issues/new?description_template=Maintainership_status_of_package).

### Move device from category

Moving devices from category is a special operation, see
[device categorization](../packaging/device-categorization).

### Change kconfigcheck requirements

Changes to `kconfigcheck.toml` are a special operation, see
[kconfigcheck](../packaging/kernel-packages/kconfigcheck).

## See also

* [MRs to stable branches](./stable-branches) follow the same approval rules as
to the `main` branch. The separate article describes what changes get done in
MRs to stable branches and the workflow for creating these.
