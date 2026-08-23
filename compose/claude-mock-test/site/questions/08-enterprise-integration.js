// Domain: enterprise-integration — "Identity, data handling and observability".
// Source: notes.txt pages 8-9 (architect track).
BANK.register({
  id: 'enterprise-integration',
  title: 'Identity, data handling and observability',
  questions: [
    {
      id: 'enterprise-integration-001',
      domain: 'enterprise-integration',
      type: 'single',
      stem:
        'A team argues that passing a full customer record into the context window is safe ' +
        'because the conversation is internal and the data never leaves the model. How should ' +
        'the architect correct this?',
      options: [
        {
          id: 'a',
          text:
            'The context window is not a data governance boundary: everything passed into a ' +
            'Claude call is transmitted to the API.',
        },
        {
          id: 'b',
          text:
            'The context window is a governance boundary, but only when the deployment routes ' +
            'through a CSP rather than the direct API.',
        },
        {
          id: 'c',
          text:
            'The concern is retention rather than transmission, so the control is a shorter ' +
            'retention setting rather than a change to what is sent.',
        },
        {
          id: 'd',
          text:
            'The record is safe to pass provided it is redacted from the response before the ' +
            'response reaches the user.',
        },
      ],
      correct: ['a'],
      explanation:
        'The material states it flatly: the context window is *not* a data governance ' +
        'boundary, because all data passed into a Claude call is transmitted to the API. The ' +
        'consequence is a design obligation — make a specific decision about which fields ' +
        'belong in the context window and which stay in the retrieval layer until needed, and ' +
        'pass only what the task absolutely requires. Routing, for instance, may need less ' +
        'data than processing. Redacting the response addresses the wrong direction of travel.',
      page: 9,
      verify: false,
    },
    {
      id: 'enterprise-integration-002',
      domain: 'enterprise-integration',
      type: 'single',
      stem:
        'An architect has established that a deployment falls under HIPAA and must stay in ' +
        'region. In the material\'s layered model, what does that constraint govern first?',
      options: [
        {
          id: 'a',
          text:
            'The delivery routes and entry points available at all, since BAA coverage, ' +
            'FedRAMP, data residency and approved-vendor lists eliminate options outright.',
        },
        {
          id: 'b',
          text:
            'The identity and SSO layer, because the user identity boundary is what a ' +
            'regulator examines first in an audit.',
        },
        {
          id: 'c',
          text:
            'The data handling and PII layer, since regulation is fundamentally about which ' +
            'fields may be processed.',
        },
        {
          id: 'd',
          text:
            'The observability layer, because demonstrating compliance depends on what was ' +
            'logged and for how long it was kept.',
        },
      ],
      correct: ['a'],
      explanation:
        'Compliance and regulated-industry constraints sit first because they impact delivery ' +
        'routes and entry points — options are eliminated by BAA coverage, FedRAMP, data ' +
        'residency and approved-vendor status before any other design question is asked. The ' +
        'remaining layers follow once the constraints are understood: identity and SSO, ' +
        'authorization and policy, data handling and PII, then observability and audit ' +
        'logging. Each of the other three is a real layer, just not the one the constraint ' +
        'reaches first.',
      page: 8,
      verify: false,
    },
    {
      id: 'enterprise-integration-003',
      domain: 'enterprise-integration',
      type: 'multi',
      stem:
        'A team is deciding what to record for each Claude call. Which two groupings match the ' +
        'material\'s observability list? (Select 2.)',
      options: [
        {
          id: 'a',
          text: 'Request: model version, input token count, prompt id.',
        },
        {
          id: 'b',
          text: 'Response: output token count, latency, stop reason.',
        },
        {
          id: 'c',
          text: 'Context: the full prompt text and every retrieved document, verbatim.',
        },
        {
          id: 'd',
          text: 'Outcome: the user\'s next three actions in the product after the response.',
        },
        {
          id: 'e',
          text: 'Request: the end user\'s name and email, for attribution.',
        },
      ],
      correct: ['a', 'b'],
      explanation:
        'The four groupings are request (model version, input token count, prompt id), ' +
        'response (output token count, latency, stop reason), context (user role, session id, ' +
        'caching) and outcome (accept and rejection signals). The wrong options each break a ' +
        'rule the material states elsewhere: context is user role and session id rather than ' +
        'verbatim content, outcome is the accept/reject signal rather than a behavioural ' +
        'trail, and PII fields must not appear in request logs — which is what makes (e) a ' +
        'defect rather than a nice-to-have.',
      page: 9,
      verify: false,
    },
    {
      id: 'enterprise-integration-004',
      domain: 'enterprise-integration',
      type: 'single',
      stem:
        'A platform team wants to enable agentic features — Claude taking actions rather than ' +
        'only answering — and plans to add tracing afterwards once usage justifies the work. ' +
        'What does the material say about that ordering?',
      options: [
        {
          id: 'a',
          text:
            'Observability is a precondition for enabling agents, and agentic actions must be ' +
            'recorded in the audit logs.',
        },
        {
          id: 'b',
          text:
            'The ordering is fine, because agent traces are only interpretable once there is ' +
            'enough traffic to establish a normal pattern to compare against.',
        },
        {
          id: 'c',
          text:
            'Tracing should wait, but the permission boundaries and approval flows have to be ' +
            'in place first, since those are what actually prevent an unwanted action.',
        },
        {
          id: 'd',
          text:
            'Neither is a precondition: the gating requirement for agentic features is an eval ' +
            'suite covering stopping behaviour, and observability follows from it.',
        },
      ],
      correct: ['a'],
      explanation:
        'The material makes observability a precondition for enabling agents, with agentic ' +
        'actions recorded in audit logs. The complexity note explains why the ordering cannot ' +
        'be reversed: logging has to be built to answer the production questions that need ' +
        'answering *before* anyone needs to ask them. Permission boundaries and stopping ' +
        'evals are genuine controls from elsewhere in the material, but neither is offered as ' +
        'a substitute for being able to reconstruct what the agent did.',
      page: 9,
      verify: false,
    },
    {
      id: 'enterprise-integration-005',
      domain: 'enterprise-integration',
      type: 'single',
      stem:
        'A multi-tenant SaaS product serves all tenants through one shared API key, and plans ' +
        'to add PII redaction later if a customer asks for it. Which two risks does the ' +
        'material name, and what does it recommend?',
      options: [
        {
          id: 'a',
          text:
            'Keep separate API keys per tenant for attribution and isolation, and allow for ' +
            'PII redaction in API calls up front, because retroactive redaction is expensive ' +
            'to implement.',
        },
        {
          id: 'b',
          text:
            'Keep the shared key for simpler quota management, and add redaction only in the ' +
            'logging layer, since that is where PII is actually retained.',
        },
        {
          id: 'c',
          text:
            'Separate keys per tenant, and rely on the provider\'s zero-retention setting ' +
            'instead of redaction, which removes the need to alter the request.',
        },
        {
          id: 'd',
          text:
            'Separate keys per environment rather than per tenant, and treat redaction as an ' +
            'eval concern rather than an architectural one.',
        },
      ],
      correct: ['a'],
      explanation:
        'Both come from this section\'s Cost/Complexity/Risk triad. The cost point is to allow ' +
        'for PII redaction in API calls, because retroactive redaction is expensive to ' +
        'implement — which is precisely the "add it later if asked" plan. The risk point is to ' +
        'keep separate API keys per tenant for attribution and isolation in any production ' +
        'multi-tenant deployment. Note that these are separate concerns: per-tenant keys give ' +
        'attribution and isolation, but they do nothing about what is in the payload.',
      page: 9,
      verify: false,
    },
    {
      id: 'enterprise-integration-006',
      domain: 'enterprise-integration',
      type: 'single',
      stem:
        'A deployment connects Claude to the full set of tools its MCP servers expose, on the ' +
        'grounds that unused tools are simply never called. What does least-privilege tool ' +
        'configuration require instead?',
      options: [
        {
          id: 'a',
          text:
            'Include only the connected tools the task actually requires, and remove the ' +
            'ones that are out of scope rather than leaving them connected and unused.',
        },
        {
          id: 'b',
          text:
            'Keep the tools connected but deny them in the permission rules, so the capability ' +
            'stays available for future use without being reachable now.',
        },
        {
          id: 'c',
          text:
            'Keep every tool connected and rely on the system prompt to state which ones are ' +
            'in scope for this task.',
        },
        {
          id: 'd',
          text:
            'Connect every tool but route each call through a human approval gate, so that ' +
            'scope is enforced at the moment of use rather than at configuration time.',
        },
      ],
      correct: ['a'],
      explanation:
        'Least-privilege tool configuration is stated simply: only include the required ' +
        'connected tools, and remove out-of-scope tools. The alternatives all leave the ' +
        'capability in place and add something on top — a rule, an instruction, or a reviewer ' +
        '— which is a weaker position than not granting it. It also costs context: every tool ' +
        'definition that is loaded is budget spent on a capability the task does not need.',
      page: 9,
      verify: false,
    },
  ],
});
