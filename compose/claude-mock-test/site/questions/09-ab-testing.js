// Domain: ab-testing — "A/B testing, shadow testing and observability at scale".
// Source: notes.txt pages 9-10 (architect track).
BANK.register({
  id: 'ab-testing',
  title: 'A/B testing, shadow testing and observability at scale',
  questions: [
    {
      id: 'ab-testing-001',
      domain: 'ab-testing',
      type: 'single',
      stem:
        'A regulated lender wants to validate a new prompt version. A single bad output could ' +
        'trigger a complaint, and the product handles only a few hundred requests a day. Which ' +
        'method does the material point to, and how is it run?',
      options: [
        {
          id: 'a',
          text:
            'Shadow testing: send live requests to the shadow version while continuing to ' +
            'serve the current version\'s responses, and score the shadow outputs from logs ' +
            'after the fact without ever exposing them.',
        },
        {
          id: 'b',
          text:
            'A live A/B test with a small treatment share, since even a few hundred requests a ' +
            'day accumulates a usable sample within a fortnight.',
        },
        {
          id: 'c',
          text:
            'A live A/B test restricted to internal staff traffic, so that real exposure is ' +
            'avoided while the split stays live.',
        },
        {
          id: 'd',
          text:
            'Neither: with low traffic and high per-output risk, the change should go straight ' +
            'to production behind a feature flag and be rolled back on the first complaint.',
        },
      ],
      correct: ['a'],
      explanation:
        'The selection rule turns on two things: a live A/B test needs a deployment that can ' +
        'absorb a small, bounded amount of exposure to a worse version and traffic volume that ' +
        'is statistically meaningful. Neither holds here. Shadow testing is named for exactly ' +
        'this case — a single bad output carrying high risk, or traffic too low to support a ' +
        'live split — and the material adds that it may be the only meaningful option in ' +
        'regulated environments. The defining property is that outputs are scored from logs ' +
        'after the fact and never reach users.',
      page: 10,
      verify: false,
    },
    {
      id: 'ab-testing-002',
      domain: 'ab-testing',
      type: 'single',
      stem:
        'A team sizes an LLM A/B test using the same sample-size calculation they use for ' +
        'deterministic UI experiments, with the same minimal detectable effect and confidence ' +
        'level. What does the material say they have missed?',
      options: [
        {
          id: 'a',
          text:
            'Output variance is higher for an LLM than for a deterministic system, so a larger ' +
            'sample is needed to detect the same effect.',
        },
        {
          id: 'b',
          text:
            'Sample size for an LLM test should be derived from token volume rather than ' +
            'request count, since cost rather than statistical power is the binding limit.',
        },
        {
          id: 'c',
          text:
            'Nothing — the calculation is identical, because minimal detectable effect and ' +
            'confidence level already account for whatever variance the system has.',
        },
        {
          id: 'd',
          text:
            'A smaller sample suffices, because each LLM response carries more information ' +
            'than a click and therefore more signal per observation.',
        },
      ],
      correct: ['a'],
      explanation:
        'Sample size still comes from the same three inputs — minimal detectable effect, ' +
        'baseline metric, confidence level — but the material adds a correction specific to ' +
        'this setting: variance in outputs is higher for an LLM than for a deterministic ' +
        'system, which means a larger sample size is needed. Under-powering is then the first ' +
        'item on the list of things to check before declaring an outcome.',
      page: 9,
      verify: false,
    },
    {
      id: 'ab-testing-003',
      domain: 'ab-testing',
      type: 'multi',
      stem:
        'A team declares a new prompt version the winner: task success rose two points over ' +
        'the fortnight it ran. Which two checks from the material\'s pre-declaration list ' +
        'should the architect insist on? (Select 2.)',
      options: [
        {
          id: 'a',
          text:
            'Whether the primary metric was pre-specified, rather than chosen once the results ' +
            'were in.',
        },
        {
          id: 'b',
          text:
            'Whether the input distribution was controlled across the two arms and the test ' +
            'period.',
        },
        {
          id: 'c',
          text:
            'Whether the treatment group was assigned by customer segment, so that each arm is ' +
            'internally homogeneous.',
        },
        {
          id: 'd',
          text:
            'Whether the new version was also cheaper per request, since a quality gain that ' +
            'costs more is not a win.',
        },
        {
          id: 'e',
          text:
            'Whether the control arm ran the previous model tier as well as the previous ' +
            'prompt, so both changes are covered at once.',
        },
      ],
      correct: ['a', 'b'],
      explanation:
        'Three things are named to watch for before declaring an A/B outcome: sample size too ' +
        'small, input distribution not controlled, and primary metric not pre-specified. Two ' +
        'of those are on offer here. The material stresses that test period and input ' +
        'distribution alignment matter more in LLM experiments than elsewhere. Assignment is ' +
        'random by request, not by segment, which is what (c) breaks; secondary-metric ' +
        'degradation is a real success criterion but is not framed as a cost veto; and ' +
        'changing model and prompt together is the opposite of an isolated treatment.',
      page: 10,
      verify: false,
    },
    {
      id: 'ab-testing-004',
      domain: 'ab-testing',
      type: 'single',
      stem:
        'Aggregate dashboards look healthy — cost per request, P95 latency and task success ' +
        'rate are all within threshold — yet a specific class of request is failing and ' +
        'consuming most of the budget. What does the material say about this?',
      options: [
        {
          id: 'a',
          text:
            'Aggregate metrics protect against obvious failures; per-request decomposition ' +
            'is what protects against non-obvious ones like this.',
        },
        {
          id: 'b',
          text:
            'The aggregates are the wrong ones — cost per request and P95 should be replaced ' +
            'by per-class rollups so that the dashboard cannot hide a bad class.',
        },
        {
          id: 'c',
          text:
            'This is a threshold-tuning problem: the alerts are set too loosely, and ' +
            'tightening them against the seven-day average would have caught it.',
        },
        {
          id: 'd',
          text:
            'This is expected and acceptable, since a small fraction of pathological requests ' +
            'is what the aggregate is designed to average out.',
        },
      ],
      correct: ['a'],
      explanation:
        'This is the risk half of the section\'s triad, almost verbatim: aggregate metrics ' +
        'protect against obvious failures, per-request decomposition protects against ' +
        'non-obvious ones — the example given is highlighting the fraction of requests ' +
        'consuming the most budget while producing wrong outputs. Threshold alerts on cost ' +
        'spikes and P95 are real instrumentation, but they fire on the aggregate and so cannot ' +
        'see a bad class hidden inside a healthy average.',
      page: 10,
      verify: false,
    },
    {
      id: 'ab-testing-005',
      domain: 'ab-testing',
      type: 'single',
      stem:
        'Task success rate has fallen over six weeks with no change to the prompt or the ' +
        'model. Which instrumentation capability does the material say separates the possible ' +
        'causes?',
      options: [
        {
          id: 'a',
          text:
            'Change attribution, which distinguishes model drift — behaviour on stable inputs ' +
            '— from data drift, where the input distribution has moved, and from the effects ' +
            'of a model update.',
        },
        {
          id: 'b',
          text:
            'Request-level tracing, since the cause is visible in individual traces once ' +
            'enough of them are read.',
        },
        {
          id: 'c',
          text:
            'Anomaly detection, since a six-week decline is precisely the pattern a threshold ' +
            'alert against the seven-day average is designed to surface.',
        },
        {
          id: 'd',
          text:
            'Metric aggregation, because comparing P50 against P95 over the period localises ' +
            'the change to a subset of requests.',
        },
      ],
      correct: ['a'],
      explanation:
        'Instrumentation has four parts — request-level tracing, metric aggregation, anomaly ' +
        'detection and change attribution — and change attribution is the one that answers ' +
        '"why did it change". Its distinction is precise and worth holding: model drift is a ' +
        'change in behaviour on stable inputs, whereas data drift is a change in the input ' +
        'distribution itself. The other three tell you what the system is doing, how well, and ' +
        'when it changed.',
      page: 10,
      verify: false,
    },
    {
      id: 'ab-testing-006',
      domain: 'ab-testing',
      type: 'single',
      stem:
        'A business owner is shown latency and task success rate and asks what they mean for ' +
        'the contact centre. Where does the material say that mapping belongs?',
      options: [
        {
          id: 'a',
          text:
            'In a translation layer designed up front — task success rate to first-contact ' +
            'resolution, latency to handle time — not worked out at the review itself.',
        },
        {
          id: 'b',
          text:
            'With the business owner, who is best placed to decide which operational measure ' +
            'each technical metric corresponds to in their own unit.',
        },
        {
          id: 'c',
          text:
            'In the observability stack itself, which should emit business metrics directly so ' +
            'that no separate mapping is needed.',
        },
        {
          id: 'd',
          text:
            'In the eval suite, since the acceptance thresholds already express the business ' +
            'requirement in measurable form.',
        },
      ],
      correct: ['a'],
      explanation:
        'The observability stack measures latency, task success rate and error rate. A ' +
        'translation layer maps those to the business\'s own numbers — task success rate to ' +
        'first-contact resolution, latency to handle time — so that the business owner can ' +
        'assess whether the system is moving the numbers that matter. The material calls out ' +
        'specifically that the translation layer is a design-time issue and not something to ' +
        'be improvised at the business review.',
      page: 10,
      verify: false,
    },
  ],
});
