# Workflow

How each item in [TODO.md](../docs/TODO.md) gets built. One item at a time,
finished properly, before the next one starts.

This is about how the work gets done with agents, not about the app. It lives
here rather than in `docs/` deliberately — `docs/` is the project, and someone
reading it to understand or fork Boring Tracker should not have to wade through
process.

## The loop

For every TODO step:

1. **Implement**, with tests for anything where a silent bug costs data or
   trust — see the testing section of [TECH.md](../docs/TECH.md).
2. **Run the tests.** They pass before anything else happens.
3. **Review, in a fresh session.** Not the session that wrote the code.
4. **Fix what's worth fixing** (see below).
5. **Re-run the tests.**
6. **Review again**, until a round turns up nothing worth fixing.
7. **Push**, and tick the item off in TODO.md.

### Commit messages carry the reasoning

The subject line says what changed; **the body says why, and the body is the
point.** Several decisions in this project have been recovered from commit
messages months after the code stopped explaining itself — what was tried and
rejected, what a number was measured against, which alternative looked better
and wasn't.

A subject line with no body is not a finished commit here, however tidy the
diff. And never claim a measurement, a tool or a test run that did not happen:
see "Always check, not just read" below.

### Every measured claim is a liability

Commit bodies here carry the reasoning, and that has been worth it. But a
sentence asserting a measurement is a promise someone has to check, and the
evidence is now clear about the cost: across this project, **seven claims did
not survive being checked** — an invented test target, a screenshot of the
wrong app, a bisection whose minimal case never reproduced, a 14ms figure that
measured 4–6, four numbers in one document, a chevron credited to the wrong
modifier, and a computed answer that was wrong in the case it called
impossible. One item needed five review rounds, and the loop kept converging on
claims rather than on code.

So: **write fewer measured claims, and only ones you actually measured.** State
the number you took, say how, and leave the rest as ordinary prose. "This is
faster" needs no defence; "this is 41ms" does. Where a claim matters but you
could not verify it, say *unverified* — that is honest and costs nobody a
round.

The lever on this cost is writing fewer of them, not reviewing harder.

### The commit body is the record — the source is not

The rule above is about **commit messages**. It has leaked into source before,
and the result was measured on 2026-08-19: **5,481 of 9,684 non-blank lines in
`BoringTracker/` were comments — 56.6%**, one file at 82.5%. Nothing asked for
that. It came from briefs saying "say why" without saying where.

Where is: the commit body, `docs/`, and the review report. Not the source.

A comment in this repo earns its line only if it answers a **why** the code
cannot: a measured number and where it came from, an alternative that was
tried and failed, a platform behaviour being worked around, a constraint that
is invisible locally. Everything else — restating the next line, narrating
structure, `// MARK`-style ceremony, "we used to" — is cost with no reader.

The cost is not aesthetic. Two sessions have already been spent repairing
comments that had gone false while the code moved on, and one of them nearly
shipped a wrong contrast number that a comment still asserted. **Prose in
source is not free: it has to be kept true, and at volume it cannot be.** A
fact worth keeping is worth putting somewhere it will be re-read — a doc — not
somewhere it will be scrolled past.

### A commit that decides is not a commit that does

Say which one it is in the subject line. "Make teal a fill colour everywhere"
reads as the change; if the diff only adds a paragraph to `docs/TODO.md`, the
subject should say **Decide**, **Note** or **Record**. Two commits on this repo
got that wrong and a later session had to point out that no Swift had moved.

History is read to find out when something happened. A decision and its
implementation are different events, often days apart, and the subject line is
what tells them apart at a glance.

### Pushing is pre-authorised — do not ask

Committing and pushing to `main` is part of finishing a step, not a separate
decision to bring back to the user. **Do not stop to ask for permission to
push.** Push when the tests pass and the review has converged, then report what
you did.

This is a solo repo with no collaborators, everything lands on `main`, and
anything wrong is recoverable from history. Asking each time costs a round trip
and buys nothing.

The repo is public as of 2026-08-19, which changes one thing and not this one:
the suite runs on every push and the README carries its badge, so **a red
`main` is now visible to anyone who looks**. Push freely, but push green —
that is the same rule the loop above already states, with a witness.

Two things still stop and ask, and they are not this: destructive git that
rewrites or discards work (`reset --hard`, `clean -fd`, force pushes,
history rewrites), and anything outward-facing beyond pushing to this repo.

### Why the review is a separate session

An author reviewing their own work re-reads what they meant, not what they
wrote. A session with fresh context reads the diff cold, the way a stranger
on GitHub would, and that is the entire value. Reviewing in-place is faster
and reliably worse.

```
/code-review high
```

**Always `high`, never `ultra`.** `high` gives broad coverage and will raise
things it isn't certain about, which is what this loop wants.

Add `--fix` to apply findings directly to the working tree, but read them
first: applying everything blindly is how a review loop starts making the code
worse.

## What is worth fixing

