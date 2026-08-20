# Installing the saga plugin

The `saga` Claude Code plugin is distributed via a local marketplace file
already committed to this repo (`.claude-plugin/marketplace.json`). No
publishing step is needed — just clone, register the marketplace, and
install.

## Prerequisites

- Claude Code installed and up to date.
- SSH access to this repo (`git@github.com:thepipeman/saga.git`).

## 1. Clone the repo

```bash
git clone git@github.com:thepipeman/saga.git
```

Put it wherever you keep local tools — it doesn't need to live inside any
project you're working on.

## 2. Add it as a local marketplace

Inside a Claude Code session, run:

```
/plugin marketplace add /path/to/saga
```

Use the absolute path to the folder you just cloned. This registers the
`saga-marketplace` marketplace defined in `.claude-plugin/marketplace.json`.

## 3. Install the plugin

```
/plugin install saga@saga-marketplace
```

## 4. Verify

```
/plugin
```

`saga` should show up as installed and enabled. Try `/init-context` in a
project to confirm the commands are available.

## Keeping it up to date

Pull the latest changes, then update the plugin from the marketplace:

```bash
git -C /path/to/saga pull
```

```
/plugin update saga
```

## Troubleshooting

- If `/plugin marketplace add` fails, double check the path points at the
  repo root (the folder containing `.claude-plugin/`), not a subfolder.
- `/plugin validate /path/to/saga` sanity-checks the manifest if something
  seems off after a pull.
