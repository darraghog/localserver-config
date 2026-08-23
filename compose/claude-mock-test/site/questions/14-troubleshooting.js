// Domain: troubleshooting — "Troubleshooting and workflow optimisation".
// Source: notes.txt page 18 (architect track).
BANK.register({
  id: 'troubleshooting',
  title: 'Troubleshooting and workflow optimisation',
  questions: [
    {
      id: 'troubleshooting-001',
      domain: 'troubleshooting',
      type: 'single',
      stem:
        'A user reports that a long working session started well and then drifted: the ' +
        'formatting rules set at the top stopped being followed about two thirds of the way ' +
        'in. Which cause does that symptom point to?',
      options: [
        {
          id: 'a',
          text:
            'Context overload — early instructions lose force, and the fix is to restart or to ' +
            'compact and summarise.',
        },
        {
          id: 'b',
          text:
            'Under-specification, since instructions that stop being followed were never ' +
            'concrete enough to be followed reliably.',
        },
        {
          id: 'c',
          text:
            'Stale configuration, since a standing instruction that drifts out of date shows ' +
            'up as gradual degradation within a session.',
        },
        {
          id: 'd',
          text:
            'The wrong model, since a speed-tier model loses instruction-following first as ' +
            'the conversation grows.',
        },
      ],
      correct: ['a'],
      explanation:
        'Each cause has its own signature symptom, and matching the symptom is the whole ' +
        'diagnostic. Under-specification shows up as output that is never right; context ' +
        'overload as output that started well and degraded; the wrong feature or model as ' +
        'specific, repeatable error types; and stale configuration as the used-to-work ' +
        'pattern. "Started well, then degraded" is context overload, and the fix is to restart ' +
        'or compact rather than to rewrite the instruction.',
      page: 18,
      verify: false,
    },
    {
      id: 'troubleshooting-002',
      domain: 'troubleshooting',
      type: 'single',
      stem:
        'A workflow that produced good output for months has quietly got worse, with no change ' +
        'to how it is prompted. Which cause fits, and what is the fix?',
      options: [
        {
          id: 'a',
          text:
            'Stale configuration — a standing instruction, knowledge source or skill has ' +
            'drifted out of date, and maintenance is the fix.',
        },
        {
          id: 'b',
          text:
            'Context overload, addressed by compacting the conversation and restating the key ' +
            'instructions.',
        },
        {
          id: 'c',
          text:
            'Under-specification that was always present and has only now become visible as ' +
            'the work has grown more demanding.',
        },
        {
          id: 'd',
          text:
            'A task that was never a fit, which the diagnostic sequence would have caught ' +
            'before the workflow was built.',
        },
      ],
      correct: ['a'],
      explanation:
        'The used-to-work symptom is stale configuration: a standing instruction, knowledge ' +
        'source or skill has drifted out of date and is degrading output. The fix is ' +
        'maintenance — which is the same conclusion the configuration-management material ' +
        'reaches when it says degraded quality is a maintenance issue rather than a prompt ' +
        'issue, and that quality dropping for no obvious reason means too long between ' +
        'reviews.',
      page: 18,
      verify: false,
    },
    {
      id: 'troubleshooting-003',
      domain: 'troubleshooting',
      type: 'single',
      stem:
        'Faced with underperforming output, a practitioner\'s first move is to question whether ' +
        'the task suits Claude at all. Where does that step sit in the diagnostic sequence, and ' +
        'why?',
      options: [
        {
          id: 'a',
          text:
            'Last. The sequence runs from the least expensive fix to the most expensive, and ' +
            'fit is the most expensive conclusion to reach.',
        },
        {
          id: 'b',
          text:
            'First, because every later step is wasted effort if the task was never suitable, ' +
            'and suitability is the cheapest thing to judge.',
        },
        {
          id: 'c',
          text:
            'Third, after specification and context have been ruled out but before the more ' +
            'invasive configuration work is undertaken.',
        },
        {
          id: 'd',
          text:
            'It is not part of the sequence — fit is settled during feasibility assessment and ' +
            'is not revisited during troubleshooting.',
        },
      ],
      correct: ['a'],
      explanation:
        'The sequence is ordered from the least expensive fix to the most expensive: reread ' +
        'the prompt for under-specification, check conversation length for context overload, ' +
        'check feature and model, check whether instructions, knowledge and skills are ' +
        'current, and finally assess whether the task is a fit at all. Putting fit last is ' +
        'deliberate — it is the most expensive conclusion to reach, and four cheaper causes ' +
        'produce the same complaint.',
      page: 18,
      verify: false,
    },
    {
      id: 'troubleshooting-004',
      domain: 'troubleshooting',
      type: 'single',
      stem:
        'A practitioner notices they make the same correction to Claude\'s output every ' +
        'session, paste the same background context into every new conversation, and get ' +
        'inconsistent results across colleagues doing the same task. Which fixes does the ' +
        'material attach to those three signals?',
      options: [
        {
          id: 'a',
          text:
            'Repetition to saved context or a standing instruction, correction to a ' +
            'configuration change, and variance to a shared skill or knowledge source.',
        },
        {
          id: 'b',
          text:
            'All three to a shared skill, since a skill is the only mechanism that carries a ' +
            'procedure across both sessions and colleagues.',
        },
        {
          id: 'c',
          text:
            'Repetition to a configuration change, correction to a shared skill, and variance ' +
            'to saved context.',
        },
        {
          id: 'd',
          text:
            'All three to better prompting, since each signal is evidence that the prompt is ' +
            'carrying too little of what the task needs.',
        },
      ],
      correct: ['a'],
      explanation:
        'Three signals of friction are listed with a fix each: repetition points to saved ' +
        'context or a standing instruction, correction points to a configuration change, and ' +
        'variance points to a shared skill or knowledge source. Variance is the one that gives ' +
        'the signal away — inconsistency *across people* is what makes it a sharing problem ' +
        'rather than a personal-configuration one.',
      page: 18,
      verify: false,
    },
    {
      id: 'troubleshooting-005',
      domain: 'troubleshooting',
      type: 'single',
      stem:
        'A team decides to capture a recurring fix and asks where it belongs. What test does ' +
        'the material give, and what happens if the answer is wrong?',
      options: [
        {
          id: 'a',
          text:
            'Ask whether the fix is a rule, a reference or a procedure — rule to an ' +
            'instruction, reference to knowledge, procedure to a skill. A misplaced fix may ' +
            'not stick.',
        },
        {
          id: 'b',
          text:
            'Ask how often the fix is needed — daily fixes to instructions, occasional ones to ' +
            'knowledge. A misplaced fix simply costs a little extra context.',
        },
        {
          id: 'c',
          text:
            'Ask who needs it — personal fixes to instructions, team-wide fixes to skills. A ' +
            'misplaced fix is a sharing problem rather than a durability one.',
        },
        {
          id: 'd',
          text:
            'Put every captured fix into a skill, since skills are versioned and a versioned ' +
            'fix is the only kind that survives review.',
        },
      ],
      correct: ['a'],
      explanation:
        'The test is about the nature of the fix, not its frequency or its audience: a rule ' +
        'becomes an instruction, a reference becomes knowledge, a procedure becomes a skill. ' +
        'The consequence the material names is that a misplaced fix may not stick — a ' +
        'procedure written as an instruction, or a rule buried in a knowledge file, is unlikely ' +
        'to hold. This is the same slot-matching discipline as configuring a project.',
      page: 18,
      verify: false,
    },
    {
      id: 'troubleshooting-006',
      domain: 'troubleshooting',
      type: 'single',
      stem:
        'An optimisation reduced revision cycles from three to one but saved almost no wall ' +
        'clock time. How does the material treat that result?',
      options: [
        {
          id: 'a',
          text:
            'As a concrete gain worth tracking: sometimes time saved matters less than ' +
            'improved consistency, and an improvement that cannot be measured is hard to ' +
            'justify.',
        },
        {
          id: 'b',
          text:
            'As an inconclusive result, since time saved is the measure that makes an ' +
            'efficiency claim defensible to a business owner.',
        },
        {
          id: 'c',
          text:
            'As a reason to revisit the optimisation, because fewer revisions with no time ' +
            'saved implies the revisions were not the bottleneck.',
        },
        {
          id: 'd',
          text:
            'As unmeasurable, since revision count is a proxy rather than a gain and should ' +
            'not be reported as one.',
        },
      ],
      correct: ['a'],
      explanation:
        'The material asks for concrete gains to be tracked — time saved, revision cycles ' +
        'reduced, consistency improvement — precisely because an improvement that cannot be ' +
        'measured is hard to justify. It then adds the qualifier that matters here: sometimes ' +
        'time saved is less important than improved consistency. Revision cycles reduced is on ' +
        'the list of gains, not a proxy for one.',
      page: 18,
      verify: false,
    },
  ],
});
