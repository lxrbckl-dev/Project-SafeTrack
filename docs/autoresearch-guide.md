# AutoResearch Guide

> How to use the AutoResearch pattern to optimize Qwen 2.5 7B for this project.

---

## What We Validated

We proved the eval loop works by:
1. Writing 5 question/answer eval cases about the app
2. Feeding the wiki (`docs/wiki.md`) as RAG context into Qwen's system prompt
3. Running each question through Qwen and checking if the response contained the expected keyword
4. Result: 5/5 passed — the wiki provides sufficient context for accurate answers

The eval script lives at `eval/wiki_eval.py`.

---

## Validation Result

We validated the pattern during initial setup: 5/5 evals passed against Qwen 2.5 7B with the current wiki as RAG context. Re-run with `python3 eval/wiki_eval.py`.

## How to Run the Eval

```bash
python3 eval/wiki_eval.py
```

Requires Ollama running with Qwen 2.5 7B loaded and `docs/wiki.md` to exist.

---

## The Full AutoResearch Loop (Post-Build)

Once the app has real features, run this optimization process:

### Phase 1: Optimize the System Prompt

The goal is to improve how Qwen answers user questions by iterating on the system prompt.

**Step 1: Write more eval cases**

Add eval cases to `eval/wiki_eval.py` that cover the actual app's features. Aim for 20-50 cases covering:
- Feature explanations ("How do I create a new X?")
- Navigation help ("Where is the settings page?")
- Error handling ("What happens if sync fails?")
- Edge cases ("Can I use the app offline?")

**Step 2: Establish a baseline**

Run the eval and record the pass rate. This is your starting score.

**Step 3: Iterate on the system prompt**

Modify the system prompt in the eval script (or the wiki content itself). Ideas:
- Add usage examples to the wiki
- Add a FAQ section
- Restructure the wiki to front-load the most common questions
- Add "If the user asks about X, explain Y" instructions to the system prompt

**Step 4: Re-run and compare**

Run the eval after each change. Keep changes that improve the score, discard ones that don't.

**Step 5: Automate (optional)**

Point AutoResearch at the system prompt file. Let it iterate overnight:
```
program.md → tells AutoResearch what to optimize (the system prompt)
wiki.md → the RAG context (AutoResearch can modify this too)
wiki_eval.py → the scoring function
```

AutoResearch modifies the prompt/wiki, runs the eval, keeps improvements, loops.

### Phase 2: Optimize the Agent Prompts

Same pattern, different target. Instead of optimizing Qwen's system prompt, optimize the agent definition files (`tpm.md`, `swe-1.md`, etc.):

**Eval cases:** "Given this task, did the agent produce working code?"
**Target file:** `.claude/agents/swe-1.md` (or any agent)
**Scoring:** Did the code compile? Did tests pass? Did it follow the style guide?

This is what Shopify did — 53% performance improvement across 120 experiments.

---

## Key Principle

> AutoResearch optimizes anything you can score. Define the metric, point it at the file, let it iterate.

- If you can't score it, you can't optimize it
- More eval cases = better signal = better optimization
- The wiki auto-regenerates on every commit, so the RAG context improves as the app evolves
- The eval script runs in seconds — fast feedback loop

---

## Files

| File | Purpose |
|---|---|
| `eval/wiki_eval.py` | Eval script — runs questions against Qwen, scores responses |
| `docs/wiki.md` | RAG context injected into Qwen's system prompt |
| `flutter/assets/wiki.md` | Copy bundled into the Flutter app |
| `.claude/agents/*.md` | Agent definitions (Phase 2 optimization targets) |
