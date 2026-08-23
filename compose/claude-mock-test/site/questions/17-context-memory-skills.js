// Domain: context-memory-skills — "Streaming, context budget, memory scope and skills".
// Source: notes.txt pages 23-24, 26-27 (builder track).
BANK.register({
  id: 'context-memory-skills',
  title: 'Streaming, context budget, memory scope and skills',
  questions: [
    {
      id: 'context-memory-skills-001',
      domain: 'context-memory-skills',
      type: 'single',
      stem:
        'A streaming client sees the HTTP connection close, assembles what it received, saves ' +
        'the assistant turn to history and continues the loop. What does the material say is ' +
        'wrong?',
      options: [
        {
          id: 'a',
          text:
            'A stream ending is not a message completing: everything is provisional until ' +
            '`message_stop`, and the partial turn is discarded rather than saved.',
        },
        {
          id: 'b',
          text:
            'The partial turn should be saved but marked incomplete, so the next request can ' +
            'ask the model to continue from where it stopped.',
        },
        {
          id: 'c',
          text:
            'Nothing is wrong, provided the client re-requests any content block that never ' +
            'received its `content_block_stop`.',
        },
        {
          id: 'd',
          text:
            'The error is only in the ordering: history should be written before the loop ' +
            'continues, not after, so a truncated turn is still recoverable.',
        },
      ],
      correct: ['a'],
      explanation:
        'The event sequence ends with `message_stop`, and the rule is that a stream ending is ' +
        'not a message completing. Everything is provisional until `message_stop` arrives, the ' +
        'partial assistant turn is thrown away rather than persisted, and `stop_reason` from ' +
        '`message_delta` is checked before the loop continues. The related rule is not to act ' +
        'on a partial block at all — especially a `tool_use` block, where acting on ' +
        'half-assembled arguments means executing a tool with input the model never finished ' +
        'writing.',
      page: 23,
      verify: false,
    },
    {
      id: 'context-memory-skills-002',
      domain: 'context-memory-skills',
      type: 'single',
      stem:
        'An agent works well for the first several turns, then starts calling the wrong tools ' +
        'from around turn eight. The team begins rewriting tool descriptions. What does the ' +
        'material suggest is actually happening?',
      options: [
        {
          id: 'a',
          text:
            'It can look like tool selection failure but be context pressure — the fix is to ' +
            'prune tool outputs and apply compaction proactively, before the cap is reached.',
        },
        {
          id: 'b',
          text:
            'It is tool selection failure, since a description good enough for turn one is ' +
            'good enough for turn eight and the schema must therefore be at fault.',
        },
        {
          id: 'c',
          text:
            'It is routing compounding: each decision narrows the next, so the fix is to ' +
            'restructure the agent as a workflow with enumerated steps.',
        },
        {
          id: 'd',
          text:
            'It is a stop-condition problem, addressed by lowering the per-turn token budget ' +
            'so the loop terminates before context becomes tight.',
        },
      ],
      correct: ['a'],
      explanation:
        'The watch-out is stated in those terms: incorrect tool calls after turn eight, fixed ' +
        'by pruning tool outputs and proactively applying compaction before the cap is reached ' +
        '— and the material adds that it can look like tool selection failure. The general ' +
        'point behind it is that context is a fixed budget and tool outputs spend it faster ' +
        'than anything else in the loop, which is why the same symptom appears at a ' +
        'predictable depth rather than randomly.',
      page: 24,
      verify: false,
    },
    {
      id: 'context-memory-skills-003',
      domain: 'context-memory-skills',
      type: 'multi',
      stem:
        'A multi-turn assistant has a stable system prompt and a stable set of tool schemas. ' +
        'Which two statements about the API features for managing what is already in context ' +
        'are accurate? (Select 2.)',
      options: [
        {
          id: 'a',
          text:
            'Mark the cache breakpoint with a `cache_control` field of type `ephemeral` on the ' +
            'last block to be cached; up to four breakpoints can be set.',
        },
        {
          id: 'b',
          text:
            'The `count_tokens` endpoint takes the same request body as a messages call and ' +
            'returns a token count without running inference.',
        },
        {
          id: 'c',
          text:
            'When the context window fills, the oldest content is silently truncated, so the ' +
            'application does not need to summarise history itself.',
        },
        {
          id: 'd',
          text:
            'Prompt caching is most valuable when the prefix changes between turns, since a ' +
            'changing prefix is what makes reprocessing expensive.',
        },
        {
          id: 'e',
          text:
            'Token counting is billed as a normal inference request, so it should be used in ' +
            'development rather than in production.',
        },
      ],
      correct: ['a', 'b'],
      explanation:
        'Prompt caching lets a stable prefix be reused instead of reprocessed, and is best ' +
        'when requests rarely change across turns — the opposite of (d). The mechanism is a ' +
        '`cache_control` field of type `ephemeral` on the last block to be cached, with up to ' +
        'four breakpoints; for a multi-turn session with a stable system prompt and tool ' +
        'schemas the material calls it the highest-leverage cost reduction available. Token ' +
        'counting measures context pressure before a request is sent rather than after it ' +
        'fails, and runs no inference. Option (c) is the trap: when context fills, the oldest ' +
        'content is *not* silently truncated — the application must manage it by summarising.',
      page: 23,
      verify: false,
    },
    {
      id: 'context-memory-skills-004',
      domain: 'context-memory-skills',
      type: 'single',
      stem:
        'Three agents need different things: one continues a client thread over weeks, one ' +
        'runs self-contained overnight jobs, and one handles short single-sitting sessions ' +
        'that never restart. Which memory scopes does the material match to them?',
      options: [
        {
          id: 'a',
          text:
            'External storage for the continuing thread, stateless for the self-contained ' +
            'jobs, and in-context memory for the short sessions.',
        },
        {
          id: 'b',
          text:
            'Summarised memory for the continuing thread, in-context memory for the ' +
            'self-contained jobs, and external storage for the short sessions.',
        },
        {
          id: 'c',
          text:
            'External storage for all three, since it is the only scope from which nothing ' +
            'persisted is ever lost.',
        },
        {
          id: 'd',
          text:
            'In-context memory for the continuing thread and the short sessions, and ' +
            'summarised memory for the self-contained jobs.',
        },
      ],
      correct: ['a'],
      explanation:
        'The material gives these three matches directly: continue a thread across sessions to ' +
        'external storage, self-contained jobs to stateless, short sessions with no restart to ' +
        'in-context. Each carries its own cost — external storage adds retrieval latency and ' +
        'read/write logic, summarised memory depends on a good summariser prompt or critical ' +
        'state is lost, and in-context memory inflates token cost as the conversation grows. ' +
        'The takeaway is that memory scope is decided by the shape of the session, not by what ' +
        'is easiest to implement.',
      page: 26,
      verify: false,
    },
    {
      id: 'context-memory-skills-005',
      domain: 'context-memory-skills',
      type: 'single',
      stem:
        'A team has task-specific expertise that applies to perhaps one request in ten, plus ' +
        'project standards that apply to everything. Which mechanisms does the material match ' +
        'to each, and why?',
      options: [
        {
          id: 'a',
          text:
            'A skill for the task-specific expertise, loaded on demand when the request ' +
            'matches its description, and CLAUDE.md for the always-on standards.',
        },
        {
          id: 'b',
          text:
            'CLAUDE.md for both, since a single always-loaded file is cheaper than the ' +
            'matching machinery a skill requires.',
        },
        {
          id: 'c',
          text:
            'A skill for both, since skills are the lowest-context-cost mechanism and always-on ' +
            'standards benefit from that as much as occasional expertise does.',
        },
        {
          id: 'd',
          text:
            'In-context instructions for the task expertise and a skill for the standards, so ' +
            'that the rarely used material never enters a file at all.',
        },
      ],
      correct: ['a'],
      explanation:
        'The three patterns differ in when they are paid for. A skill is on-demand at the ' +
        'lowest context cost and suits task-specific expertise: its frontmatter carries a name ' +
        'and description, and the description is the matching criterion that decides whether ' +
        'the instructions load at all. CLAUDE.md is loaded every session at fixed overhead, ' +
        'which is what makes it right for always-on project standards. In-context instructions ' +
        'sit in every turn and grow with the session without outlasting it, so they suit short ' +
        'sessions where the full history fits in the window.',
      page: 27,
      verify: false,
    },
    {
      id: 'context-memory-skills-006',
      domain: 'context-memory-skills',
      type: 'single',
      stem:
        'A subagent is dispatched from an agent that has a skill enabled, and the parent\'s ' +
        'permissions apply to it. The subagent then fails to follow the skill\'s procedure. ' +
        'What is the explanation?',
      options: [
        {
          id: 'a',
          text:
            'Subagents do not automatically inherit skills — permissions are inherited, but a ' +
            'skill has to be registered explicitly in the subagent\'s configuration.',
        },
        {
          id: 'b',
          text:
            'Skills are inherited but only after the subagent\'s first turn, so a short-lived ' +
            'subagent may finish before the skill loads.',
        },
        {
          id: 'c',
          text:
            'Skills are inherited, so the failure must be a description mismatch: the ' +
            'subagent\'s task did not match the skill\'s description closely enough.',
        },
        {
          id: 'd',
          text:
            'Neither skills nor permissions are inherited, so the subagent is running with ' +
            'neither and both need registering.',
        },
      ],
      correct: ['a'],
      explanation:
        'The constraint is precise, and the asymmetry is the part worth remembering: ' +
        'permissions are inherited by a subagent, skills are not. A skill must be explicitly ' +
        'registered in the subagent config. Description matching is a real mechanism — it is ' +
        'what decides whether a registered skill loads — but it cannot explain a skill that ' +
        'was never available to match against.',
      page: 27,
      verify: false,
    },
  ],
});
