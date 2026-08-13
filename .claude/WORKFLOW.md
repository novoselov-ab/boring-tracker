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
   trust — see the testing section of [TECH.md](TECH.md).
2. **Run the tests.** They pass before anything else happens.
3. **Review, in a fresh session.** Not the session that wrote the code.
4. **Fix what's worth fixing** (see below).
5. **Re-run the tests.**
6. **Review again**, until a round turns up nothing worth fixing.
7. **Push**, and tick the item off in TODO.md.

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
- Violations of the rules in [PHILOSOPHY.md](PHILOSOPHY.md): a new dependency,
  a tap added to the common path, an animation you have to wait for, anything
  that collects data.
- Failing or missing tests on a data-critical path — day boundaries,
  aggregation, merge, export/import round trips.

**Usually fix**

- Simplifications that *delete* code, especially a concept the app doesn't
  need.
- Performance on the common path — launch, opening the log sheet, saving.

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

Each step runs in its own agterm session with a written brief, so context
stays scoped and the work is inspectable. A brief says what to build, what is
explicitly out of scope, and how to verify. The out-of-scope list matters as
much as the task: it is what stops one step quietly turning into three.
