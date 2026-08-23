// Domain: ai-fluency — "AI Fluency and the 4 D's".
// Source: notes.txt page 1 (the framework itself) and its reappearances on
// pages 2, 10, 12, 13, 16 and 17.
BANK.register({
  id: 'ai-fluency',
  title: "AI Fluency and the 4 D's",
  questions: [
    {
      id: 'ai-fluency-001',
      domain: 'ai-fluency',
      type: 'single',
      stem:
        'A reviewer signs off a system prompt for a claims-summarisation service: the role ' +
        'is stated, the output format is specified, and every constraint the prompt does ' +
        'contain is accurate. What does the material say the Description competency still ' +
        'asks of that review?',
      options: [
        {
          id: 'a',
          text:
            'Read the prompt for what it does not say, because the model will improvise the ' +
            'gaps it leaves in scope, format and constraints.',
        },
        {
          id: 'b',
          text:
            'Add worked examples to the prompt, since examples carry the exact shape of an ' +
            'answer that a written description does not reach on its own.',
        },
        {
          id: 'c',
          text:
            'Defer the judgement to Discernment, since a prompt can only be assessed from ' +
            'the outputs it produces once it is running against real work.',
        },
        {
          id: 'd',
          text:
            'Re-author the guardrails in this prompt rather than inheriting them from the ' +
            'fixed scaffolding of the template it came from.',
        },
      ],
      correct: ['a'],
      explanation:
        'Description is prompting discipline — scope, output format and constraints — and ' +
        'the material states the review habit directly: assess prompts for what they do not ' +
        'say, because models will improvise gaps. Ambiguity is a defect multiplied at every ' +
        'step. Examples are a separate technique and do not close an unstated constraint. ' +
        'Discernment is critical evaluation of output, which is a different competency from ' +
        'designing the request. And the material treats fixed scaffolding as carrying ' +
        'guardrails that are inherited, not re-authored.',
      page: 2,
      verify: false,
    },
    {
      id: 'ai-fluency-002',
      domain: 'ai-fluency',
      type: 'single',
      stem:
        'A reviewer works through the flagged outputs of a support assistant and records ' +
        'each one as either fine or not fine; the weekly tally goes to the product owner. ' +
        'What does the material say the Discernment competency requires here?',
      options: [
        {
          id: 'a',
          text:
            'Sort each output into acceptable, needs revision or needs override, and feed ' +
            'that judgement back into evals and monitoring.',
        },
        {
          id: 'b',
          text:
            'Report the not-fine proportion as the error rate in the observability stack, ' +
            'alongside latency and task success rate.',
        },
        {
          id: 'c',
          text:
            'Send every not-fine output through a pre-action approval gate, so that nothing ' +
            'reaches a user until a second reviewer has cleared it.',
        },
        {
          id: 'd',
          text:
            'Replace the reviewer with an LLM judge scoring each output against a rubric, ' +
            'since a binary human tally is both expensive and noisy.',
        },
      ],
      correct: ['a'],
      explanation:
        'The material gives Discernment two parts: classify outputs as acceptable, needing ' +
        'revision or needing override, and feed that judgement back into evals and ' +
        'monitoring. A binary tally collapses the middle category and the loop back into the ' +
        'evals is what the tally is missing. Error rate is an observability metric about the ' +
        'system, not a judgement about an individual output. A pre-action gate is a ' +
        'human-review placement decision, not output classification. And it is LLM-as-judge ' +
        'that the material calls expensive and noisy, reserving it for open-ended output.',
      page: 10,
      verify: false,
    },
    {
      id: 'ai-fluency-003',
      domain: 'ai-fluency',
      type: 'single',
      stem:
        'A lending assistant stores only its final decision for each application. A ' +
        'compliance reviewer is asked to look through those records for skewed or ' +
        'unjustified outcomes. Why does the material say this will not work?',
      options: [
        {
          id: 'a',
          text:
            'Discernment lets a reviewer recognise a skewed outcome, but the transparency ' +
            'record of inputs and rationale is what makes that possible.',
        },
        {
          id: 'b',
          text:
            'Unfairness enters through the retrieval corpus, the prompt framing and ' +
            'downstream routing, so reviewing decisions after the fact can never detect any ' +
            'of it.',
        },
        {
          id: 'c',
          text:
            'The record a reviewer needs is the build team debug trace, so a review of this ' +
            'kind can only be carried out by an engineer from the build team.',
        },
        {
          id: 'd',
          text:
            'Each stored decision needs a confidence estimate attached, since confidence is ' +
            'what establishes whether a given outcome was justified.',
        },
      ],
      correct: ['a'],
      explanation:
        'The material pairs the two directly: Discernment lets a reviewer recognise a skewed ' +
        'or unjustified outcome, and the transparency record is what makes that recognition ' +
        'possible. An affected user needs inputs and rationale; a regulator needs inputs, ' +
        'outputs and decision paths. Naming where unfairness enters does not make review ' +
        'futile — an unmeasured injection point is what hides unfairness. The full trace is ' +
        'the build team audience, not the only admissible record. And confidence is what ' +
        'determines whether a decision is routed to a human, not what shows an outcome was ' +
        'fair.',
      page: 12,
      verify: false,
    },
    {
      id: 'ai-fluency-004',
      domain: 'ai-fluency',
      type: 'single',
      stem:
        'An agent workflow pauses for human approval at every tool call. Six weeks in, ' +
        'reviewers are approving almost everything within seconds of it appearing in the ' +
        'queue. What does the material prescribe?',
      options: [
        {
          id: 'a',
          text:
            'Drive the review away from per-step approvals and towards higher-value ' +
            'checkpoints such as plan review or exception handling.',
        },
        {
          id: 'b',
          text:
            'Keep the per-step gates and give reviewers more context, since the fatigue ' +
            'comes from thin approval screens rather than from gate count.',
        },
        {
          id: 'c',
          text:
            'Move the workflow to post-action audit, which the material recommends wherever ' +
            'reviewers approve faster than they can read.',
        },
        {
          id: 'd',
          text:
            'Drop the human gate and rely on sampled review, since sampling monitors the ' +
            'overall system rather than one scenario at a time.',
        },
      ],
      correct: ['a'],
      explanation:
        'Diligence is the competency behind human review, and the material names this ' +
        'failure and its fix: drive review activity away from per-step approvals to ' +
        'higher-value checkpoints — plan review or exception handling — to avoid consent ' +
        'fatigue. Reviewers do need context (inputs, outputs, why it was flagged), but ' +
        'adding it under the same volume of gates leaves the volume untouched. Post-action ' +
        'audit is chosen for reversible and low-cost decisions, not because a queue is ' +
        'moving quickly. And Diligence in deployment means maintaining explicit ' +
        'accountability checkpoints, so removing the checkpoint altogether is the erosion ' +
        'the material warns about.',
      page: 13,
      verify: false,
    },
    {
      id: 'ai-fluency-005',
      domain: 'ai-fluency',
      type: 'single',
      stem:
        'A firm publishes an AI usage policy and checks conformance in an annual audit. ' +
        'Between audits, teams use Claude as they see fit, and the policy has not been ' +
        'revised since it was written. What does the material say about this arrangement?',
      options: [
        {
          id: 'a',
          text:
            'A policy followed only while someone is watching is not governance, and the gap ' +
            'between use and policy needs regular review.',
        },
        {
          id: 'b',
          text:
            'The arrangement holds provided the annual audit samples enough requests for the ' +
            'sample size to support the conclusion that it draws.',
        },
        {
          id: 'c',
          text:
            'Governance of this kind belongs to risk and compliance, so what practitioners ' +
            'do between two audits sits outside its remit.',
        },
        {
          id: 'd',
          text:
            'The gap closes once every use case has been classified as fully appropriate, ' +
            'appropriate with a human review gate, or inappropriate.',
        },
      ],
      correct: ['a'],
      explanation:
        'The material is blunt about it: policies followed only when someone is watching is ' +
        'not governance. The diligence gap is where Claude action diverges from policy, and ' +
        'because policies and capabilities both evolve, identifying those gaps takes regular ' +
        'review. Sample size is a watch-out for declaring an A/B outcome, not a substitute ' +
        'for the habit. Governance is presented as a practitioner skill rather than a policy ' +
        'binder owned elsewhere. And screening use cases into the three classifications is a ' +
        'point-in-time act, which is exactly what an unrevised annual cycle already does.',
      page: 17,
      verify: false,
    },
    {
      id: 'ai-fluency-006',
      domain: 'ai-fluency',
      type: 'multi',
      stem:
        'A team screens a proposed use case against the four Delegation criteria — ' +
        'reversibility, consequence of error, the human element, and accountability — and ' +
        'records that none of them blocked it. Which two further steps does the material ' +
        'require before that screening is defensible to risk and compliance? (Select 2.)',
      options: [
        {
          id: 'a',
          text:
            'Identify which of the criteria are load-bearing in this case, since not all ' +
            'four of them carry the classification.',
        },
        {
          id: 'b',
          text:
            'Record one of the three classifications, defining a formal gate for the case if ' +
            'it turns out to need human review.',
        },
        {
          id: 'c',
          text:
            'Confirm the case is both reversible and cheap when wrong, since only cases of ' +
            'that kind can be delegated in the first place.',
        },
        {
          id: 'd',
          text:
            'Hand the classification to risk and compliance, since the policy binder is ' +
            'where these criteria are owned.',
        },
      ],
      correct: ['a', 'b'],
      explanation:
        'Delegation supplies the criteria — reversibility, consequences of error, the human ' +
        'creativity and empathy an AI does not supply, and accountability for the outcome — ' +
        'but the material adds that not all criteria are load-bearing, and that identifying ' +
        'the load-bearing ones is what makes a classification defensible to risk and ' +
        'compliance. The screening then has to land on one of three classifications: fully ' +
        'appropriate, appropriate with human review (which needs a formally defined gate), ' +
        'or inappropriate. Irreversible or costly cases are not undelegatable by definition ' +
        '— they are the ones that go to human review or are dropped. And governance here is ' +
        'a practitioner skill, not a decision handed to the binder owner.',
      page: 16,
      verify: false,
    },
  ],
});
