// Domain: sizing-roi — "Use-case sizing, feasibility and ROI".
// Source: notes.txt pages 6-8 (architect track).
BANK.register({
  id: 'sizing-roi',
  title: 'Use-case sizing, feasibility and ROI',
  questions: [
    {
      id: 'sizing-roi-001',
      domain: 'sizing-roi',
      type: 'single',
      stem:
        'A feasibility assessment covers whether the task tolerates probabilistic generation, ' +
        'whether the knowledge exists outside training data, and whether the instructions are ' +
        'specific enough to be verifiable. Which property has been left out, and what ' +
        'compensating controls belong to it?',
      options: [
        {
          id: 'a',
          text:
            'Working memory — whether the aggregate input exceeds the context window — ' +
            'answered with chunking, progressive loading, or a pipeline architecture.',
        },
        {
          id: 'b',
          text:
            'Latency, answered by caching the stable prefix and capping max tokens so P95 ' +
            'stays inside the SLA.',
        },
        {
          id: 'c',
          text:
            'Cost, answered by the monthly projection and a sensitivity analysis over call ' +
            'volume and token distribution.',
        },
        {
          id: 'd',
          text:
            'Autonomy, answered by choosing between an augmented LLM, a workflow, and an ' +
            'agent according to the tightest constraint.',
        },
      ],
      correct: ['a'],
      explanation:
        'The assessment covers four AI properties — next-token prediction, knowledge, working ' +
        'memory and steerability — and the material notes that working memory is the one most ' +
        'often overlooked, which is exactly the omission here. Its question is whether all ' +
        'inputs fit in the context window or the aggregate exceeds it, and its controls are ' +
        'chunking, progressive context loading, summarisation turns and pipeline ' +
        'architecture. Cost, latency and autonomy are all real concerns elsewhere in the ' +
        'material, but they are not among the four properties this assessment enumerates.',
      page: 7,
      verify: false,
    },
    {
      id: 'sizing-roi-002',
      domain: 'sizing-roi',
      type: 'single',
      stem:
        'A design needs the current status of an order, the contents of a stable policy manual, ' +
        'and occasional statements about contested industry claims. Which mapping does the ' +
        'material give?',
      options: [
        {
          id: 'a',
          text:
            'Tool call for the live order status, RAG for the stable policy manual, and an ' +
            'explicit uncertainty flag on the contested claims.',
        },
        {
          id: 'b',
          text:
            'RAG for all three, with the order status re-indexed frequently enough that the ' +
            'retrieved copy stays close to live.',
        },
        {
          id: 'c',
          text:
            'Tool calls for all three, since a tool call always returns the freshest data and ' +
            'retrieval only adds an indexing step that can go stale.',
        },
        {
          id: 'd',
          text:
            'RAG for the live order status and the contested claims, and a tool call for the ' +
            'policy manual, since only the manual has a stable canonical source to call.',
        },
      ],
      correct: ['a'],
      explanation:
        'The knowledge property splits by volatility: RAG for stable knowledge, a tool for ' +
        'live-state data, and flag uncertainty on contested claims. Option (b) is the common ' +
        'mistake the material names directly — using retrieval as a substitute for live state ' +
        '— and the reason the RAG failure-mode note tells teams to separate live-state queries ' +
        'from static-knowledge queries. Re-indexing more often narrows the staleness window ' +
        'without closing it.',
      page: 7,
      verify: false,
    },
    {
      id: 'sizing-roi-003',
      domain: 'sizing-roi',
      type: 'single',
      stem:
        'An assessment returns "feasible with constraints": the design holds provided documents ' +
        'stay under a stated size and volume stays under a stated ceiling. The delivery team ' +
        'wants to record the verdict and leave the constraints out of the SOW as implementation ' +
        'detail. What is wrong with that?',
      options: [
        {
          id: 'a',
          text:
            'The constraints are part of the design, and a feasible-with-constraints verdict ' +
            'becomes infeasible the moment they are violated in production — so the SOW must ' +
            'carry the boundary conditions.',
        },
        {
          id: 'b',
          text:
            'Nothing, provided the constraints are monitored in production and the team is ' +
            'alerted when either ceiling is approached.',
        },
        {
          id: 'c',
          text:
            'The verdict itself is the problem: only "feasible as scoped" or "not feasible" ' +
            'should ever be recorded, since a conditional verdict cannot be contracted against.',
        },
        {
          id: 'd',
          text:
            'The constraints belong in the eval suite rather than the SOW, because that is ' +
            'where violations would actually be caught before release.',
        },
      ],
      correct: ['a'],
      explanation:
        'Feasibility is a verdict plus constraints, and the scoping sequence ends with ' +
        'boundary conditions being written into the SOW for exactly this reason. The named ' +
        'risk is that a feasible-with-constraints verdict becomes infeasible when the ' +
        'constraints are violated in production; the material\'s answer is that constraints ' +
        'are part of the design, not a caveat attached to it. Monitoring and evals are useful, ' +
        'but neither creates the contractual record that the verdict was conditional.',
      page: 7,
      verify: false,
    },
    {
      id: 'sizing-roi-004',
      domain: 'sizing-roi',
      type: 'multi',
      stem:
        'An ROI map projects that a claims workflow moves from 45 analyst-minutes per claim to ' +
        'zero, using an industry benchmark for the baseline and the average tokens per request ' +
        'for run cost. Which two errors from the material\'s list does this commit? (Select 2.)',
      options: [
        {
          id: 'a',
          text:
            'Assuming full automation when a human-in-the-loop step is required, which ' +
            'overstates the value of the post-deployment state.',
        },
        {
          id: 'b',
          text:
            'Estimating the baseline from an industry figure instead of measuring it from ' +
            'the business unit\'s own operational data.',
        },
        {
          id: 'c',
          text:
            'Expressing the baseline in analyst-minutes rather than in currency, leaving the ' +
            'gain incomparable to the run cost.',
        },
        {
          id: 'd',
          text:
            'Projecting the post-deployment state in the same unit as the baseline, rather ' +
            'than in whichever unit suits each.',
        },
        {
          id: 'e',
          text:
            'Treating build cost separately from run cost, when the value case needs a ' +
            'single blended figure.',
        },
      ],
      correct: ['a', 'b'],
      explanation:
        'Three key ROI map errors are listed: a baseline estimated rather than measured (from ' +
        'a lack of operational data), an assumption of full automation with no HITL, and run ' +
        'cost estimated from an average rather than from the sizing distribution. This map ' +
        'commits the first two — and the third as well, though it is not among the options ' +
        'offered. The other three options invert instructions the material actually gives: ' +
        'name the baseline in a business unit and predict the post-deployment state in that ' +
        'same unit, and treat build cost separately from run cost so that payback can be ' +
        'computed.',
      page: 8,
      verify: false,
    },
    {
      id: 'sizing-roi-005',
      domain: 'sizing-roi',
      type: 'single',
      stem:
        'How does the material define the value of a deployment, and how does the payback ' +
        'period relate to it?',
      options: [
        {
          id: 'a',
          text:
            'Value is the operational gain minus the run cost from the sizing model; payback ' +
            'is the time for accumulated gain to cover build and run cost.',
        },
        {
          id: 'b',
          text:
            'Value is the operational gain minus build and run cost together; payback is ' +
            'reached at the point that figure first turns positive in a single month.',
        },
        {
          id: 'c',
          text:
            'Value is the gross operational gain, with cost handled separately in the budget; ' +
            'payback is the time for that gain to exceed the build cost.',
        },
        {
          id: 'd',
          text:
            'Value is the reduction in headcount attributable to the deployment; payback is ' +
            'the point at which that reduction is realised in the operating plan.',
        },
      ],
      correct: ['a'],
      explanation:
        'The value of the deployment is the operational gain above the baseline, less the run ' +
        'cost taken from the sizing model. Build cost is treated separately, and that is what ' +
        'payback covers: the time taken for accumulated operational gain to cover build and ' +
        'run cost. Keeping the two apart is what makes the sensitivity analysis work, since a ' +
        'change in token budget or model tier updates both the cost ceiling and the value ' +
        'case.',
      page: 7,
      verify: false,
    },
    {
      id: 'sizing-roi-006',
      domain: 'sizing-roi',
      type: 'single',
      stem:
        'Asked to scope a claims use case, an architect writes down "reduce claim handling ' +
        'time" and "improve customer satisfaction" as the first step of the capability list. ' +
        'What has gone wrong?',
      options: [
        {
          id: 'a',
          text:
            'Those are goals, not capabilities. The step calls for the capabilities to be ' +
            'performed — extract fields, look up coverage, route the claim — because the ' +
            'next step assigns each one to Claude, a system, or a human.',
        },
        {
          id: 'b',
          text:
            'Nothing is wrong with the entries themselves, but they belong in step two rather ' +
            'than step one, after the architecture sketch exists to attach them to.',
        },
        {
          id: 'c',
          text:
            'The entries are too narrow. Scoping starts from the business requirement as a ' +
            'whole, and decomposition happens only once boundary conditions are known.',
        },
        {
          id: 'd',
          text:
            'The problem is sequencing: capability comes after constraints such as volume, ' +
            'latency and input size, so nothing should be listed until those are fixed.',
        },
      ],
      correct: ['a'],
      explanation:
        'Step one of scoping is turning the business requirement into a capability list, and ' +
        'the material is explicit that these are capabilities to be performed, not goals — its ' +
        'own examples are extracting fields, looking up coverage, routing a claim, drafting a ' +
        'notification. The reason is step two: each capability has to be placed with Claude, ' +
        'an existing system, or a human in the loop, and a goal cannot be placed. Option (d) ' +
        'echoes a real warning — do not address capability before constraints such as volume, ' +
        'latency and input size — but that warning is about the feasibility conversation, not ' +
        'about whether the capability list may be written.',
      page: 6,
      verify: false,
    },
  ],
});