The loop needs a stopping rule or it ping-pongs on taste forever.

**Always fix**

- Correctness bugs, and anything that can lose, corrupt or silently alter
  stored data.
- Violations of the rules in [PHILOSOPHY.md](../docs/PHILOSOPHY.md): a new
  dependency, a tap added to the common path, an animation you have to wait
  for, anything that collects data.
- Failing or missing tests on a data-critical path — day boundaries,
  aggregation, merge, export/import round trips.

**Usually fix**

- Simplifications that *delete* code, especially a concept the app doesn't
  need.
- Performance on the common path — launch, opening the log sheet, saving.

**Always check, not just read**

A claimed measurement or a cited tool is a fact, and facts get verified. Item 5
recorded a correct timing credited to "the same XCUI tap" — in a repo that has
never had a UI test target. The number was right and its provenance was
invented, which is worse than no number, because it survives scrutiny it never
earned.

So when a commit or a doc says something was measured, reproduce it; when it
names a tool, confirm the tool exists here. This is the failure a code review
is structurally weakest against, since nothing in the diff looks wrong.

**Do not fix**

- Style preferences and naming taste.
- Speculative generality: abstractions for a second case that doesn't exist.
- "Best practice" cited without a concrete failure it would prevent. This app
  has one criterion pair — performance and simplicity — and neither is a
  synonym for convention.

**Stop** when a review round produces nothing in the first two categories. If
three rounds haven't converged, that isn't a review problem — it's a design
problem, and it should come back to the user rather than being polished
further.

## Sessions

Each step runs as its own agent in its own pane with a written brief, so
context stays scoped and the work is inspectable. A brief says what to build,
what is explicitly out of scope, how to verify, and that pushing needs no
permission. The out-of-scope list matters as much as the task: it is what stops
one step quietly turning into three.

Permission mode is **not inherited** — every spawned agent is a fresh `claude`
process — so it is passed explicitly, after `--`:

```sh
herdr pane split --current --direction right \
  --cwd "$(git rev-parse --show-toplevel)" --no-focus
herdr agent start <step> --kind claude --pane <returned-pane-id> \
  -- --permission-mode auto
herdr agent prompt <step> "Read <brief-path> and carry out the task it describes." --wait
```

The brief is passed **by path, not by value.** That was originally because a
long brief broke nested shell quoting; it survives for a better reason — a
brief on disk can be re-read by the agent, quoted in review, and corrected
without re-sending.

The mechanics are in *Spawning a session* below.

### Leave the repo on `main`

A session that creates a branch must return to `main` before it finishes, even
if its work is stuck. One left the repo on a proof branch after its push was
refused, and the next two sessions — and I — spent a while reading a history
that looked wrong because we were not standing where we thought we were.

If a branch has to survive, say so in the report and switch back anyway. The
branch keeps.

### Check the screen is unlocked before planning to drive the UI

A locked Mac takes the accessibility tree and synthesized clicks with it, so
anything needing a touch driver becomes impossible — and it fails *late*, after
the work is built, not when it is planned. Pressed states have gone unverified
three separate times for exactly this reason.

Check first:

```sh
ioreg -n Root -d1 -a | grep -q CGSSessionScreenIsLocked && echo locked || echo unlocked
```

The key is simply absent when unlocked. If it says `locked`, **say so at the
start** and plan around it — screenshots through a launch-argument probe, the
store read directly, reasoning stated as reasoning. Do not build something whose
only verification is a tap you cannot perform, then report it as unverified at
the end.

It is the *lock* that matters, not the display sleeping. `caffeinate -dimsu`
keeps the machine awake; the lock itself is a Settings choice.

### Spawning a session: a pane, then an agent in it

Work runs in **herdr** (0.9.0, `brew install herdr`), not agterm. The agterm
equivalents of everything below are in this file's history at `fe36b89` if the
reasoning is ever wanted; the commands are dead but several of the lessons are
not, and they are carried forward here.

Check you are actually inside herdr before issuing any control command —
`test "${HERDR_ENV:-}" = 1`. Herdr injects `$HERDR_WORKSPACE_ID`,
`$HERDR_TAB_ID` and `$HERDR_PANE_ID` into every managed pane.

Two steps, because a pane and an agent are separate things. `agent start`
needs an existing shell pane at its prompt and never creates layout:

```sh
herdr pane split --current --direction right --cwd "$PWD" --no-focus
# read .result.pane.pane_id from the JSON
herdr agent start work --kind claude --pane w3:p2
```

- **`--no-focus`** keeps the user where they are. Use it for anything the user
  did not ask to be taken to.
- **Split a wide pane right, a tall or narrow one down.** Check first with
  `herdr pane layout --pane "$HERDR_PANE_ID"`; repeated same-direction splits
  make unusable columns.
- **Name the agent.** `[a-z][a-z0-9_-]{0,31}`, unique among live agents. The
  name is how you address it afterwards, and it is cleared when that agent
  exits or is replaced.
- Pass native agent arguments after `--`.

