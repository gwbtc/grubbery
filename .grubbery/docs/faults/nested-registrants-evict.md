# Nested registrants evict and strip each other

**Problem.** Two defects in the [usergroups registry](#usergroups.md), neither
of which logs anything. `%register` prunes every row whose prefix is an
ancestor or descendant of the new one:

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 7759-7772
```

The root registers `/`, which is a prefix of everything, so each rebuild
evicts every other registrant and every delegated grant is refused as not
registered. Then `+replace-roads` removes every road under the sender's prefix
before adding its own:

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 7965-7978
```

A desk nested inside the shell's prefix has its roads erased each time the
shell re-applies its grant, which it does whenever a desk's share state
changes.

**Proposed solution.** Eviction fires only on an exact re-claim of the same
prefix, the stale-row case the rule exists for. `+replace-roads` touches only
the sender's own rows.

**Status.** Open, [proposed](https://github.com/gwbtc/grubbery/pull/61).
