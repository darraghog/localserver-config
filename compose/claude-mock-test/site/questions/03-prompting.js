// Domain: prompting — "Prompt design, techniques, caching and reuse".
// Source: notes.txt page 1 (prompts as a designed asset, the architectural
// discipline, the start of the template material) and page 2 (scaffolding and
// inherited guardrails, cost/complexity/risk, the one-shot / few-shot /
// chain-of-thought techniques, prompt-model pairing, bias, caching, prompt
// libraries versus skills, and the output contract rule).
BANK.register({
  id: 'prompting',
  title: 'Prompt design, techniques, caching and reuse',
  questions: [
    {
      id: 'prompting-001',
      domain: 'prompting',
      type: 'single',
      stem:
        "A team keeps its assistant's system prompt as a string literal that whoever is on " +
        'call edits when an output looks wrong. Asked to treat the prompt as an asset that ' +
        'is designed for reuse, what does the material say such a prompt has to state?',
      options: [
        {
          id: 'a',
          text:
            'A clear statement of the role and scope, the constraints that must be ' +
            'upheld, and an output contract that the response has to satisfy.',
        },
        {
          id: 'b',
          text:
            'A worked example for every output the assistant may be asked to produce, so ' +
            'that nothing about the task is left to be described in prose.',
        },
        {
          id: 'c',
          text:
            'The reasoning path the model should work through before it answers, since a ' +
            'stated path is what makes a prompt reusable across tasks.',
        },
        {
          id: 'd',
          text:
            'As little as possible about scope, so that the assistant can adapt each ' +
            'response to whatever the caller actually turns out to need.',
        },
      ],
      correct: ['a'],
      explanation:
        'The material treats a prompt as an asset to be designed — a system prompt, a ' +
        'reusable template, guardrails — and names what prompting as an architectural ' +
        'discipline requires: a clear statement of role and scope, the constraints that ' +
        'must be upheld, and an output contract. Examples are a technique applied on top of ' +
        'that structure, not the structure itself, and a reasoning path is matched to tasks ' +
        'that require one rather than being what makes a prompt reusable. Leaving scope ' +
        'open is the ambiguity the material calls a defect multiplied at every step.',
      page: 1,
      verify: false,
    },
    {
      id: 'prompting-002',
      domain: 'prompting',
      type: 'single',
      stem:
        'A prompt at the first stage of a three-stage pipeline leaves the required date ' +
        'format unstated. The reviewer argues that this is a small detail the model will ' +
        'handle sensibly, and that a later stage can normalise whatever comes out. How does ' +
        'the material treat that reasoning?',
      options: [
        {
          id: 'a',
          text:
            'An unstated format is a defect in the prompt, and a pipeline multiplies it at ' +
            'every step, so it belongs in the prompt as a stated output rule.',
        },
        {
          id: 'b',
          text:
            'The gap is tolerable while the pipeline is a prototype, because ambiguity only ' +
            'becomes a defect once a prompt has been promoted to a shared template.',
        },
        {
          id: 'c',
          text:
            'Normalising later is the cheaper route, because a prompt that pins down every ' +
            'detail spends more tokens on every call than a short one does.',
        },
        {
          id: 'd',
          text:
            'This is a Discernment problem rather than a Description one, since the gap ' +
            'will show up when someone checks the outputs against the source signals.',
        },
      ],
      correct: ['a'],
      explanation:
        'The material states it flatly: ambiguity is a defect multiplied at every step — so ' +
        'a chained pipeline is exactly where an unstated output rule does the most damage, ' +
        'and the fix sits in the prompt. Nothing in the material makes the defect ' +
        'conditional on the prompt being shared. The cost claim is backwards: the material ' +
        'says vague prompts mean higher cost, not lower. And prompting discipline — scope, ' +
        'output format, constraints — is the Description competency; Discernment is the ' +
        'later evaluation of what came out.',
      page: 1,
      verify: false,
    },
    {
      id: 'prompting-003',
      domain: 'prompting',
      type: 'single',
      stem:
        'Three teams start from the same system prompt template. Each has pasted it into ' +
        'its own service and rewritten the safety rules in its own wording, keeping only ' +
        'the paragraph that describes the task unchanged. What does the material say a ' +
        'template is for?',
      options: [
        {
          id: 'a',
          text:
            'The fixed scaffolding carries the consistency and safety guarantees, so ' +
            'guardrails are inherited and only the parameterised slots vary per team.',
        },
        {
          id: 'b',
          text:
            'Each team should re-author the guardrails in its own words, because a ' +
            "guardrail only binds the model when it is phrased for that team's own task.",
        },
        {
          id: 'c',
          text:
            'The task paragraph should be the fixed text and the safety rules the slots, so ' +
            'each team can tune those rules to the risk appetite it works under.',
        },
        {
          id: 'd',
          text:
            'Copying the template into each service is the reuse intended, since a prompt ' +
            'library is fragments that engineers assemble by hand.',
        },
      ],
      correct: ['a'],
      explanation:
        'A template is a system prompt with parameterised slots: the fixed scaffolding is ' +
        'what carries consistency and safety guarantees, and the material is explicit that ' +
        'guardrails are inherited, not re-authored. So the variation belongs in the slots ' +
        'and the guardrails belong in the scaffolding — the two options that re-author the ' +
        'rules or turn them into slots invert that. Assembling fragments by hand does ' +
        'describe a prompt library, but edited copies spreading across teams is exactly the ' +
        'ungoverned reuse the material flags as a behavioural drift risk.',
      page: 2,
      verify: false,
    },
    {
      id: 'prompting-004',
      domain: 'prompting',
      type: 'multi',
      stem:
        'A design review is working through the cost, complexity and risk of the prompts ' +
        'behind a new feature. Which two statements match the way the material frames ' +
        'those three? (Select 2.)',
      options: [
        {
          id: 'a',
          text:
            'A vague prompt is a cost problem, because the imprecision in the request shows ' +
            'up as higher cost on every call, not only as a weaker answer.',
        },
        {
          id: 'b',
          text:
            'The risk to name is underspecified guardrails, rather than any single output ' +
            'that the prompt happens to have produced so far.',
        },
        {
          id: 'c',
          text:
            'A vague prompt is the cheaper option, because a shorter instruction spends ' +
            'fewer tokens on each of the calls that use it.',
        },
        {
          id: 'd',
          text:
            'Templates are complexity that has to be justified, because a prompt written ' +
            'for one use case is the simplest thing for a reviewer to work through.',
        },
      ],
      correct: ['a', 'b'],
      explanation:
        'The material sets prompts against the three headings directly: cost is that vague ' +
        'prompts mean higher cost, complexity is that templates are what enable review and ' +
        'improvement, and risk is underspecified guardrails. The cheaper-because-shorter ' +
        'option reverses the cost claim, and the option that treats templates as unjustified ' +
        'complexity reverses the complexity claim — the material puts templates on the side ' +
        'that makes prompts reviewable, not on the side that makes them harder to review.',
      page: 2,
      verify: false,
    },
    {
      id: 'prompting-005',
      domain: 'prompting',
      type: 'single',
      stem:
        "An assistant must never quote a customer's account number back in its reply. The " +
        'team implements the rule by extending the persona paragraph so that it reads "you ' +
        'are a discreet adviser who respects customer privacy". What does the material ' +
        'recommend instead?',
      options: [
        {
          id: 'a',
          text:
            'Build the constraint into the output contract, which is where the material ' +
            'says output rules are enforced, rather than into the role or the tone.',
        },
        {
          id: 'b',
          text:
            'Move the rule into the few-shot examples, so that every example the model is ' +
            'shown happens to demonstrate a reply with the account number left out.',
        },
        {
          id: 'c',
          text:
            'Keep strengthening the persona wording until the rule is unambiguous, since ' +
            'tone is the part of a prompt that a model attends to most closely.',
        },
        {
          id: 'd',
          text:
            'Leave the rule out of the prompt and catch it in review instead, because a ' +
            'rule the model can restate to itself is one it can also be argued out of.',
        },
      ],
      correct: ['a'],
      explanation:
        'The material gives this as a rule: build constraints into the output contract to ' +
        'enforce output rules, rather than into other parts of the prompt such as role or ' +
        'tone rules. A persona paragraph — however strongly worded — is exactly the "other ' +
        'part" it is steering you away from, and examples are too; neither is the contract ' +
        'the output has to satisfy. Dropping the rule from the prompt altogether leaves an ' +
        'underspecified guardrail, which the material names as the risk item for prompts.',
      page: 2,
      verify: false,
    },
    {
      id: 'prompting-006',
      domain: 'prompting',
      type: 'single',
      stem:
        'One step of a workflow pulls the invoice number out of a scanned purchase order — ' +
        'a single bounded task with one right answer. The team proposes adding a ' +
        'chain-of-thought instruction so that the model "reasons carefully". What does the ' +
        'material say?',
      options: [
        {
          id: 'a',
          text:
            'The task is clear and bounded, which is the one-shot case; asking for a ' +
            'reasoning path the task does not require just spends tokens.',
        },
        {
          id: 'b',
          text:
            'Chain-of-thought is the safe default for extraction, since a stated reasoning ' +
            'path is what lets a reviewer audit how a particular value was arrived at.',
        },
        {
          id: 'c',
          text:
            'Few-shot is the technique here, because a bounded task is precisely the case ' +
            'where showing examples beats describing the rule.',
        },
        {
          id: 'd',
          text:
            'The technique choice can wait, because it only starts to matter once the ' +
            'prompt has been paired with a model that is not capable enough for the task.',
        },
      ],
      correct: ['a'],
      explanation:
        'The material matches one-shot to a clear and bounded task, and names the cost of ' +
        'getting this wrong: using chain-of-thought on a task that does not require it ' +
        "wastes tokens. Few-shot is the show-don't-tell case, which is not what a " +
        'single-value extraction needs. And prompt-model pairing is not a reason to defer ' +
        'the technique choice — the material treats the pairing as part of what ships, ' +
        'which makes the technique a design decision rather than a later one.',
      page: 2,
      verify: false,
    },
    {
      id: 'prompting-007',
      domain: 'prompting',
      type: 'single',
      stem:
        'A release-notes prompt has grown into nine paragraphs of prose describing the ' +
        'house style — sentence length, the order of the sections, how a breaking change is ' +
        'phrased. Reviewers still argue about whether the output matches the style. Which ' +
        'technique does the material point to?',
      options: [
        {
          id: 'a',
          text:
            'Few-shot: show the model two or three release notes already written in the ' +
            'house style, instead of describing that style in yet more prose.',
        },
        {
          id: 'b',
          text:
            'Chain-of-thought: have the model set out how it applied each style rule before ' +
            'it writes the notes, so that the reasoning behind the wording is visible.',
        },
        {
          id: 'c',
          text:
            'One-shot with the prose left as it is, because a style guide this detailed has ' +
            'already made the task a clear and bounded one.',
        },
        {
          id: 'd',
          text:
            'More prose, because examples are the part of a prompt that goes stale and has ' +
            'to be maintained if it is to stay current with the house style.',
        },
      ],
      correct: ['a'],
      explanation:
        "Few-shot is the material's show-don't-tell technique, and a house style that " +
        'nine paragraphs have failed to pin down is the case it is for. Chain-of-thought is ' +
        'reserved for tasks where a reasoning path is required, which a formatting task is ' +
        'not, and one-shot is for a task already clear and bounded — which the disagreement ' +
        'shows this is not. That examples require maintenance to stay current is a real ' +
        'point in the material, but it is listed as the complexity cost of the technique, ' +
        'not as a reason to keep describing the style instead.',
      page: 2,
      verify: false,
    },
    {
      id: 'prompting-008',
      domain: 'prompting',
      type: 'single',
      stem:
        'An underwriting assistant has to apply four eligibility rules in sequence, where ' +
        "each rule's outcome decides which rule is read next. The team finds it announcing " +
        'verdicts that do not follow from the rules. Which technique does the material ' +
        'match to this?',
      options: [
        {
          id: 'a',
          text:
            'Chain-of-thought, because this is a task where a reasoning path is required ' +
            'rather than a single bounded answer that can be stated outright.',
        },
        {
          id: 'b',
          text:
            'One-shot, because the four rules are already written down, which makes the ' +
            'task a clear and bounded one as soon as they are pasted into the prompt.',
        },
        {
          id: 'c',
          text:
            'Few-shot, since a handful of decided cases shows the model which verdicts to ' +
            'imitate without the reasoning being spelled out.',
        },
        {
          id: 'd',
          text:
            'A more capable model with the prompt left unchanged, since a prompt is written ' +
            'to a task and ships independently of the model it happens to run on.',
        },
      ],
      correct: ['a'],
      explanation:
        'The material matches chain-of-thought to the case where a reasoning path is ' +
        'required, and a sequence of rules whose outcomes select the next rule is that case. ' +
        "One-shot is for a clear and bounded task and few-shot is show-don't-tell, " +
        'neither of which gets the model to work the sequence through. Swapping the model ' +
        'and keeping the prompt also contradicts the material, which says what ships is a ' +
        'prompt-model pairing rather than a prompt on its own.',
      page: 2,
      verify: false,
    },
    {
      id: 'prompting-009',
      domain: 'prompting',
      type: 'single',
      stem:
        'A prompt was written and tuned against the most capable tier and works well. To ' +
        'cut cost the team plans to point that same prompt at a cheaper model, keeping it ' +
        'byte-for-byte identical so that the change stays "configuration only". What does ' +
        'the material say?',
      options: [
        {
          id: 'a',
          text:
            'What ships is a prompt-model pairing: a less capable model needs more ' +
            'instruction, so the prompt has to be reworked for the tier it now runs on.',
        },
        {
          id: 'b',
          text:
            'The prompt is the portable part of the design, so keeping it identical is what ' +
            'makes a tier change cheap to reverse if the saving disappoints.',
        },
        {
          id: 'c',
          text:
            'The prompt should be shortened for the cheaper model, since a smaller model ' +
            'has less capacity to spend on instructions before it reaches the task itself.',
        },
        {
          id: 'd',
          text:
            'Nothing changes at the prompt layer, because the capability the cheaper tier ' +
            'gives up is recovered by turning on extended thinking for those calls.',
        },
      ],
      correct: ['a'],
      explanation:
        'The material says to ship a prompt-model pairing rather than just a prompt, and ' +
        'gives the reason: less capable models need more instruction. So the prompt is not ' +
        'the portable part and it certainly does not get shorter — the cheaper tier needs ' +
        'more of it, not less. Extended thinking does not stand in for that either; the ' +
        'material treats it as a billing consideration, its intermediate steps counting as ' +
        'output tokens. This is also why the material elsewhere treats a model swap as a ' +
        'release rather than a configuration change.',
      page: 2,
      verify: false,
    },
    {
      id: 'prompting-010',
      domain: 'prompting',
      type: 'multi',
      stem:
        "A prompt asks the model to review a supplier's compliance evidence and say whether " +
        'it holds up. Which two things does the material say keep bias out of a prompt like ' +
        'this one? (Select 2.)',
      options: [
        {
          id: 'a',
          text:
            'Phrase the request neutrally, so that the wording of the prompt does not lean ' +
            'the review toward one finding rather than another.',
        },
        {
          id: 'b',
          text:
            'Balance the examples the prompt carries, so that the set the model is shown is ' +
            'not weighted toward one outcome or another.',
        },
        {
          id: 'c',
          text:
            'State the finding the review is expected to reach, so that the model has a ' +
            'clear position to confirm or to contradict.',
        },
        {
          id: 'd',
          text:
            'Route the review to a more capable tier, on the basis that bias in a prompt is ' +
            'a capability gap that a stronger model absorbs on its own.',
        },
      ],
      correct: ['a', 'b'],
      explanation:
        'The material lists three ways of avoiding bias: neutral phrasing, balanced ' +
        'examples, and a prompt that avoids assuming the answer. Telling the model what ' +
        'finding to expect is that third item inverted — it is precisely assuming the ' +
        'answer, and it is the surest way to get the answer confirmed back. Nor does the ' +
        'material treat bias as something a model tier fixes; it is a property of how the ' +
        'prompt is written, which is why bias sits under risk in the technique section.',
      page: 2,
      verify: false,
    },
    {
      id: 'prompting-011',
      domain: 'prompting',
      type: 'single',
      stem:
        "A support prompt opens with the current timestamp and the ticket id, then the long " +
        "standing instructions and policy text, then the customer's message. The team " +
        'switches caching on and sees no saving at all. What does the material identify as ' +
        'the problem?',
      options: [
        {
          id: 'a',
          text:
            'Caching needs a stable prefix, and prefixing the prompt with dynamic content ' +
            'destroys it — the static content has to be ordered before the dynamic.',
        },
        {
          id: 'b',
          text:
            "The policy text comes before the customer's message, so the variable part " +
            'of the prompt falls inside the cached region and the whole prompt is re-read.',
        },
        {
          id: 'c',
          text:
            'The prompt is simply too short for a cache to pay for itself, so the fix is to ' +
            'raise the TTL until entries survive from one call to the next.',
        },
        {
          id: 'd',
          text:
            'Caching applies to the response rather than to the prompt, so a saving only ' +
            'appears where the same answer is returned to two different callers.',
        },
      ],
      correct: ['a'],
      explanation:
        'The material gives caching two conditions and this prompt breaks both: it requires ' +
        'a stable prefix, and it says not to prefix with dynamic content — content ordering ' +
        'is static before dynamic, with the cache breakpoint falling where the variable ' +
        'content begins. Policy text placed before the customer message is correct ordering, ' +
        'not the fault. TTL selection turns on how often a prompt is used, so it does not ' +
        'repair ' +
        'a broken prefix, and the material treats the cached thing as prompt content rather ' +
        'than as a response.',
      page: 2,
      verify: false,
    },
    {
      id: 'prompting-012',
      domain: 'prompting',
      type: 'single',
      stem:
        'Two prompts in the same service share a cached prefix. One is called a handful of ' +
        'times an hour; the other runs continuously through the working day. An engineer ' +
        'proposes one TTL for both, chosen by how sensitive the prefix text is. On what ' +
        'does the material say TTL selection turns?',
      options: [
        {
          id: 'a',
          text:
            'How often the prompt is used — TTL is selected against the frequency of use, ' +
            'so these two prompts should not be given the same one.',
        },
        {
          id: 'b',
          text:
            'How large the stable prefix is, since a longer prefix is worth holding for ' +
            'longer to recover the cost of writing it.',
        },
        {
          id: 'c',
          text:
            'How sensitive the cached text is, since prefix content under a policy ' +
            'classification should expire as soon as the call that used it has finished.',
        },
        {
          id: 'd',
          text:
            'How many breakpoints the prompt declares, because every breakpoint resets the ' +
            'lifetime of the cached content that precedes it in the prompt.',
        },
      ],
      correct: ['a'],
      explanation:
        'The material lists TTL selection with one criterion beside it: frequency of prompt ' +
        'use. A prompt called continuously and one called a few times an hour therefore do ' +
        'not want the same TTL. Prefix size is a real consideration in the material, but it ' +
        'belongs to whether caching is worth doing at all — call frequency and prefix size ' +
        'both matter there — not to how long an entry lives. Sensitivity and breakpoint ' +
        'counts are not TTL criteria; the breakpoint is simply where the stable prefix ends ' +
        'and uncacheable variable content begins.',
      page: 2,
      verify: false,
    },
    {
      id: 'prompting-013',
      domain: 'prompting',
      type: 'single',
      stem:
        'A quarter-end reconciliation prompt carries a large fixed preamble and runs about ' +
        'a dozen times, once a quarter. The team wants to cache the preamble on the grounds ' +
        'that it is the biggest static block anywhere in the system. What does the material ' +
        'say?',
      options: [
        {
          id: 'a',
          text:
            'The cost of writing to the cache is not always worth it: at this call ' +
            'frequency the misses mean caching adds cost rather than removing it.',
        },
        {
          id: 'b',
          text:
            'Cache it, because prefix size is what decides the benefit and this is by some ' +
            'margin the largest stable prefix that the system has to offer.',
        },
        {
          id: 'c',
          text:
            'Cache it with a short TTL, so that the write cost is paid once a quarter and ' +
            'no entry is left lingering between one run and the next.',
        },
        {
          id: 'd',
          text:
            'The question does not arise, because a preamble that never changes is cached ' +
            'automatically once it has been ordered ahead of the dynamic content.',
        },
      ],
      correct: ['a'],
      explanation:
        'The material is explicit that the cost of writing to cache is not always worth it, ' +
        'and that caching adds cost when there are no hits — call frequency and prefix size ' +
        'both matter. Here the frequency is the binding constraint, so size alone does not ' +
        'carry the case. A short TTL makes it strictly worse, since every run would pay the ' +
        'write cost again with nothing surviving to be hit. And caching is a decision to be ' +
        'made with a breakpoint and a stable prefix, not something that happens by itself ' +
        'once content is ordered correctly.',
      page: 2,
      verify: false,
    },
    {
      id: 'prompting-014',
      domain: 'prompting',
      type: 'single',
      stem:
        'One team owns a summarisation prompt that its own engineers rewrite most weeks as ' +
        'they learn what works, and nothing outside that team calls it. An architect ' +
        'proposes packaging it as a skill so that it is "properly managed". What do the ' +
        "material's considerations indicate?",
      options: [
        {
          id: 'a',
          text:
            'Keep it as a prompt: it is tweaked most weeks, it serves a single team, and ' +
            'the engineers who change it are the ones who own it.',
        },
        {
          id: 'b',
          text:
            'Package it as a skill, because a prompt that changes as often as this one is ' +
            'the case that needs version management the most.',
        },
        {
          id: 'c',
          text:
            'Package it as a skill, because a prompt library is only loose fragments and ' +
            'cannot carry a system prompt template with parameterised slots in it.',
        },
        {
          id: 'd',
          text:
            'Split it, keeping the wording that changes as a fragment while publishing the ' +
            'stable scaffolding as a skill for the wider organisation.',
        },
      ],
      correct: ['a'],
      explanation:
        "All three of the material's considerations point the same way here. " +
        'Repeatability: if a prompt is often tweaked, use a prompt rather than a skill. ' +
        'Distribution: a single team and a single use case means a prompt. Governance: use ' +
        'a prompt where the engineers own it, and reach for a skill when versioning, ' +
        'approval and rollback are needed. Frequent change is the argument against ' +
        'packaging, not for it. A prompt library is described as fragments and templates ' +
        'assembled by engineers, so it does carry templates. And publishing to an ' +
        'organisation nobody in has asked for it invents a distribution need.',
      page: 2,
      verify: false,
    },
    {
      id: 'prompting-015',
      domain: 'prompting',
      type: 'multi',
      stem:
        'A pricing-explanation prompt has been copy-pasted into the repositories of three ' +
        'separate teams, and each copy has since been edited locally. Compliance now ' +
        'wants ' +
        'every change signed off and a way to roll a change back. Which two of the ' +
        "material's points apply? (Select 2.)",
      options: [
        {
          id: 'a',
          text:
            'Ungoverned prompts copied across teams carry a risk of behavioural drift, and ' +
            'versioned reuse is the key control against it.',
        },
        {
          id: 'b',
          text:
            'The governance consideration points to a skill, which packages instructions, ' +
            'scripts and version management as a single unit.',
        },
        {
          id: 'c',
          text:
            'The distribution consideration points to a prompt library, because engineers ' +
            'in each team already own the fragments.',
        },
        {
          id: 'd',
          text:
            'The drift is a model-layer problem rather than a prompt one, so the control is ' +
            'pinning all three teams to a single model tier and route.',
        },
      ],
      correct: ['a', 'b'],
      explanation:
        'The material names this risk directly: ungoverned prompts copied across teams risk ' +
        'behavioural drift, and versioned reuse is the key control. It also gives the ' +
        'governance rule — use a prompt where engineers own it, use a skill where ' +
        'versioning, approval and rollback are needed — and describes a skill as a single ' +
        'unit of governance packaging instructions, scripts and version management. ' +
        'Distribution runs the other way from the option that cites it: beyond a single ' +
        'team and use case, the material points to a skill. And drift here comes from ' +
        'divergent prompt copies, not from the model; the material says behaviour is the ' +
        'same regardless of the delivery route.',
      page: 2,
      verify: false,
    },
  ],
});
