<!--
HOW TO WRITE A RELEASE NOTE (for humans and LLMs)

1. Copy this file to docs/release_notes/<version>.md, e.g. 3.64.0.md
   (the version release-please will tag, without the "v" prefix).
2. Readers are node operators. They deploy the Marketplace with Docker Compose
   and edit `marketplace.env`. Assume they don't know the codebase.
3. Include only changes that matter to a node: new capabilities, changed
   behaviour, new/renamed/removed env variables, required migrations or
   manual steps, and breaking changes. Leave out refactors, tests, CI and
   internal fixes. CHANGELOG.md already lists those.
4. Keep it short. Each "What's new" item is 1–3 sentences. Each "Action
   required" item is a numbered checklist of concrete commands and settings
   that can be copy-pasted.
5. Each "What's new" item gets its own "Action required" entry with the same
   heading. If a change needs no action, write "None." under that heading.
6. For defaults, cron schedules, queue names and the like, use the
   values from the code and docs/marketplace-deployment.md. Don't guess.
   Link to the deployment guide section instead of repeating it.
7. Remove every placeholder (<...>) and every section marked OPTIONAL that
   doesn't apply. Delete this comment block.
-->

# Release <version>

**Released:** <YYYY-MM-DD>
**Action required after upgrade:** <Yes / No / Optional>

## What's new

### <Change title>

<1–3 sentences: what changed and why it matters to the node.>

## Action required

### <Change title>

<Optional one-line context, e.g. "Only if you want to use X.">

1. <Step, e.g. Set the following in `marketplace.env`:>

   ```env
   <VARIABLE>=<value>
   ```

2. <Step, e.g. Restart the affected service:>

   ```bash
   docker compose up -d <service>
   ```

3. <Verification step: how the node can check it works.>

More details: [<Section name>](../marketplace-deployment.md#<anchor>)

<!-- OPTIONAL: include only if something is deprecated or removed. -->

## Breaking changes / deprecations

- <What was removed or changed incompatibly and what to use instead.>
