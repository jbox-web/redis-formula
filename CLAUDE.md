# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

The `jbox-web` hard fork of `saltstack-formulas/redis-formula`, reworked on
`master` since 2026-10-18. Only `redis.server` on Debian 11 and 13, with the
distribution's `redis-server` package, is used and tested; everything else
(sentinel, multi-instance, other OS families) is inherited from upstream and
untested.

## Commands

```bash
bundle install
bin/kitchen list                                  # 3 instances: default-<platform>
bin/kitchen test default-debian-13-3008-2
pre-commit run --all-files                        # rubocop and yamllint lint the whole tree
```

On an arm64 Mac, redis cannot start in the emulated amd64 container
(`226/NAMESPACE`): converge works locally, but the service, port and
`redis-cli ping` controls only pass in GitHub CI.

## Architecture — this formula does NOT follow the template layout

Unlike most saltstack-formulas, it predates the `template-formula` layout:

- **No `tplroot`.** States and templates hardcode `redis/...` paths
  (`redis/map.jinja`, `salt://redis/files/...`); only `_mapdata/init.sls`
  derives `tplroot`.
- **Short merge chain.** `map.jinja` exports `redis_settings`, built from
  `defaults.yaml` <- `osfamilymap.yaml` <- `redis:lookup`, then merged with the
  whole `redis` pillar. There is no `osarchmap`/`osmap`/`osfingermap` level
  (`osfingermap.yaml` was dropped on purpose).
- **No `package/config/service` split.** `redis` = `redis.common` (the package)
  + `redis.server` -> `server/install.sls` (config, `root_dir`, systemd drop-in,
  service, sysctl). `redis.clean` -> `server/clean.sls`. `instances.sls` and
  `sentinel.sls` are standalone, not included by `redis`.
- **No TOFS.** The config source is
  `salt://redis/files/redis-<cfg_version>.conf.jinja` (`cfg_version` `3.2` by
  default, `3.0` on RedHat), or the pillar's `source_path` when set.
- **Templates import `map.jinja` themselves.** The single-instance and sentinel
  templates read `redis_settings` from the map, not from the state context;
  only `redis-3.2.conf.multi.jinja` takes it from `defaults:` in
  `instances.sls` (where `_default` values are `.format(name=...)`-expanded per
  instance).
- **Same change in every config template.** A rendering fix (e.g. `bind` as a
  string or a list) must be carried into all `redis/files/*.conf.jinja`,
  sentinel included — the 2026-10-18 rework touched 8 of them.

### Invariants of the 2026-10-18 rework

- `redis_config` is `0640`, owned by the redis user and group, with
  `show_changes: False`: the file may carry `requirepass` (pillar key `pass`).
- `redis_root_dir` creates `root_dir` (`0750`): redis refuses to start without
  its `dir`.
- `systemd_rw_root_dir` (true on Debian) adds `redis_systemd_dropin`
  (`ReadWriteDirectories=-<root_dir>`): the packaged unit runs with
  `ProtectSystem=strict`, so RDB snapshots fail elsewhere without it.
- Keep the state IDs `redis_root_dir` and `redis_systemd_dropin` stable:
  deployments may reference them in requisites.
- Source/archive installation is gone (`install_from`, `bin`,
  `python_dev_package` no longer exist).

## Tests

One suite, `default`: `state_top` runs `redis._mapdata`, `redis.common`,
`redis.server` with `test/salt/pillar/default.sls` (list `bind`, `root_dir:
/data/redis`, a test-only `pass`). The controls in
`test/integration/default/controls/redis_spec.rb` assert on that pillar
(conf mode, `bind`, `dir`, drop-in, `redis-cli -a ... ping`), so a pillar
change must be reflected there. There are no `_mapdata` reference dumps in this
fork.
