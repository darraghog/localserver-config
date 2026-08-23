// Domain: prod-prompting-tools — "Production prompting, extended thinking, tool schemas, the loop".
// Source: notes.txt pages 20-22 (builder track).
BANK.register({
  id: 'prod-prompting-tools',
  title: 'Production prompting, extended thinking, tool schemas, the loop',
  questions: [
    {
      id: 'prod-prompting-tools-001',
      domain: 'prod-prompting-tools',
      type: 'single',
      stem:
        'An extraction prompt returns the right facts but wraps them in a different JSON shape ' +
        'each time. The team\'s response is to add another paragraph of guidance to the ' +
        'instructions. Which technique does the symptom actually call for?',
      options: [
        {
          id: 'a',
          text:
            'Output constraints — field names, types, lengths, limits, preambles and ' +
            'missing-data handling — since the output is meant to be machine readable.',
        },
        {
          id: 'b',
          text:
            'A more detailed system prompt, since the behavioural contract for the session is ' +
            'what governs how responses are shaped.',
        },
        {
          id: 'c',
          text:
            'Few-shot examples, since a varying shape means the model has not been shown what ' +
            'the answer should look like.',
        },
        {
          id: 'd',
          text:
            'Extended thinking, so the model plans the structure of its answer before ' +
            'committing to it.',
        },
      ],
      correct: ['a'],
      explanation:
        'The symptom table maps each complaint to one technique: wrong format to output ' +
        'constraints, wrong content or scope drift to a missing or under-specified system ' +
        'prompt, a correct task with hallucinated structure to few-shot examples, and good ' +
        'output that breaks on edge cases to a prompt that only handles the happy path. This ' +
        'is wrong format, so it is an output-constraint problem — and the material names the ' +
        'exact failure the team is committing: adding more to the prompt instead of addressing ' +
        'output constraints.',
      page: 21,
      verify: false,
    },
    {
      id: 'prod-prompting-tools-002',
      domain: 'prod-prompting-tools',
      type: 'multi',
      stem:
        'A team sets `strict: true` on their tool definitions so that arguments are validated ' +
        'against the schema before their code runs. Which two consequences does the material ' +
        'tell them to expect? (Select 2.)',
      options: [
        {
          id: 'a',
          text:
            'The first request is slower, because the API compiles the schema into a grammar; ' +
            'that cache is refreshed every 24 hours.',
        },
        {
          id: 'b',
          text:
            'A guaranteed schema does not guarantee success — a refusal or a truncation is ' +
            'still possible, so `stop_reason` has to be checked.',
        },
        {
          id: 'c',
          text:
            'Input token count falls, because a schema replaces the instructions that would ' +
            'otherwise describe the format in prose.',
        },
        {
          id: 'd',
          text:
            'Constrained generation composes with message prefilling, so a response can be ' +
            'both started for Claude and schema-constrained on the same request.',
        },
        {
          id: 'e',
          text:
            'Validation runs on the model side only, so the application no longer needs to ' +
            'handle malformed arguments defensively.',
        },
      ],
      correct: ['a', 'b'],
      explanation:
        'Constraining generation has real costs. The first request is slower because the API ' +
        'compiles the schema into a grammar, with that cache refreshed every 24 hours, and ' +
        'input token count *rises* rather than falls to accommodate the system prompt — which ' +
        'is what (c) inverts. The trap worth remembering is that a guaranteed schema does not ' +
        'guarantee success: a refusal or truncation can still occur, so check `stop_reason`. ' +
        'Constrained generation also does not combine with message prefilling; the two ' +
        'patterns cannot run on the same request, so the choice is made per task.',
      page: 21,
      verify: false,
    },
    {
      id: 'prod-prompting-tools-003',
      domain: 'prod-prompting-tools',
      type: 'single',
      stem:
        'An agentic loop has extended thinking enabled and calls tools across several turns. ' +
        'The application strips thinking blocks from the history to save context. What breaks?',
      options: [
        {
          id: 'a',
          text:
            'The carry-back rule: with extended thinking enabled and tools in use, every ' +
            'thinking block must be returned to the API exactly as it arrived.',
        },
        {
          id: 'b',
          text:
            'Nothing breaks — thinking blocks are advisory, and dropping them is the ' +
            'recommended way to reclaim context in a long agentic loop.',
        },
        {
          id: 'c',
          text:
            'Only the display breaks: the reasoning is no longer visible to the user, but the ' +
            'loop continues to function.',
        },
        {
          id: 'd',
          text:
            'The tool results become unattributable, so the API returns them in a later turn ' +
            'rather than the immediately following one.',
        },
      ],
      correct: ['a'],
      explanation:
        'The carry-back rule is stated without exception: if extended thinking is enabled and ' +
        'tools are used, every thinking block has to be returned to the API as it arrived — ' +
        'unmodified, not summarised, not dropped. It is worth knowing when *not* to have ' +
        'thinking on at all: it earns its place in multi-step reasoning where several ' +
        'constraints are held at once, and in agentic loops where the model plans across ' +
        'several tool calls, but it should be disabled for mechanical work such as ' +
        'classification, format conversion and field extraction. This area is ' +
        'version-sensitive — how thinking is requested and displayed has changed recently — so ' +
        're-check it against the documentation.',
      page: 21,
      verify: true,
    },
    {
      id: 'prod-prompting-tools-004',
      domain: 'prod-prompting-tools',
      type: 'single',
      stem:
        'An application receives an assistant turn containing two `tool_use` blocks. It ' +
        'executes both tools, returns one result immediately and queues the second for the ' +
        'turn after next. What does the material say about this?',
      options: [
        {
          id: 'a',
          text:
            'It violates the critical invariant: every `tool_use` block needs its ' +
            '`tool_result` in the immediately following user turn.',
        },
        {
          id: 'b',
          text:
            'It is acceptable, since results are matched by the `tool_use` id rather than by ' +
            'turn position.',
        },
        {
          id: 'c',
          text:
            'It is acceptable only if `disable_parallel_tool` is set, which tells the API to ' +
            'expect results across multiple turns.',
        },
        {
          id: 'd',
          text:
            'It is a performance problem rather than a correctness one: the loop still runs, ' +
            'but the deferred call costs an extra round trip.',
        },
      ],
      correct: ['a'],
      explanation:
        'The invariant is explicit: every `tool_use` block from an assistant turn must have a ' +
        'corresponding `tool_result` block in the immediately following user turn, and the API ' +
        'raises a validation error if results are missing or appear in a later turn. Unique ' +
        'ids identify which result belongs to which call, but they do not license deferring ' +
        'one. `disable_parallel_tool` addresses a different question — forcing one tool call ' +
        'per turn so subtasks run sequentially.',
      page: 22,
      verify: false,
    },
    {
      id: 'prod-prompting-tools-005',
      domain: 'prod-prompting-tools',
      type: 'single',
      stem:
        'A tool definition marks every parameter as required and carries a one-line ' +
        'description. Two other tools accept a similarly named string parameter. Which ' +
        'problems does the material predict?',
      options: [
        {
          id: 'a',
          text:
            'Marking everything required invites fabricated values, a one-line description ' +
            'gives too little to decide on, and overlapping parameter types cause wrong-tool ' +
            'calls.',
        },
        {
          id: 'b',
          text:
            'Only the description is a problem: required fields and overlapping parameters are ' +
            'resolved by schema validation before the tool runs.',
        },
        {
          id: 'c',
          text:
            'Marking everything required is correct practice, since optional parameters are ' +
            'the main cause of malformed tool arguments.',
        },
        {
          id: 'd',
          text:
            'None of these matter once `strict: true` is set, because validation catches a ' +
            'wrong-tool call before the application executes anything.',
        },
      ],
      correct: ['a'],
      explanation:
        'Three items from the tool-calling decision table land here. Making all fields ' +
        'required can push Claude to fabricate values, so only non-negotiable fields should be ' +
        'required — optional fields are for parameters with sensible defaults or where absence ' +
        'itself carries meaning. Descriptions should run three to four sentences covering what ' +
        'the tool does, when to use it and what it returns, with examples of valid input, ' +
        'because the description is what Claude uses to decide whether the tool is needed. And ' +
        'overlapping parameter types between tools are a common source of wrong-tool calls, ' +
        'answered with disambiguating language. Schema validation checks the shape of a call, ' +
        'never whether it was the right tool.',
      page: 22,
      verify: false,
    },
    {
      id: 'prod-prompting-tools-006',
      domain: 'prod-prompting-tools',
      type: 'single',
      stem:
        'A prompt asks Claude to debug a code sample using some supplied documentation, and ' +
        'the model keeps confusing which text is the instruction and which is the input. Which ' +
        'technique applies, and what does the material say about its form?',
      options: [
        {
          id: 'a',
          text:
            'XML tags, which create unambiguous boundaries when a prompt mixes inputs with ' +
            'instructions — and the tag names can be descriptive rather than formal XML.',
        },
        {
          id: 'b',
          text:
            'XML tags, which must be valid, schema-declared XML element names for the parser ' +
            'to treat them as boundaries.',
        },
        {
          id: 'c',
          text:
            'Markdown headings, which are the recommended separator because they cost fewer ' +
            'tokens than tags.',
        },
        {
          id: 'd',
          text:
            'A second request, splitting the documentation and the code into separate calls so ' +
            'that no single prompt mixes the two.',
        },
      ],
      correct: ['a'],
      explanation:
        'XML tags are the named technique for prompts that mix inputs with instructions, and ' +
        'the debugging-code-with-supplied-docs case is the material\'s own example. The tags ' +
        'create unambiguous boundaries, and they can be descriptive rather than formal XML tag ' +
        'names — nothing is parsed as XML. The same consistency is asked of few-shot examples, ' +
        'which should be wrapped in a consistent XML structure so the boundary between example ' +
        'and prompt stays clear.',
      page: 20,
      verify: false,
    },
  ],
});