**`agent start` blocks until the agent is ready for input** — it returns with
`interactive_ready: true` and a real `agent_status`, or `agent_not_ready` if
the agent is blocked during startup. That is worth saying plainly because the
old tooling could not do it: under agterm a session that launched perfectly and
then sat at a first-run prompt was indistinguishable from one that was working,
and an hour was lost to exactly that on 2026-08-20. Herdr answers it in the
return value.

The lesson that survives the tooling change: **a process that started is not a
process that is working.** Herdr now checks that for you — but when something
looks stalled, `herdr agent get <name>` and `herdr agent read <name>` are the
two commands that tell you which it is.

### Redirecting a running agent: `agent prompt` actually submits

```sh
herdr agent prompt work "Also update the README." --wait --timeout 120000
```

**This works, and it is the single biggest practical gain over agterm.**
`agent prompt` sends the text and an encoded Enter as one ordered submission,
honouring the pane's bracketed-paste mode, and reports success only after both
are written. Verified on 2026-09-16 with a token round-trip: prompt in, the
agent ran the turn, the token came back out of `agent read`.

Under agterm this was impossible. `session type` put text in front of a session
and the newline never landed — long instructions arrived as a paste block that
nothing could submit, and short ones did not submit either. Every redirect had
to become a fresh session with a brief file, and three instructions were
silently lost before anyone noticed the text sitting at a prompt.

So the old rule — *never steer a running session* — is retired. Steer them.

Still true, and worth keeping:

- **A brief file beats a long prompt for anything with structure.** Not because
  prompting fails now, but because a brief survives being re-read, and a
  session that has to be told its job twice usually needed a better brief.
- **`--wait` is enough for normal work.** It waits for the first settled
  `idle`, `done` or `blocked`. Do not restate those with `--until`; use
  `--until` only for a state-specific wait, such as
  `herdr agent wait work --until blocked`.
- **`--wait` tracks lifecycle state, not your turn.** If the agent was already
  working, the completion of *that* turn can satisfy the wait. Check
  `agent read` rather than assuming the reply you got is the one you asked for.
- **It refuses a blocked agent** with `agent_blocked` before sending anything.
  Inspect the dialog and ask the user rather than answering it blind.
- A timeout or `agent_prompt_stalled` **does not prove the prompt was never
  delivered.** Read before resending.

### Watching an agent, and reading what it did

**The polling watchers are gone.** Under agterm there was no state to ask for,
so progress meant a background script polling `tree --json` every 60 seconds
with a four-consecutive-idle heuristic — which produced false completions every
time a session delegated to a child and sat idle while the child worked. Herdr
has real states: `idle`, `working`, `blocked`, `done`, `unknown`. Wait on them
instead:

```sh
herdr agent wait work --timeout 600000
```

`blocked` is the one worth knowing about: herdr recognises an approval or
question UI natively. That is the failure the old tooling could not see at all.

Reading output:

```sh
herdr agent read work --source recent-unwrapped --lines 120
```

- **`agent read` returns plain text, not JSON**, unlike almost every other
  command. Do not pipe it into a JSON parser.
- Sources: `visible` (viewport), `recent`, `recent-unwrapped` (soft wraps
  joined — prefer it for transcripts), `detection` (what herdr classifies on).
- `--format ansi` only when colour is evidence.
- **If raising `--lines` reveals nothing more**, the agent is on the terminal's
  alternate screen and those rows are unrecoverable. Fallback: ask it to write
  its full response to a file and reply with the path. Only as a fallback.

**`blocked` detection is confirmed.** On 2026-09-16 an agent writing scratch
outside the working directory hit a permission dialog; herdr reported
`blocked`, `agent read` showed the exact modal, `herdr agent send-keys <name>
esc` dismissed it, and `agent prompt` redirected the agent mid-task. Under
agterm the same situation was invisible — the session simply went quiet, and an
hour was lost to one on 2026-08-20.

**Cancel a permission dialog rather than answering it.** Both answers on that
one wrote a persistent user setting affecting every project, which is not
something a pruning task gets to decide. `esc`, then tell the agent to route
around the cause — in that case, keep scratch inside the repo.

Still documentation rather than fact: the alternate-screen read limit and
`agent_prompt_stalled`. Confirm them the first time each matters.

**One hazard carried over from agterm:** `agent prompt` appends to whatever is
already in the pane's input. If a human has half a line typed there, your
prompt concatenates onto it. Read the pane before prompting a session someone
else may be using.

**Clean up what you created and nothing else.** `herdr pane close <id>` for
your own panes. Never `herdr server stop` from an active session, and never
kill the main herdr process — use a named test session for experiments that
need an isolated server.

`.claude/settings.local.json` carries the allowlist for what these sessions
routinely run — xcodegen, xcodebuild, the git subcommands, `herdr`, read-only
inspection. It is machine-local and gitignored. Destructive git
(`reset --hard`, `clean -fd`) is deliberately absent, so it still stops and
asks.
