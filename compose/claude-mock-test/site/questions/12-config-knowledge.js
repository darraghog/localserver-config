// Domain: config-knowledge — "Configuring Claude projects and knowledge management".
// Source: notes.txt pages 15-16 (architect track).
BANK.register({
  id: 'config-knowledge',
  title: 'Configuring Claude projects and knowledge management',
  questions: [
    {
      id: 'config-knowledge-001',
      domain: 'config-knowledge',
      type: 'single',
      stem:
        'A team wants a Claude project to follow a fixed review procedure, to know the current ' +
        'product catalogue, and to keep hold of decisions already settled with the client. ' +
        'Which configuration slots does the material map those three needs to?',
      options: [
        {
          id: 'a',
          text:
            'Skills for the procedure, the knowledge base for the catalogue, and memory for ' +
            'the settled decisions.',
        },
        {
          id: 'b',
          text:
            'Instructions for the procedure, memory for the catalogue, and the knowledge base ' +
            'for the settled decisions.',
        },
        {
          id: 'c',
          text:
            'Skills for the procedure, memory for the catalogue, and instructions for the ' +
            'settled decisions.',
        },
        {
          id: 'd',
          text:
            'Instructions for all three, since a single well-written standing instruction can ' +
            'carry procedure, facts and history together.',
        },
      ],
      correct: ['a'],
      explanation:
        'The four slots each answer a different question: instructions shape behaviour, the ' +
        'knowledge base holds facts, skills hold procedures, and memory provides continuity. ' +
        'Memory in particular holds what the project has already settled — standing ' +
        'preferences and decisions. The material notes that some configurations legitimately ' +
        'span slots, but matching each need to the right mechanism is the point of having ' +
        'four.',
      page: 15,
      verify: false,
    },
    {
      id: 'config-knowledge-002',
      domain: 'config-knowledge',
      type: 'single',
      stem:
        'A consultant builds a skill for one client project and expects it to stay confined to ' +
        'that project. What does the material say about the scope of skills and of memory?',
      options: [
        {
          id: 'a',
          text:
            'Skills live at the account level rather than being specific to any individual ' +
            'project, whereas memory is scoped by project.',
        },
        {
          id: 'b',
          text:
            'Both are scoped by project, which is what keeps one client\'s procedures and ' +
            'context out of another\'s.',
        },
        {
          id: 'c',
          text:
            'Skills are scoped by project and memory sits at the account level, so continuity ' +
            'carries across the consultant\'s work.',
        },
        {
          id: 'd',
          text:
            'Both live at the account level, and separation between clients is achieved with ' +
            'separate accounts rather than separate projects.',
        },
      ],
      correct: ['a'],
      explanation:
        'Skills are held at the account level and are not specific to any individual project ' +
        'in Claude — so a skill authored for one engagement is available to the others, which ' +
        'is worth knowing before client-specific procedure goes into one. Memory is the ' +
        'opposite: scoped by project, holding what that project has already settled.',
      page: 15,
      verify: false,
    },
    {
      id: 'config-knowledge-003',
      domain: 'config-knowledge',
      type: 'single',
      stem:
        'Output quality on a long-running project has been drifting downwards for no obvious ' +
        'reason. The team\'s first instinct is to rewrite the prompt. What does the material ' +
        'say?',
      options: [
        {
          id: 'a',
          text:
            'Degraded quality is a maintenance issue rather than a prompt issue, and quality ' +
            'dropping for no obvious reason usually means too long has passed between ' +
            'configuration reviews.',
        },
        {
          id: 'b',
          text:
            'Drift of this kind is model drift, so the response is to pin the model version ' +
            'and re-run the eval suite against the pinned version.',
        },
        {
          id: 'c',
          text:
            'Rewriting the prompt is the right first move, since instructions are the only ' +
            'configuration slot that shapes behaviour directly.',
        },
        {
          id: 'd',
          text:
            'It is expected decay in a long-running project and is addressed by starting a ' +
            'fresh project rather than by maintaining the existing one.',
        },
      ],
      correct: ['a'],
      explanation:
        'The material is explicit that degraded quality is a maintenance issue, not a prompt ' +
        'issue, and offers the diagnostic directly: quality dropping for no obvious reason ' +
        'points to too long between reviews. The prescribed practice is a recurring review of ' +
        'the configuration of every active project — a monthly pass is offered as an example ' +
        'that catches most drift — so that decay is caught before it reaches a deliverable.',
      page: 16,
      verify: false,
    },
    {
      id: 'config-knowledge-004',
      domain: 'config-knowledge',
      type: 'multi',
      stem:
        'A monthly configuration review is being defined. Which two maintenance facts from the ' +
        'material should shape what the reviewer actually checks? (Select 2.)',
      options: [
        {
          id: 'a',
          text:
            'Custom-uploaded skills need manual re-upload, while Anthropic and org-provisioned ' +
            'skills update automatically.',
        },
        {
          id: 'b',
          text:
            'Memory should be treated like a working file, with a full reset when too much ' +
            'outdated context has accumulated.',
        },
        {
          id: 'c',
          text:
            'Uploaded knowledge refreshes from its source whenever the project is opened, so ' +
            'currency needs no review.',
        },
        {
          id: 'd',
          text:
            'Memory compacts itself once it passes a size threshold, so stale entries fall out ' +
            'without intervention.',
        },
        {
          id: 'e',
          text:
            'All skills, however provisioned, are pinned at the version in force when the ' +
            'project was created.',
        },
      ],
      correct: ['a', 'b'],
      explanation:
        'Two maintenance rules matter here. Skills differ by provenance: Anthropic and ' +
        'org-provisioned skills update automatically, while custom-uploaded skills need manual ' +
        're-upload — so a custom skill is the thing most likely to be quietly stale. Memory is ' +
        'to be treated like a working file, with a full reset when it has accumulated too much ' +
        'outdated context. Uploaded knowledge is separately called out as needing to be kept ' +
        'current, which is what rules out (c).',
      page: 16,
      verify: false,
    },
    {
      id: 'config-knowledge-005',
      domain: 'config-knowledge',
      type: 'single',
      stem:
        'A project is connected to a data source through a publicly available connector rather ' +
        'than the organisation\'s own. What does the material ask a practitioner to establish ' +
        'about connectors?',
      options: [
        {
          id: 'a',
          text:
            'That the correct connector path is used — organisational rather than public where ' +
            'one exists — and that the boundary of the connector\'s capabilities is understood.',
        },
        {
          id: 'b',
          text:
            'That the connector is listed in the compliance control register with a named ' +
            'owner, which is what makes the path an approved one.',
        },
        {
          id: 'c',
          text:
            'That the connector\'s data is mirrored into the knowledge base, so the project ' +
            'does not depend on a live connection to a third-party service.',
        },
        {
          id: 'd',
          text:
            'That the connector is scoped to the project rather than the account, so its reach ' +
            'matches the reach of the work.',
        },
      ],
      correct: ['a'],
      explanation:
        'Two things are asked about connectors: use the correct connector path, distinguishing ' +
        'the organisational one from the public one, and understand the scope of the ' +
        'connector\'s capabilities. Knowing each connector\'s boundary is listed as one of the ' +
        'five takeaways for this section, and it is the part that gets skipped — a connector ' +
        'that reaches further than assumed is the same silent-failure shape as assuming a ' +
        'domain rule is enforced when it was never given.',
      page: 15,
      verify: false,
    },
    {
      id: 'config-knowledge-006',
      domain: 'config-knowledge',
      type: 'single',
      stem:
        'A standing instruction reads "keep the tone professional and format things sensibly". ' +
        'What is the material\'s objection?',
      options: [
        {
          id: 'a',
          text:
            'Standing instructions must be precise rather than vague — format, tone and ' +
            'guardrail guidance are exactly the preferences worth stating exactly.',
        },
        {
          id: 'b',
          text:
            'Tone and format belong in the knowledge base rather than in instructions, since ' +
            'they are reference material rather than behaviour.',
        },
        {
          id: 'c',
          text:
            'Standing instructions should describe outcomes rather than style, leaving tone ' +
            'and formatting to be inferred from the examples in the knowledge base.',
        },
        {
          id: 'd',
          text:
            'There is no objection: a short, general instruction is preferable because it ' +
            'leaves room for judgement on each request.',
        },
      ],
      correct: ['a'],
      explanation:
        'Standing instructions are named as the place for preferences — embed format, tone and ' +
        'guardrail guidance — with the instruction to be precise, not vague. "Sensibly" gives ' +
        'nothing to comply with and nothing to check compliance against. Writing instructions ' +
        'precisely is one of the five takeaways for this section, alongside matching each need ' +
        'to the right mechanism.',
      page: 15,
      verify: false,
    },
  ],
});
