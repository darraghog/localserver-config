// Domain: prod-engineering — "Production engineering, evals, tracing and security".
// Source: notes.txt pages 36-38 (builder track).
BANK.register({
  id: 'prod-engineering',
  title: 'Production engineering, evals, tracing and security',
  questions: [
    {
      id: 'prod-engineering-001',
      domain: 'prod-engineering',
      type: 'single',
      stem:
        'A tool call returns HTTP 429, and later another returns 400. The application retries ' +
        'both with backoff. What does the material say about that handling?',
      options: [
        {
          id: 'a',
          text:
            'Sort each failure first: 429 and 529 are retriable because the condition clears ' +
            'with time, while 400 and 401 are terminal and will keep failing. Check what the ' +
            'SDK already retries before adding your own.',
        },
        {
          id: 'b',
          text:
            'Retrying both is correct, since any failure may be transient and a bounded retry ' +
            'costs less than a false terminal classification.',
        },
        {
          id: 'c',
          text:
            'Neither should be retried at the application level, because the SDK retries every ' +
            'retriable status already.',
        },
        {
          id: 'd',
          text:
            'Both are terminal from the loop\'s perspective: a failed tool call should be ' +
            'returned to Claude to decide, rather than retried by the application.',
        },
      ],
      correct: ['a'],
      explanation:
        'The first question for any tool error is whether it is retriable or terminal — a rate ' +
        'limit clears with time, a malformed request will continue to fail. The material gives ' +
        'the mapping: 429 (rate limit) and 529 (service overloaded) are retriable; 400 (bad ' +
        'request) and 401 (auth failure) are terminal. It also warns against duplicating work ' +
        'the SDK already does, since SDKs handle some retriable failures themselves — but "some" ' +
        'is not "all", which is what makes (c) too strong.',
      page: 37,
      verify: false,
    },
    {
      id: 'prod-engineering-002',
      domain: 'prod-engineering',
      type: 'single',
      stem:
        'A tool fails and the application returns an empty result block to Claude, expecting ' +
        'the model to notice something went wrong. What does the material say happens instead?',
      options: [
        {
          id: 'a',
          text:
            'An empty result is valid data from the model\'s perspective. Errors must come ' +
            'back explicitly, with `is_error` set to true.',
        },
        {
          id: 'b',
          text:
            'The model infers the failure from the missing content and retries the tool call ' +
            'on the next turn.',
        },
        {
          id: 'c',
          text:
            'The API rejects the turn, because a `tool_result` block cannot carry an empty ' +
            'payload.',
        },
        {
          id: 'd',
          text:
            'The result is treated as an error automatically whenever the underlying HTTP ' +
            'status was not 200.',
        },
      ],
      correct: ['a'],
      explanation:
        'Tool errors must come back to Claude explicitly, because an empty result is valid ' +
        'data from the model\'s perspective — an empty search result and a search that failed ' +
        'look identical. The mechanism is `is_error` set to true. Note also that HTTP status ' +
        'is not the test: a 200 response carrying a refusal is terminal based on its content ' +
        'rather than on being transient.',
      page: 37,
      verify: false,
    },
    {
      id: 'prod-engineering-003',
      domain: 'prod-engineering',
      type: 'multi',
      stem:
        'A team is deciding whether to enable prompt caching on a service with a fixed system ' +
        'prompt and stable tool schemas. Which two statements about the economics are ' +
        'accurate? (Select 2.)',
      options: [
        {
          id: 'a',
          text:
            'Cache writes are billed at a premium over base input tokens — 1.25× for the ' +
            '5-minute TTL and 2× for the 1-hour TTL.',
        },
        {
          id: 'b',
          text:
            'Cache reads cost a fraction of the base input rate, at 0.1×, which is what the ' +
            'write premium is repaid from.',
        },
        {
          id: 'c',
          text:
            'Cache writes are billed at the base input rate, and only the read is discounted, ' +
            'which is what makes caching unconditionally cheaper.',
        },
        {
          id: 'd',
          text:
            'There is no minimum length for caching, so any prefix however short is worth a ' +
            'breakpoint.',
        },
        {
          id: 'e',
          text:
            'Caching must be configured manually with `cache_control` markers; there is no ' +
            'automatic mode.',
        },
      ],
      correct: ['a', 'b'],
      explanation:
        'The premium on writes is what makes caching a calculation rather than a free win: ' +
        '1.25× for the 5-minute TTL, 2× for the 1-hour TTL, against reads at 0.1×. A prefix ' +
        'has to be reused enough to repay the write. There is a minimum length threshold that ' +
        'varies by model, and longer prompts cache better, so (d) is wrong. Setup can be ' +
        'automatic — a single cache flag at the top of the request, with the system managing ' +
        'breakpoints — or manual with `cache_control` markers on content blocks.',
      page: 38,
      verify: false,
    },
    {
      id: 'prod-engineering-004',
      domain: 'prod-engineering',
      type: 'single',
      stem:
        'A team proposes a multi-agent orchestration — a lead model planning, several subagent ' +
        'models fanning out, then synthesis — for a task that is essentially one long lookup. ' +
        'What does the material say about that choice?',
      options: [
        {
          id: 'a',
          text:
            'Use it only when the task requires genuine parallel exploration: it can perform ' +
            'significantly better than a single-agent run, but at roughly 15× the tokens.',
        },
        {
          id: 'b',
          text:
            'Multi-agent orchestration is the default for production work, since the quality ' +
            'gain over a single agent holds across task types.',
        },
        {
          id: 'c',
          text:
            'It is the wrong shape because the token cost is comparable, and the real ' +
            'objection is the added coordination latency alone.',
        },
        {
          id: 'd',
          text:
            'It should be adopted whenever elapsed time matters, since parallel subagents ' +
            'reduce wall-clock time without other costs.',
        },
      ],
      correct: ['a'],
      explanation:
        'The example given is a lead model with subagents performing significantly better than ' +
        'a single-agent run of the stronger model — at 15× the tokens. Hence the rule: only ' +
        'use it when the task requires genuine parallel exploration. The reference metrics ' +
        'spell out the rest of the bill. An orchestrator multiplies token consumption by the ' +
        'number of agents; parallel subagents can reduce elapsed time but add coordination ' +
        'latency for planning; and more agents means more failure points in the error rate.',
      page: 38,
      verify: false,
    },
    {
      id: 'prod-engineering-005',
      domain: 'prod-engineering',
      type: 'single',
      stem:
        'An agent summarises web pages fetched at runtime. A page contains hidden text ' +
        'instructing the agent to email a file to an external address. Which posture does the ' +
        'material prescribe?',
      options: [
        {
          id: 'a',
          text:
            'Treat anything the agent did not author as data rather than instructions, and ' +
            'constrain and log every consequential action.',
        },
        {
          id: 'b',
          text:
            'Rely on the model\'s training to recognise and refuse injected instructions, ' +
            'which is what makes a separate application boundary unnecessary.',
        },
        {
          id: 'c',
          text:
            'Restrict the agent to a curated allowlist of domains, after which fetched content ' +
            'can be treated as trusted instructions.',
        },
        {
          id: 'd',
          text:
            'Add a system-prompt instruction telling Claude to ignore instructions found in ' +
            'fetched content, which resolves the ambiguity at its source.',
        },
      ],
      correct: ['a'],
      explanation:
        'No agent that reads untrusted content is immune. Anthropic does train models to ' +
        'recognise and refuse injected instructions, but the material is explicit that ' +
        'model-defined boundaries are unreliable, whereas deterministic application boundaries ' +
        'are less probabilistic and more guaranteed — which is why (b) and (d) both stop ' +
        'short. The defensive posture is that the agent treats anything it did not author as ' +
        'data, with consequential actions constrained and logged, an action boundary defined ' +
        'by identity and access, and hooks enforcing the control — where deny takes precedence ' +
        'over any allow.',
      page: 38,
      verify: false,
    },
    {
      id: 'prod-engineering-006',
      domain: 'prod-engineering',
      type: 'single',
      stem:
        'Every component of a document pipeline passes its unit tests, yet the flow produces ' +
        'wrong output in production. Which test type and which diagnostic does the material ' +
        'point to?',
      options: [
        {
          id: 'a',
          text:
            'Integration tests, which exercise the handoff between two components, with ' +
            'tracing to record each step of the run.',
        },
        {
          id: 'b',
          text:
            'More unit tests, since a flow that fails while its components pass means the ' +
            'component tests are not covering enough cases.',
        },
        {
          id: 'c',
          text:
            'End-to-end tests only, since they exercise the flow as a user would and therefore ' +
            'subsume what an integration test would catch.',
        },
        {
          id: 'd',
          text:
            'An LLM-judge eval over the final output, since the failure is one of quality ' +
            'rather than of wiring.',
        },
      ],
      correct: ['a'],
      explanation:
        'The material\'s takeaway is that most silent failures hide at the integration seam ' +
        'where component handoffs happen — individual components can pass their tests while ' +
        'the handoff fails. That is exactly what an integration test exercises. Tracing is the ' +
        'companion: it records each step of a run — prompt, tool calls, intermediate outputs, ' +
        'timing — so the failure can be located rather than inferred. End-to-end tests are a ' +
        'real category but tell you that the flow failed, not where.',
      page: 36,
      verify: false,
    },
  ],
});
