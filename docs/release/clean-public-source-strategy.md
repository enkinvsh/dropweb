# Clean Public Source Strategy

This document records the safe public repository strategy for Dropweb. This task does not rewrite history, publish a repository, create a tag, push a branch, or change any release asset.

## Recommended path

Use a clean public branch, built as an orphan-style initial import after v0.7.1 verification passes. The public import should contain the reviewed source tree and public release docs only, with the same source that matches the shipped v0.7.1 Play Submission Candidate.

The clean import must preserve GPL obligations and upstream credit:

1. Keep `LICENSE` with GPL-3.0 text.
2. Keep `NOTICE.md` naming Dropweb as a modified GPL-3.0 fork of FlClashX and listing FlClashX, FlClash, and mihomo.
3. Keep `ATTRIBUTIONS.md` with the same core project attribution and exact-version source availability rule.
4. Keep README wording that openly says Dropweb is a GPL-3.0 fork and links to `NOTICE.md` and `ATTRIBUTIONS.md`.

This gives the owner a clean public source surface without pretending the project has no fork lineage.

## What we will not do

We will not hide GPL or fork origin. Dropweb remains a GPL-3.0 fork of FlClashX, with FlClash and mihomo lineage preserved.

We will not delete `NOTICE.md`, `ATTRIBUTIONS.md`, `LICENSE`, or README attribution to make the repository look original.

We will not rewrite or force-push `main` without explicit owner approval, a backup branch or tag, and a final review of the exact tree to be published.

We will not use history cleanup to remove required license notices, upstream credit, or exact-version source availability evidence.

## Current branch state

Branch `play-submission-clean-public-source` contains clean docs and runtime surface work for the public source tree.

Completed work on this branch includes GPL attribution notices, Play submission drafts, README cleanup, public changelog cleanup, quarantine of internal docs from the public tree, runtime wording cleanup, and app-facing Play policy links.

Task 9 is still blocked on owner-input placeholders. Missing owner inputs include organization or DUNS status, Privacy Policy URL, support contact, account deletion URL, backend retention answers, reviewer demo access, and demo video status. Do not claim Task 9 is complete until those values are supplied or the owner explicitly approves publishing owner-review-required drafts.

## Future owner-approved operations

The commands below are examples for later owner-approved work. They were not executed by this task.

Before any destructive public history change, create a recoverable backup reference:

```bash
GIT_MASTER=1 git branch backup/pre-public-source-main main
GIT_MASTER=1 git tag backup/pre-public-source-v0.7.1 main
```

Prepare a clean orphan branch only after owner approval and v0.7.1 verification:

```bash
GIT_MASTER=1 git switch --orphan public-source-v0.7.1
GIT_MASTER=1 git add LICENSE NOTICE.md ATTRIBUTIONS.md README.md README_EN.md CHANGELOG.md docs lib android macos windows linux pubspec.yaml pubspec.lock setup.dart
GIT_MASTER=1 git commit -m "docs: publish v0.7.1 public source import"
```

Compare the clean public tree against the verified release source before any push:

```bash
GIT_MASTER=1 git status --short
GIT_MASTER=1 git diff --stat main..public-source-v0.7.1
```

Push or replace a public branch only after explicit owner approval. If the owner approves replacing an existing remote branch, use force-with-lease, not force:

```bash
GIT_MASTER=1 git push origin public-source-v0.7.1
GIT_MASTER=1 git push --force-with-lease origin public-source-v0.7.1:main
```

The safer default is an orphan import to a new public branch or new repository, followed by owner review, rather than a force rewrite of an existing public `main` branch.

## Release recommendation

Treat v0.7.1 as a Play Submission Candidate only after the owner fills the Play docs and all verification passes.

Do not publish direct APK links, Play submission assets, GitHub releases, tags, or public branch rewrites until the exact-version source tree is ready and the owner has approved the final public repository strategy.
