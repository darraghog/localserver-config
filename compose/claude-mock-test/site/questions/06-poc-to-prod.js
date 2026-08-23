// Domain: poc-to-prod — "POC to production: cost, latency, reliability".
// Source: notes.txt pages 5-6 (architect track).
BANK.register({
  id: 'poc-to-prod',
  title: 'POC to production: cost, latency, reliability',
  questions: [
    {
      id: 'poc-to-prod-001',
      domain: 'poc-to-prod',
      type: 'single',
      stem:
        'A successful POC ran for three weeks on curated inputs with a friendly pilot group. ' +
        'The sponsor wants to treat its measured spend and error rate as the production ' +
        'forecast. What is the architect\'s objection?',
      options: [
        {
          id: 'a',
          text:
            'A POC establishes capability only. Cost, input distribution and reliability cannot ' +
            'be proven by a POC alone.',
        },
        {
          id: 'b',
          text:
            'The POC numbers are usable once scaled linearly by the expected production call ' +
            'volume, since per-request cost and error rate are properties of the prompt.',
        },
        {
          id: 'c',
          text:
            'The objection is only about cost. Reliability does carry over, because the same ' +
            'model and the same prompt produce the same failure rate at any volume.',
        },
        {
          id: 'd',
          text:
            'There is no objection worth raising — re-deriving the model after a POC that ' +
            'already met its success criteria is process for its own sake.',
        },
      ],
      correct: ['a'],
      explanation:
        'The material states it as a rule in capitals: do not treat the POC as a cost and ' +
        'reliability model. A POC runs at low volume, on clean inputs, with a patient user, and ' +
        'it answers one question — does the system move the business metric. Production runs at ' +
        'business volume on real inputs with users who tolerate neither slowness nor error. ' +
        'That is why the input distribution in particular does not carry over: the real input ' +
        'mix is what the curated set was chosen to avoid.',
      page: 6,
      verify: false,
    },
    {
      id: 'poc-to-prod-002',
      domain: 'poc-to-prod',
      type: 'single',
      stem:
        'A team builds its monthly cost model from the average tokens per request measured in ' +
        'testing, and sets its latency SLA at the median observed response time. Which ' +
        'correction does the material make to both?',
      options: [
        {
          id: 'a',
          text:
            'Model the distribution rather than the average, because a long tail of long ' +
            'requests moves cost disproportionately; and target P95 rather than median, ' +
            'because SLA breaches come from the slow extreme.',
        },
        {
          id: 'b',
          text:
            'Use the average for cost but the maximum observed latency for the SLA, so that ' +
            'the budget stays realistic while the latency commitment is one no request can ' +
            'breach.',
        },
        {
          id: 'c',
          text:
            'Both should use the median, since averages are skewed by outliers and the median ' +
            'is the robust statistic for cost and latency alike.',
        },
        {
          id: 'd',
          text:
            'Neither needs correcting, provided the model is re-measured monthly against real ' +
            'traffic and adjusted when it drifts.',
        },
      ],
      correct: ['a'],
      explanation:
        'The two corrections are the same shape. Cost models should assume a distribution ' +
        'rather than an average, because the long tail of long requests has a ' +
        'disproportionate effect. Latency is similar: median latency can look acceptable while ' +
        'SLA breaches are caused by slower requests at the extreme, so P95 is the better ' +
        'target. Committing to the maximum, as in (b), prices in the worst request ever seen ' +
        'and is not what the material asks for.',
      page: 5,
      verify: false,
    },
    {
      id: 'poc-to-prod-003',
      domain: 'poc-to-prod',
      type: 'single',
      stem:
        'An agent-based research assistant passes its output-quality evals but occasionally ' +
        'runs for hundreds of turns on ambiguous requests, burning budget before returning. ' +
        'What does the material say the eval suite is missing?',
      options: [
        {
          id: 'a',
          text:
            'Evaluation of stopping behaviour, not just output quality — with per-turn token ' +
            'budgets, tool-call counts and explicit stopping criteria as the limits it checks.',
        },
        {
          id: 'b',
          text:
            'Retrieval precision and recall, since an agent that runs long is almost always ' +
            'failing to find the right context on its early turns.',
        },
        {
          id: 'c',
          text:
            'A confidence score on each turn, so that low-confidence turns can be routed to a ' +
            'human reviewer before the agent continues.',
        },
        {
          id: 'd',
          text:
            'Nothing. Long runs on ambiguous input are the expected cost of agency, and the ' +
            'control belongs in the billing alert rather than the eval set.',
        },
      ],
      correct: ['a'],
      explanation:
        'Failure modes are listed per architecture type. For agents the named failure is ' +
        'exceeding limits, and the named controls are per-turn token budgets, tool counts and ' +
        'stopping criteria — with the explicit instruction to evaluate stopping behaviour, not ' +
        'just output quality. The other options are real controls from the same list but ' +
        'belong to other architectures: precision and recall to RAG, and confidence-score ' +
        'routing to the document-processing evaluator-optimizer pipeline.',
      page: 6,
      verify: false,
    },
    {
      id: 'poc-to-prod-004',
      domain: 'poc-to-prod',
      type: 'multi',
      stem:
        'A production service calls Claude with no resilience controls at all. Which two ' +
        'statements match the material\'s treatment of that gap? (Select 2.)',
      options: [
        {
          id: 'a',
          text:
            'With no fallback and no circuit breaker, the model endpoint is a single point of ' +
            'failure with no recovery path.',
        },
        {
          id: 'b',
          text:
            'Retries, fallback chains and circuit breakers are harder to add after the fact, ' +
            'so they should be built in from the start.',
        },
        {
          id: 'c',
          text:
            'Resilience controls are best deferred until real traffic reveals which failures ' +
            'actually occur, since building for unobserved failures is speculative work.',
        },
        {
          id: 'd',
          text:
            'A circuit breaker replaces the need for exponential backoff, because both exist ' +
            'to absorb the same transient errors at the same boundary.',
        },
        {
          id: 'e',
          text:
            'Fallback chains are a cost control rather than a resilience control, since their ' +
            'purpose is routing traffic to a cheaper model tier.',
        },
      ],
      correct: ['a', 'b'],
      explanation:
        'The Cost/Complexity/Risk triad for this section names both: the complexity point is ' +
        'that retries, fallback chains and circuit breakers are harder to add after the fact ' +
        'and should be built in from the start, and the risk point is that a system with ' +
        'neither has the model endpoint as a single point of failure with no recovery path. ' +
        'The three controls sit at different boundaries and do not substitute for one another ' +
        '— exponential backoff at the API call, fallback chains at orchestration, the circuit ' +
        'breaker at the service boundary — and a fallback chain exists so an unavailable ' +
        'endpoint does not raise an error to the user, not to save money.',
      page: 6,
      verify: false,
    },
    {
      id: 'poc-to-prod-005',
      domain: 'poc-to-prod',
      type: 'single',
      stem:
        'An orchestrator fans work out to subagents and synthesises their results. Reviewers ' +
        'find that when one subagent dies, the synthesis still returns a confident answer and ' +
        'the trace shows nothing unusual. Which set of controls does the material prescribe?',
      options: [
        {
          id: 'a',
          text:
            'Define recoverable versus unrecoverable boundaries at the orchestrator, carry a ' +
            'shared trace id across agents, and reconcile coverage at synthesis.',
        },
        {
          id: 'b',
          text:
            'Raise the per-subagent timeout and retry any subagent that fails, so that the ' +
            'synthesis step always receives a full set of results.',
        },
        {
          id: 'c',
          text:
            'Collapse the orchestrator and subagents into a single agent, since fragmented ' +
            'traces are an inherent property of multi-agent designs.',
        },
        {
          id: 'd',
          text:
            'Add a second synthesis pass that re-reads the original request and checks the ' +
            'answer for plausibility before it is returned.',
        },
      ],
      correct: ['a'],
      explanation:
        'This is the orchestrator-workers failure mode almost verbatim: failure boundaries ' +
        'between orchestrators and subagents blur, traces fragment, and a dropped subagent ' +
        'fails silently during synthesis. The three prescribed controls answer those three ' +
        'symptoms in order. Note what reconciling coverage does that retrying does not — it ' +
        'makes the gap visible at synthesis, which is the actual defect here, since the ' +
        'system\'s problem is not that a subagent died but that nothing noticed.',
      page: 6,
      verify: false,
    },
    {
      id: 'poc-to-prod-006',
      domain: 'poc-to-prod',
      type: 'single',
      stem:
        'A team has a stable system prompt reused on every request and a generous max-token ' +
        'cap. They want the single biggest lever on cost and are separately worried about P95 ' +
        'latency. What does the material tell them?',
      options: [
        {
          id: 'a',
          text:
            'Prompt caching has the biggest impact on cost for a stable prompt reused across ' +
            'requests, and a higher max-token cap raises P95 latency.',
        },
        {
          id: 'b',
          text:
            'Lowering the max-token cap is the biggest cost lever, and prompt caching is a ' +
            'latency optimisation whose effect on spend is incidental.',
        },
        {
          id: 'c',
          text:
            'Moving down a model tier is the only lever with material effect on either, since ' +
            'both cost and latency are set by the tier.',
        },
        {
          id: 'd',
          text:
            'The max-token cap is a safety limit with no bearing on latency, because requests ' +
            'that finish early are unaffected by where the ceiling sits.',
        },
      ],
      correct: ['a'],
      explanation:
        'Both statements come straight from the cost-and-latency modelling notes: a higher ' +
        'max-token cap means higher P95 latency, and enabling prompt caching for a stable ' +
        'prompt across requests has the biggest impact on cost. The caching saving scales with ' +
        'the length of the cached prefix and the level of reuse, which is why a stable system ' +
        'prompt on every request is the ideal case. Model tier is one of the three cost-model ' +
        'inputs, alongside call volume and token budget, but it is not the only lever.',
      page: 6,
      verify: false,
    },
  ],
});
