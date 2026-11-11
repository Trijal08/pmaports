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

If the author of the MR is a package maintainer, co-maintainers who are not [on
hiatus](#package-with-idle-maintainers) must be given a 48-hour review
window[^review-window-start]. After this window expires, the merge request can
proceed with any two approvals from team members. The submitting maintainer may
choose to block the merge request to wait for co-maintainer review beyond the
48-hour window if desired.

(package-with-idle-maintainers)=
#### Package with idle maintainer(s)

Wait two weeks for the maintainer(s) to respond to the MR, unless they are on
hiatus, which is defined as either:
* They are known to be gone without saying when they will come back.
* They are on a planned leave for a month or longer.

If there is no maintainer reponse:
* Require two approvals by any team members.
* If maintainer(s) are not on a planned leave, open a [maintainership status
  issue](https://gitlab.nura.eco/nura/pmaports/-/issues/new?description_template=Maintainership_status_of_package).

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

[^review-window-start]: The review window starts when maintainers are notified,
                        typically via the automated GitLab ping.
