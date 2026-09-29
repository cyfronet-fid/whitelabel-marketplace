---
name: release-notes
description: Use when asked to write, generate or update a node-facing release note in docs/release_notes/, prepare release notes for an upcoming version, or when the user invokes /release-notes.
---

# release-notes

Write a short, checklist-style release note for **node operators** (they deploy with Docker Compose and edit `marketplace.env`). This is not the CHANGELOG. It covers only what a node must know or do after upgrading.

## 1. Read the template first

Read `docs/release_notes/template.md` and follow its instructions and structure. The template is the source of truth. Don't reinvent the format.

## 2. Determine the version and scope

- Last released tag: `git tag --sort=-creatordate | head -1`.
- Changes going in: `git log --oneline <last-tag>..HEAD` (or `<last-tag>..<base-branch>` if asked about a whole release rather than the current branch).
- Version: release-please decides it. Breaking change (`!` or `BREAKING CHANGE`) → major. Any `feat` → minor. Otherwise → patch. State the version you picked and why. If unsure, ask.
- If `docs/release_notes/<version>.md` already exists, add to it instead of overwriting.

## 3. Filter to node-relevant changes

Include new capabilities, behaviour changes, new/renamed/removed env variables, new services/containers, migrations or rake tasks nodes must run, and breaking changes.

Leave out refactors, tests, CI, dependency bumps and internal fixes, unless they change what a node sees or configures.

If nothing is node-relevant, tell the user and don't create a file.

## 4. Get facts from the code

For each change, read the diff (`git show <sha>`) and verify every concrete value you write: env variable names, defaults, cron expressions, service names in docker-compose, UI paths. Good places to look: `config/schedule.yml`, `config/sidekiq.yml`, `ENV.fetch` calls, `docs/marketplace-deployment.md`. Don't guess.

Link to the matching `docs/marketplace-deployment.md` section instead of repeating it. If the deployment guide doesn't document the change yet, say so to the user.

## 5. Write the file

- Create `docs/release_notes/<version>.md` from the template.
- Each "What's new" item gets a matching "Action required" heading. Write "None." when no action is needed.
- Steps are numbered and copy-pasteable, and the last one is a verification step.
- Set the header "Action required after upgrade" to **Yes** if anything is mandatory, **Optional** if only opt-in features need setup, **No** otherwise.
- Use `<placeholders>` for secrets and node-specific URLs. Leave `**Released:** <YYYY-MM-DD>` as a placeholder unless the user gives the date.
- Remove the template's instruction comment, unused OPTIONAL sections and leftover placeholders.

## 6. Update the index

Add a row, newest first, to the table in `docs/release_notes/README.md`: version link, action required (Yes/No/Optional), one-line summary.

## 7. Report back

Tell the user which version you used and why, which commits you included and which you left out, and any placeholders they still need to fill.
