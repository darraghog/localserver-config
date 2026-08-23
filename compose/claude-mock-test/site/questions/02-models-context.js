// Domain: models-context — "Models, context strategy and model swap".
// Source: notes.txt page 1 (product and model selection, model and context
// strategy) and the model/context takeaways on page 4.
BANK.register({
  id: 'models-context',
  title: 'Models, context strategy and model swap',
  questions: [
    {
      id: 'models-context-001',
      domain: 'models-context',
      type: 'single',
      stem:
        'A service has run on the most capable model since its prototype. Asked which tier ' +
        'it should be using in production, the team answers that the question has never come ' +
        'up. How does the material characterise that?',
      options: [
        {
          id: 'a',
          text:
            'Making no model-tier decision is itself a decision, and the default it settles ' +
            'on is often the most expensive option on the list.',
        },
        {
          id: 'b',
          text:
            'The tier is settled well enough for now, since starting at the top and stepping ' +
            'down later avoids a quality regression.',
        },
        {
          id: 'c',
          text:
            'The choice stands until the cost dashboard contradicts it, and that ' +
            'contradiction is the signal to revisit which tier the service runs on.',
        },
        {
          id: 'd',
          text:
            'Tier selection only becomes a decision once a feature carries production ' +
            'traffic, so a tier inherited from a prototype needs no justification.',
        },
      ],
      correct: ['a'],
      explanation:
        'The material states it as a slogan: "no model-tier decision" is a decision, and the ' +
        'default can often be to the most expensive option. Waiting for the cost dashboard ' +
        'is weak because cost visibility can be in weeks, so the contradiction arrives late. ' +
        'And the recommendation for a new feature is to start with Sonnet, not to start at ' +
        'the top and step down, because the later step down is a model swap and changes ' +
        'behaviour.',
      page: 1,
      verify: false,
    },
    {
      id: 'models-context-002',
      domain: 'models-context',
      type: 'single',
      stem:
        'An architect is asked at design time which model a new feature should run on. There ' +
        'is no eval set yet and no production traffic to learn from. What does the material ' +
        'recommend?',
      options: [
        {
          id: 'a',
          text:
            'Start on Sonnet as the general-purpose tier, and treat any later move to ' +
            'another tier as a release rather than a config tweak.',
        },
        {
          id: 'b',
          text:
            'Start on the cheapest tier and step up when users begin to complain, so that no ' +
            'capability is being paid for before it has been shown to be needed.',
        },
        {
          id: 'c',
          text:
            'Start on the most capable tier and leave it there, since a tier that is never ' +
            'changed cannot introduce a regression later on.',
        },
        {
          id: 'd',
          text:
            'Choose the tier from published benchmark scores for this task type, and confirm ' +
            'the choice once there is real traffic to measure it against.',
        },
      ],
      correct: ['a'],
      explanation:
        'The page 4 takeaway is exactly this: choosing a model means starting with Sonnet ' +
        'and treating a model swap as a release. Sonnet is the general-purpose tier. Waiting ' +
        'for user complaints is detecting regressions in production, which the material ' +
        'tells you to avoid. Never changing tier is the "no model-tier decision" default, ' +
        'sitting on the expensive end. And a benchmark score is not the eval set the ' +
        'material wants gating a tier decision.',
      page: 4,
      verify: false,
    },
    {
      id: 'models-context-003',
      domain: 'models-context',
      type: 'single',
      stem:
        'A cost model for a new feature treats Opus as the ceiling on per-request price and ' +
        'Haiku as the floor, with Sonnet somewhere in between. Which correction does the ' +
        'material make to that picture?',
      options: [
        {
          id: 'a',
          text:
            'Fable, not Opus, sits at the expensive end; Haiku is the cheapest, Sonnet the ' +
            'general-purpose tier and Opus the advanced one.',
        },
        {
          id: 'b',
          text:
            'Sonnet is the cheapest of the four tiers, with Haiku sitting above it as the ' +
            'fast tier rather than below it as the inexpensive one.',
        },
        {
          id: 'c',
          text:
            'The tiers cannot be ordered by price at all, since per-request cost is set by ' +
            'the context strategy in use rather than by the tier.',
        },
        {
          id: 'd',
          text:
            'Opus is the ceiling only once extended thinking is switched on, which is what ' +
            'lifts it above the other tiers on price.',
        },
      ],
      correct: ['a'],
      explanation:
        'The material lists four tiers: Haiku as the cheapest, Sonnet as general purpose, ' +
        'Opus as advanced, and Fable as the most expensive. A cost model that stops at Opus ' +
        'is missing the top of the range. Haiku is named as the cheapest, so the inverted ' +
        'ordering is wrong. The tiers are ordered by cost in the material itself. And ' +
        'extended thinking adds output tokens to a request; it does not reorder the tiers.',
      page: 1,
      verify: false,
    },
    {
      id: 'models-context-004',
      domain: 'models-context',
      type: 'single',
      stem:
        'Two engineers disagree over whether a summariser should run on Haiku or on Sonnet. ' +
        'Each has read the outputs of a handful of runs and reached the opposite conclusion. ' +
        'The feature has no eval set. What does the material say about the situation?',
      options: [
        {
          id: 'a',
          text:
            'An eval set is what makes a tier decision decidable; without one the decision ' +
            'is being made blind, however many outputs get read.',
        },
        {
          id: 'b',
          text:
            'Ship on the cheaper tier and let the production error rate settle the argument, ' +
            'since live traffic is a larger sample than any set they could assemble.',
        },
        {
          id: 'c',
          text:
            'Run on the more capable tier while the argument is open, on the grounds that an ' +
            'unresolved tier question has not yet become a decision.',
        },
        {
          id: 'd',
          text:
            'This is a prompt problem rather than a tier problem, since disagreement about ' +
            'output points at an underspecified prompt.',
        },
      ],
      correct: ['a'],
      explanation:
        'The material says an eval set helps with the tier decision and that no eval set ' +
        'means the decision making is blind — which is what reading a handful of runs ' +
        'amounts to. Letting production settle it is detecting regressions in production, ' +
        'which the material tells you to avoid. Deferring is not neutral: "no model-tier ' +
        'decision" is itself a decision. And nothing here points at a prompt defect; the ' +
        'missing artefact is the eval set.',
      page: 1,
      verify: false,
    },
    {
      id: 'models-context-005',
      domain: 'models-context',
      type: 'single',
      stem:
        'A team plans to switch tiers on Monday and confirm the cost impact from the billing ' +
        'dashboard in time for a Friday go/no-go. What does the material say about that ' +
        'plan?',
      options: [
        {
          id: 'a',
          text:
            'Cost visibility can run to weeks, so a few days of dashboard data will not ' +
            'confirm what the change actually costs to run.',
        },
        {
          id: 'b',
          text:
            'The dashboard settles cost but not behaviour, so the go/no-go should turn on ' +
            'the eval score alone and leave the cost figure out of it.',
        },
        {
          id: 'c',
          text:
            'Cost per request is fixed by the tier, so it can be worked out up front and ' +
            'needs no dashboard confirmation before the go/no-go at all.',
        },
        {
          id: 'd',
          text:
            'Cost is the wrong measure for a tier change, since intermediate reasoning steps ' +
            'are billed on a separate track.',
        },
      ],
      correct: ['a'],
      explanation:
        'Among the model-swap notes the material warns that cost visibility can be in weeks. ' +
        'A four-day window will not produce the number the go/no-go is waiting on. Cost is ' +
        'not irrelevant to the decision — it is one of the reasons the tier decision matters ' +
        '— and it cannot simply be computed up front, which is why visibility lagging by ' +
        'weeks is worth warning about. Extended thinking is not billed on a separate track: ' +
        'its intermediate steps count as output tokens.',
      page: 1,
      verify: false,
    },
    {
      id: 'models-context-006',
      domain: 'models-context',
      type: 'single',
      stem:
        'A team enables extended thinking on a reasoning-heavy feature and budgets for it by ' +
        'counting only the tokens in the final answer, on the basis that the intermediate ' +
        'steps are internal to the model. What does the material say?',
      options: [
        {
          id: 'a',
          text:
            'The intermediate steps count as output tokens for billing, so the budget has to ' +
            'carry them alongside the final answer.',
        },
        {
          id: 'b',
          text:
            'The intermediate steps are billed at the input rate, which is why a budget ' +
            'should count them with the prompt rather than with the answer.',
        },
        {
          id: 'c',
          text:
            'Extended thinking is priced into the tier itself, so a feature that switches it ' +
            'on pays no more per request than one that leaves it off.',
        },
        {
          id: 'd',
          text:
            'Only steps returned to the caller are billed, so a feature discarding the ' +
            'reasoning pays for its answer alone.',
        },
      ],
      correct: ['a'],
      explanation:
        'The material notes that with reasoning models and extended thinking the ' +
        'intermediate steps are considered output tokens for billing purposes. That is the ' +
        'whole point of the warning: the reasoning is not free, is not charged at the ' +
        'cheaper input rate, is not absorbed into the tier price, and is not waived by ' +
        'discarding the blocks before they reach the user.',
      page: 1,
      verify: false,
    },
    {
      id: 'models-context-007',
      domain: 'models-context',
      type: 'single',
      stem:
        'A design review is deadlocked over whether an assistant should use RAG or ' +
        'compaction, on the assumption that the architecture has to commit to one context ' +
        'strategy. How does the material frame that choice?',
      options: [
        {
          id: 'a',
          text:
            'Monolithic, progressive, RAG and compaction combine, and more than one may be ' +
            'in play during a single model execution.',
        },
        {
          id: 'b',
          text:
            'The strategies are mutually exclusive at run time, so the choice has to be made ' +
            'once and then held for the working life of the feature.',
        },
        {
          id: 'c',
          text:
            'The choice follows from the model tier, since each tier supports the strategies ' +
            'its context window can sustain.',
        },
        {
          id: 'd',
          text:
            'RAG and compaction are the same strategy under two names, so the review is ' +
            'arguing about vocabulary rather than about architecture.',
        },
      ],
      correct: ['a'],
      explanation:
        'The material names four context strategies — monolithic, progressive, RAG and ' +
        'compaction — and adds directly that multiple strategies may be combined during ' +
        'model execution. So the deadlock is over a false choice. Nothing in the material ' +
        'ties a strategy to a tier, and RAG and compaction are listed as separate ' +
        'strategies, not as two names for one thing.',
      page: 1,
      verify: false,
    },
    {
      id: 'models-context-008',
      domain: 'models-context',
      type: 'single',
      stem:
        'An assistant answers "where is my order right now" by retrieving from a document ' +
        'store that is re-indexed overnight. Customers report answers that were true ' +
        'yesterday. What does the material identify as the underlying mistake?',
      options: [
        {
          id: 'a',
          text:
            'Using retrieval as a substitute for live state: retrieval suits static docs, ' +
            'not the current status of an order.',
        },
        {
          id: 'b',
          text:
            'Indexing too rarely; the same retrieval design works once the store is ' +
            're-indexed continuously rather than in an overnight batch run.',
        },
        {
          id: 'c',
          text:
            'A context window too small for the retrieved chunks, which is fixed by moving ' +
            'the feature to a tier with more room in its context.',
        },
        {
          id: 'd',
          text:
            'Missing compaction, so older summaries sit in the conversation history and ' +
            'outweigh the retrieved documents.',
        },
      ],
      correct: ['a'],
      explanation:
        'The material calls out this exact common mistake: using retrieval as a substitute ' +
        'for live state, when retrieval is good for static docs. Persistent application ' +
        'state is named as its own key term for a reason. Re-indexing faster narrows the ' +
        'staleness window without changing the architecture that produced it, so the design ' +
        'still answers a live question from a document snapshot. Nothing here points at the ' +
        'size of the context window, and compaction manages accumulated history rather than ' +
        'freshness of state.',
      page: 4,
      verify: false,
    },
    {
      id: 'models-context-009',
      domain: 'models-context',
      type: 'multi',
      stem:
        'A team is moving a production feature from one model tier to another and plans to ' +
        'flip it behind a configuration flag on a quiet afternoon. Which two things does the ' +
        'material require instead? (Select 2.)',
      options: [
        {
          id: 'a',
          text:
            'Handle the change as a release, because a swap changes the behaviour of the ' +
            'feature and not only its price.',
        },
        {
          id: 'b',
          text:
            'Gate the change on an eval set beforehand, rather than detecting the regression ' +
            'once it is in production.',
        },
        {
          id: 'c',
          text:
            'Leave the flag in place and compare the tiers on live traffic, which is the ' +
            'only honest comparison of two tiers there is.',
        },
        {
          id: 'd',
          text:
            'Confirm the cost effect first, which the billing data will show within a day of ' +
            'the flag being flipped.',
        },
      ],
      correct: ['a', 'b'],
      explanation:
        'The material says to treat a model swap as a release because it changes behaviour, ' +
        'that an eval set is what a tier decision rests on, and that you should avoid ' +
        'detecting regressions in production. A quiet configuration flip is the opposite of ' +
        'all three. Comparing on live traffic is where the regression would be discovered, ' +
        'and the billing data will not answer within a day, since cost visibility can be in ' +
        'weeks.',
      page: 1,
      verify: false,
    },
    {
      id: 'models-context-010',
      domain: 'models-context',
      type: 'single',
      stem:
        'A context design document describes the approach as "RAG, compaction and persistent ' +
        'application state — three context strategies working together". Which correction ' +
        'does the material make?',
      options: [
        {
          id: 'a',
          text:
            'Persistent application state is one of the key terms of context design, rather ' +
            'than one of the four strategies.',
        },
        {
          id: 'b',
          text:
            'Compaction belongs with the key terms rather than the strategies, alongside ' +
            'retrieval and the context window.',
        },
        {
          id: 'c',
          text:
            'The key terms — context window, retrieval, persistent application state and ' +
            'memory layers — are simply those strategies renamed.',
        },
        {
          id: 'd',
          text:
            'The list is complete only once summaries and memory layers is added, which the ' +
            'material names as the fourth of the strategies.',
        },
      ],
      correct: ['a'],
      explanation:
        'The material keeps two lists apart. The key terms of model and context strategy are ' +
        'the context window, retrieval, persistent application state, and summaries and ' +
        'memory layers. The context strategies are monolithic, progressive, RAG and ' +
        'compaction. So compaction is a strategy and persistent application state is not, ' +
        'the two lists are not the same list renamed, and summaries and memory layers is a ' +
        'key term rather than the missing fourth strategy.',
      page: 1,
      verify: false,
    },
  ],
});
