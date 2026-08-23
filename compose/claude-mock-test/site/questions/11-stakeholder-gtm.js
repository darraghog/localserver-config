// Domain: stakeholder-gtm — "Stakeholder engagement, lifecycle, GTM and documentation".
// Source: notes.txt pages 14-15 (architect track).
BANK.register({
  id: 'stakeholder-gtm',
  title: 'Stakeholder engagement, lifecycle, GTM and documentation',
  questions: [
    {
      id: 'stakeholder-gtm-001',
      domain: 'stakeholder-gtm',
      type: 'single',
      stem:
        'Structured discovery has produced a long list of what the system must do and roughly ' +
        'what it may cost. Which two categories are missing, and what is discovery meant to ' +
        'produce?',
      options: [
        {
          id: 'a',
          text:
            'What the system must *not* do, and what it must prove for compliance — with a ' +
            'translation table as the output.',
        },
        {
          id: 'b',
          text:
            'Who owns the system and who funds it — with a signed statement of work as the ' +
            'output.',
        },
        {
          id: 'c',
          text:
            'Which model tier and which entry point are in scope — with an architecture sketch ' +
            'as the output.',
        },
        {
          id: 'd',
          text:
            'Nothing is missing: capability and cost are the two discovery categories, and the ' +
            'output is the capability list that feeds sizing.',
        },
      ],
      correct: ['a'],
      explanation:
        'Discovery runs on four questions: what the system must do, what it must not do, what ' +
        'it must cost, and what it must prove for compliance. The must-not-do and must-prove ' +
        'categories are the ones teams skip, and they are the ones that later eliminate entry ' +
        'points and routes. The output of discovery is a translation table — the artefact that ' +
        'carries requirements into design, with preferences recorded as constraints and ' +
        'assumptions attached per requirement.',
      page: 14,
      verify: false,
    },
    {
      id: 'stakeholder-gtm-002',
      domain: 'stakeholder-gtm',
      type: 'single',
      stem:
        'An architect recommends Bedrock over the direct API and writes it up as a one-line ' +
        'verdict with a short justification. How does the material say a tradeoff should be ' +
        'communicated?',
      options: [
        {
          id: 'a',
          text:
            'As a package rather than a verdict: what is gained, what is given up, and what it ' +
            'costs to reverse the choice later — plus what it does to the compliance posture.',
        },
        {
          id: 'b',
          text:
            'As a verdict with the supporting evidence attached, since a recommendation that ' +
            'presents alternatives invites the partner to re-open a settled decision.',
        },
        {
          id: 'c',
          text:
            'As a scored comparison across every candidate route, so that the decision follows ' +
            'from the weighting rather than from the architect\'s judgement.',
        },
        {
          id: 'd',
          text:
            'As a verdict now and a package later, with the reversal cost added to the outcome ' +
            'document once the deployment has run long enough to estimate it.',
        },
      ],
      correct: ['a'],
      explanation:
        'The GTM questions are: what do we gain, what do we give up, what happens if we choose ' +
        'this now and reverse later, and what does it do to our compliance posture. The ' +
        'material\'s instruction is to frame the decision as a package, not a verdict, because ' +
        'that is what makes it defensible by the partner to their own stakeholders. Reversal ' +
        'cost is named as one of the three elements a tradeoff presentation must carry, so ' +
        'deferring it removes the part that makes the package a decision rather than a ' +
        'preference.',
      page: 14,
      verify: false,
    },
    {
      id: 'stakeholder-gtm-003',
      domain: 'stakeholder-gtm',
      type: 'single',
      stem:
        'A deployment has dashboards and alerts but no agreed way of acting on what they show. ' +
        'Which structure does the material place above the observability stack?',
      options: [
        {
          id: 'a',
          text:
            'A decision layer running signals, triage, decide, act, review — ending by asking ' +
            'whether the response worked and whether the rule should change.',
        },
        {
          id: 'b',
          text:
            'An escalation matrix mapping each alert to a severity and an on-call owner, so ' +
            'that every signal has a route to a person.',
        },
        {
          id: 'c',
          text:
            'A weekly business review, where the accumulated signals are presented and the ' +
            'stakeholders decide which to act on.',
        },
        {
          id: 'd',
          text:
            'A second eval suite run against production traffic, so that observed signals are ' +
            'converted into pass/fail results before anyone is asked to act.',
        },
      ],
      correct: ['a'],
      explanation:
        'The feedback-loop decision layer sits above the observability stack and has five ' +
        'steps: signals (what is the system showing us), triage (what needs attention now and ' +
        'what can wait), decide (team fix, stakeholder review, or no action), act (what ' +
        'correction, guardrail update or escalation is required), and review (did the response ' +
        'work, and does the rule need to change). The last step is what makes it a loop rather ' +
        'than a pipeline.',
      page: 14,
      verify: false,
    },
    {
      id: 'stakeholder-gtm-004',
      domain: 'stakeholder-gtm',
      type: 'single',
      stem:
        'A draft SLA commits to "high quality responses with good availability". What does the ' +
        'material require of an SLA, and where should the thresholds come from?',
      options: [
        {
          id: 'a',
          text:
            'It must state what is measured, what counts as a breach, and what happens when ' +
            'one occurs — with tangible thresholds drawn from real sources rather than ' +
            'adjectives.',
        },
        {
          id: 'b',
          text:
            'It must state a single composite service score with a numeric floor, so that ' +
            'breach is unambiguous and no individual metric can be argued over.',
        },
        {
          id: 'c',
          text:
            'It must state what is measured and what counts as a breach; the consequence is a ' +
            'commercial matter settled in the contract rather than in the SLA.',
        },
        {
          id: 'd',
          text:
            'It should stay qualitative until the deployment has a production baseline, since ' +
            'thresholds set before real traffic are guesses that will be renegotiated anyway.',
        },
      ],
      correct: ['a'],
      explanation:
        'An SLA answers three questions: what are we measuring, what counts as a breach, and ' +
        'what happens when a breach occurs. Dropping the third, as in (c), leaves a metric ' +
        'rather than an agreement. The material also insists thresholds be tangible and drawn ' +
        'from real sources — latency tied to user experience, availability to business ' +
        'criticality, and quality to eval results and acceptance criteria, which is what makes ' +
        'the quality number defensible rather than an opinion.',
      page: 14,
      verify: false,
    },
    {
      id: 'stakeholder-gtm-005',
      domain: 'stakeholder-gtm',
      type: 'multi',
      stem:
        'A handoff document records the decision that was made and the tradeoff that was ' +
        'named. Which two further items does the material\'s documentation checklist require? ' +
        '(Select 2.)',
      options: [
        {
          id: 'a',
          text:
            'The alternatives that were rejected, so a reviewer can see what was considered ' +
            'and not chosen.',
        },
        {
          id: 'b',
          text:
            'A named owner and an evidence artifact, with the audit-ready status of each ' +
            'recorded.',
        },
        {
          id: 'c',
          text:
            'The full prompt text and model configuration in force at the time of writing, so ' +
            'the document is self-contained.',
        },
        {
          id: 'd',
          text:
            'A projected review date, after which the document should be regarded as lapsed ' +
            'rather than current.',
        },
        {
          id: 'e',
          text:
            'The names of everyone consulted during discovery, so the decision can be traced ' +
            'to the people who informed it.',
        },
      ],
      correct: ['a', 'b'],
      explanation:
        'The completion checklist is decision, rejected alternatives, tradeoff named, owner, ' +
        'evidence artifact, and audit-ready status. Rejected alternatives and the ' +
        'owner-and-evidence pair are what turn a record of a choice into something a reviewer ' +
        'can audit — which is the same principle the compliance control register runs on, and ' +
        'why the register is carried forward into the handoff as evidence.',
      page: 14,
      verify: false,
    },
    {
      id: 'stakeholder-gtm-006',
      domain: 'stakeholder-gtm',
      type: 'single',
      stem:
        'A partner design spans two entry points. Beyond choosing the route on latency, ' +
        'compliance and cost, what does the material ask for?',
      options: [
        {
          id: 'a',
          text:
            'An entry-point-responsibility map for the multi-entry-point design, and an ' +
            'outcome document capturing the before metric, an auditable control and a reuse ' +
            'note.',
        },
        {
          id: 'b',
          text:
            'A consolidation plan committing to a single entry point within a fixed period, ' +
            'since a two-entry-point design is a transitional state rather than a target one.',
        },
        {
          id: 'c',
          text:
            'A separate SOW per entry point, so that the boundary conditions of each can be ' +
            'contracted against independently.',
        },
        {
          id: 'd',
          text:
            'A single blended cost model across both entry points, so the partner sees one ' +
            'figure rather than two competing ones.',
        },
      ],
      correct: ['a'],
      explanation:
        'Entry-point selection is chosen on latency, compliance and cost, with an ' +
        'entry-point-responsibility map required specifically for designs that span more than ' +
        'one. The outcome document then captures three things: the before metric, an auditable ' +
        'control, and a reuse note. Note the shape — a before metric is what later lets anyone ' +
        'claim the deployment moved anything, which is the same discipline as measuring the ' +
        'ROI baseline rather than estimating it.',
      page: 15,
      verify: false,
    },
  ],
});
