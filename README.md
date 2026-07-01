# GitHubactionNewJuly01

Two ways to **incrementally bump versions and create GitHub releases** from **Conventional Commits** on `main`:

1. **In-house workflow** — `.github/workflows/release.yml` + `scripts/next-version.sh`. Zero third-party action, fully under your control.
2. **release-please** — `.github/workflows/release-please.yml` + `release-please-config.json`. Google's action opens a release PR; you merge and the tag/release happen.

Pick **one** of them and delete the other. The two coexist fine but you'd be creating two release notes per push.

## Project layout

```
.
├── .github/workflows/
│   ├── release.yml             # in-house conventional-commit release
│   └── release-please.yml      # alternative: release-please
├── scripts/
│   └── next-version.sh         # version-bump logic for release.yml
├── release-please-config.json
├── .release-please-manifest.json
├── package.json
└── README.md
```

## Conventional Commit format

```
<type>(<scope>)<!>: <subject>

<body>

<footer>
```

| Type | Bump | Notes |
|---|---|---|
| `feat` | **minor** | New user-visible feature |
| `fix` | **patch** | Bug fix |
| `perf` | **patch** | Performance improvement |
| `refactor` | **patch** | Code change, no feature/fix |
| `revert` | **patch** | Revert a previous change |
| `test` / `build` / `ci` / `docs` / `style` / `chore` | **patch** (release.yml) / hidden (release-please) | |
| **anything with `!` after the type/scope** or a `BREAKING CHANGE:` footer | **major** | The bang is the trigger |
| `chore:` only | **none** (release.yml) / hidden (release-please) | No release produced |

### Examples

```bash
git commit -m "feat(api): add /users search endpoint"
git commit -m "fix(auth): handle expired refresh tokens"
git commit -m "feat!: drop legacy v1 auth (BREAKING CHANGE: clients must re-auth)"
git commit -m "perf(db): add index on orders.user_id"
git commit -m "chore(deps): bump axios"
```

## How `release.yml` works

On every push to `main`:

1. `actions/checkout@v4` with `fetch-depth: 0` (full history so we can scan tags).
2. `scripts/next-version.sh` reads the previous tag (`git describe --tags --abbrev=0`), scans the commits since, and decides the bump.
3. If the bump is `major | minor | patch`, the workflow:
   - Updates `package.json` version (if `package.json` exists),
   - Commits `chore(release): vX.Y.Z` back to `main`,
   - Creates the tag `vX.Y.Z`,
   - Publishes a GitHub Release with the auto-generated changelog.
4. If the bump is `none`, the workflow ends silently (still green).

### Manual bump

```bash
# from the GitHub UI: Actions -> Release -> Run workflow
#   release_type: major | minor | patch | no-bump
#   dry_run:      true|false
```

### First run

If there are no tags yet, `next-version.sh` starts from `package.json`'s `version` (or `0.0.0`) and bumps from there. So the very first push to `main` will produce a `v0.1.0` (or your bump).

## How `release-please.yml` works

On every push to `main`, **release-please** opens (or updates) a single PR titled `:rocket: release`. The PR body is a curated changelog. When you merge that PR:

- the version in `package.json` is updated,
- a tag `vX.Y.Z` is created,
- a GitHub Release is published.

This is the safer, more reviewable model for production repos.

## Minimal test

```bash
git init
git add .
git commit -m "chore: initial commit"
git branch -M main
git remote add origin git@github.com:<you>/<repo>.git
git push -u origin main

# push a feat -> v0.1.0
echo "console.log('hello')" > index.js
git add .
git commit -m "feat: greet the world"
git push

# push a fix -> v0.1.1
sed -i "s/hello/hi/" index.js
git add .
git commit -m "fix: greet properly"
git push

# Watch the Actions tab. You should see v0.1.0, then v0.1.1.
```

## Tag / release flow at a glance

```
commit (feat/fix/...) ── push main ──► workflow ──► bump version ──► commit "chore(release): vX.Y.Z"
                                                                            │
                                                                            ▼
                                                              git tag -a vX.Y.Z  (and push)
                                                                            │
                                                                            ▼
                                                              GitHub Release with changelog
```

## Conventions

- **One logical change per commit** — squashing features into one commit hides them from the changelog.
- **Use the bang `!` for breaking changes** — it's much harder to miss in code review than a `BREAKING CHANGE:` footer.
- **Don't rebase after a tag** — it changes the SHA history and the next bump will misbehave. Use `git pull --rebase` only before tagging, and never edit a pushed tag.
- **Pin third-party actions to a SHA in production** — `@v4` is convenient but `actions/checkout@<sha>` is the secure long-term choice.
