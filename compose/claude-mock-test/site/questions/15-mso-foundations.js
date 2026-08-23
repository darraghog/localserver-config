// Domain: mso-foundations — "Tokens, sampling, model and reasoning modes, SDK/REST/streaming".
// Source: notes.txt pages 19-20 (builder track).
BANK.register({
  id: 'mso-foundations',
  title: 'Tokens, sampling, model and reasoning modes, SDK/REST/streaming',
  questions: [
    {
      id: 'mso-foundations-001',
      domain: 'mso-foundations',
      type: 'single',
      stem:
        'A developer sizing a request counts the system prompt and the user message against ' +
        'the context window, and treats the conversation so far, the attached documents, the ' +
        'tool results and the response as separate. What does the material say the context ' +
        'window holds?',
      options: [
        {
          id: 'a',
          text:
            'All of it — the prompt, the conversation so far, documents, tool results and the ' +
            'model\'s own output are one fixed token budget holding the whole request at once.',
        },
        {
          id: 'b',
          text:
            'Input only. Output tokens are drawn from a separate budget, which is why they are ' +
            'priced differently.',
        },
        {
          id: 'c',
          text:
            'Everything except tool results, which are supplied to the model out of band and ' +
            'do not consume the window.',
        },
        {
          id: 'd',
          text:
            'Everything in the current turn only — earlier turns are summarised by the ' +
            'platform and do not count against the window.',
        },
      ],
      correct: ['a'],
      explanation:
        'The context window is the number of tokens the model can take in a single request, ' +
        'and the material enumerates what that includes: the prompt, the conversation so far, ' +
        'documents, tool results and the model output. The takeaway states it as a single ' +
        'idea — the context window is a fixed token budget that holds the whole request at ' +
        'once. Nothing is supplied out of band, and nothing from an earlier turn is free.',
      page: 19,
      verify: false,
    },
    {
      id: 'mso-foundations-002',
      domain: 'mso-foundations',
      type: 'single',
      stem:
        'A test asserts that a summarisation endpoint returns one exact expected string, and ' +
        'fails intermittently. What does the material prescribe?',
      options: [
        {
          id: 'a',
          text:
            'Do not test on the output itself — test on property assertions; and where the ' +
            'judgement is about meaning rather than structure, use an eval with a model-graded ' +
            'judge.',
        },
        {
          id: 'b',
          text:
            'Set temperature to zero, which removes sampling variance and makes exact-match ' +
            'assertions reliable.',
        },
        {
          id: 'c',
          text:
            'Retry the assertion up to three times and pass if any attempt matches, since ' +
            'sampling variance is bounded.',
        },
        {
          id: 'd',
          text:
            'Move the assertion to a cosine-similarity threshold against the expected string, ' +
            'which is the standard fix for every non-deterministic output.',
        },
      ],
      correct: ['a'],
      explanation:
        'Sampling means the model draws from a probability distribution and each run can ' +
        'produce a different result. The material\'s rule follows directly: do not test on ' +
        'output, test on property assertion — and when what matters is meaning rather than ' +
        'structure, use an eval with a model-graded judge. Temperature concentrates ' +
        'probability on the most likely tokens but is not offered as a determinism switch, and ' +
        'not all models even accept temperature, top_p or top_k.',
      page: 19,
      verify: false,
    },
    {
      id: 'mso-foundations-003',
      domain: 'mso-foundations',
      type: 'single',
      stem:
        'A team wants deeper reasoning on a hard multi-step problem and assumes that means ' +
        'moving up a model tier. What does the material say about the relationship between ' +
        'model and reasoning mode?',
      options: [
        {
          id: 'a',
          text:
            'They are independent, composable levers set separately — and with adaptive ' +
            'thinking the model decides when and how much to think, with depth tuned by the ' +
            'effort setting rather than a token budget.',
        },
        {
          id: 'b',
          text:
            'Reasoning mode is a property of the model tier, so deeper reasoning is obtained ' +
            'by moving up a tier and cannot be requested separately.',
        },
        {
          id: 'c',
          text:
            'They are independent, but reasoning depth is set by assigning a thinking token ' +
            'budget, which is the supported control across the current models.',
        },
        {
          id: 'd',
          text:
            'Reasoning mode should be turned on for every workload, since a model that thinks ' +
            'before answering is strictly better on any task type.',
        },
      ],
      correct: ['a'],
      explanation:
        'Model choice and reasoning mode are separate, composable levers — one of the ' +
        'section\'s five takeaways. Adaptive thinking lets the model decide when and how much ' +
        'to think, and the depth control is the effort setting rather than a token budget: on ' +
        'the current models a thinking token budget is rejected outright, which is what makes ' +
        '(c) wrong rather than merely dated. Reasoning is also not free — the material calls ' +
        'it overkill for lookups and classifications. Version-sensitive: per-model defaults ' +
        'differ and the controls have moved recently, so re-check against the documentation.',
      page: 19,
      verify: true,
    },
    {
      id: 'mso-foundations-004',
      domain: 'mso-foundations',
      type: 'single',
      stem:
        'A prompt for a straightforward extraction task carries six worked examples. The ' +
        'author argues that more examples can only help. What is the material\'s position?',
      options: [
        {
          id: 'a',
          text:
            'Each example consumes tokens and context budget, so the aim is the smallest ' +
            'prompt that produces a reliable result — simple tasks zero-shot, complex or ' +
            'edge-case work multi-shot.',
        },
        {
          id: 'b',
          text:
            'More examples are always safer, because examples act as training data for the ' +
            'task and additional data cannot reduce accuracy.',
        },
        {
          id: 'c',
          text:
            'Examples should be removed entirely once the model tier is capable enough, since ' +
            'a capable model treats them as noise.',
        },
        {
          id: 'd',
          text:
            'Example count should be fixed at three across a codebase, so that prompt cost is ' +
            'predictable and comparisons between prompts stay fair.',
        },
      ],
      correct: ['a'],
      explanation:
        'Examples sit in the prompt and are not training data — their job is to give the exact ' +
        'shape of an answer that a description alone does not convey. The trade-off is ' +
        'explicit: each one consumes tokens and context budget, so add the smallest amount of ' +
        'prompt that produces a reliable result. The joint rule with model choice is to find ' +
        'the simplest model and the fewest examples that meet the eval — a capable model may ' +
        'need none, a less capable one may need several.',
      page: 20,
      verify: false,
    },
    {
      id: 'mso-foundations-005',
      domain: 'mso-foundations',
      type: 'single',
      stem:
        'A developer asks why they should use the Python SDK rather than calling the REST ' +
        'endpoint directly. What does the material say the SDK is?',
      options: [
        {
          id: 'a',
          text:
            'A thin convenience layer over the same REST API, handling authentication, request ' +
            'construction, retries and response parsing so there is less boilerplate.',
        },
        {
          id: 'b',
          text:
            'A separate protocol with capabilities the REST API does not expose, which is why ' +
            'the SDK is the recommended path for production.',
        },
        {
          id: 'c',
          text:
            'A local runtime that manages the agent loop on the developer\'s behalf, which the ' +
            'REST API leaves to the caller.',
        },
        {
          id: 'd',
          text:
            'A managed queue in front of the API that smooths rate limits, making it the right ' +
            'choice for bulk workloads.',
        },
      ],
      correct: ['a'],
      explanation:
        'Claude is reached over an HTTP REST API returning JSON, usually invoked through an ' +
        'SDK that is described as a thin convenience layer: it handles authentication, request ' +
        'construction, retries and response parsing. Option (c) describes the Agent SDK, which ' +
        'is a different thing — the language SDK does not run an agent loop.',
      page: 20,
      verify: false,
    },
    {
      id: 'mso-foundations-006',
      domain: 'mso-foundations',
      type: 'multi',
      stem:
        'A team must choose between streaming and the Message Batches API for two workloads: a ' +
        'chat feature where a user waits for a long response, and an overnight evaluation run ' +
        'over a large corpus. Which two statements from the material apply? (Select 2.)',
      options: [
        {
          id: 'a',
          text:
            'Streaming suits long responses or a waiting user, and is delivered over HTTP ' +
            'using server-sent events.',
        },
        {
          id: 'b',
          text:
            'The Batches API suits offline pipelines, evaluation runs and bulk jobs: submit ' +
            'many requests in one call, receive an id, and poll for completion.',
        },
        {
          id: 'c',
          text:
            'The Batches API returns results faster than synchronous requests, which is why ' +
            'bulk jobs are routed to it.',
        },
        {
          id: 'd',
          text:
            'Streaming lowers per-token cost relative to a synchronous request, since partial ' +
            'output can be discarded before completion.',
        },
        {
          id: 'e',
          text:
            'An async client is required for streaming, because server-sent events cannot be ' +
            'consumed from a synchronous call.',
        },
      ],
      correct: ['a', 'b'],
      explanation:
        'Three patterns, three jobs. Synchronous requests are simplest and suit short ' +
        'responses and back-end batch work; streaming suits long responses or a waiting user ' +
        'and is sent over HTTP using server-sent events; the Message Batches API is a separate ' +
        'pattern for bulk offline workloads — submit many requests in one call, get an id, ' +
        'poll for completion. The batch trade is the opposite of (c): it may take up to 24 ' +
        'hours, and the compensation is a lower per-token cost. Async clients are about ' +
        'concurrency without blocking, not a prerequisite for streaming.',
      page: 20,
      verify: false,
    },
  ],
});
