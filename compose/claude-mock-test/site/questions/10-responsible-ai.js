// Domain: responsible-ai — "Control layers, guardrails, fairness, HITL, compliance".
// Source: notes.txt pages 11-13 (architect track).
BANK.register({
  id: 'responsible-ai',
  title: 'Control layers, guardrails, fairness, HITL, compliance',
  questions: [
    {
      id: 'responsible-ai-001',
      domain: 'responsible-ai',
      type: 'single',
      stem:
        'A project team assumed that Claude would refuse to disclose one business unit\'s data ' +
        'to another, and so built no authorization check. Which failure does the material use ' +
        'this example to name?',
      options: [
        {
          id: 'a',
          text:
            'Conflating domain policy with trained alignment — assuming Claude enforces a ' +
            'domain rule it was never given, which fails silently.',
        },
        {
          id: 'b',
          text:
            'Under-specifying the system prompt, since a clearly stated confidentiality ' +
            'instruction would have covered the case.',
        },
        {
          id: 'c',
          text:
            'Missing output screening, since the disclosure is visible in the response and ' +
            'could have been caught before it was returned.',
        },
        {
          id: 'd',
          text:
            'Choosing the wrong model tier, since cross-unit reasoning of this kind is ' +
            'reliable only on the more capable tiers.',
        },
      ],
      correct: ['a'],
      explanation:
        'Trained behaviour is owned by Anthropic and covers broad classes of harmful or unsafe ' +
        'output; it explicitly excludes domain policy, data rules and the authorization model. ' +
        'The named risk is assuming Claude enforces a domain rule it was never given, and the ' +
        'failure is silent — nothing reports that the control was absent. Whether an action ' +
        'with a side effect is permitted for this caller in this context is the authorization ' +
        'layer\'s job, which is why a stronger instruction or a screening pass does not ' +
        'substitute for it.',
      page: 11,
      verify: false,
    },
    {
      id: 'responsible-ai-002',
      domain: 'responsible-ai',
      type: 'single',
      stem:
        'A design places a single model-based screen on the response, arguing that anything ' +
        'harmful — a bad input, an unauthorised tool call, or unsafe content — ultimately shows ' +
        'up in what is returned. What does the material say?',
      options: [
        {
          id: 'a',
          text:
            'Output screening is not a control for actions or for inputs. Input screening ' +
            'decides whether a request reaches the model at all, and tool-call authorization ' +
            'runs before any action with side effects.',
        },
        {
          id: 'b',
          text:
            'A single output screen is sufficient provided it is model-based rather than ' +
            'deterministic, since only a model can recognise the full range of harms.',
        },
        {
          id: 'c',
          text:
            'The screen should move to the input instead, since stopping a bad request before ' +
            'it reaches the model covers every downstream case at lower cost.',
        },
        {
          id: 'd',
          text:
            'Screening placement is a tuning decision that should follow the first production ' +
            'incident, since where harm actually appears is not knowable in advance.',
        },
      ],
      correct: ['a'],
      explanation:
        'The three guardrails sit at different points on the request path and answer different ' +
        'questions: input screening decides whether the request should reach the model at all, ' +
        'output screening decides whether the model\'s output is safe to return, and tool-call ' +
        'authorization runs before any action with side effects. The material states the trap ' +
        'directly — output screening is not a control for actions or inputs — because by the ' +
        'time an unauthorised action has been taken, screening the text describing it changes ' +
        'nothing.',
      page: 12,
      verify: false,
    },
    {
      id: 'responsible-ai-003',
      domain: 'responsible-ai',
      type: 'multi',
      stem:
        'A team is deciding which screens should be model-based and which deterministic. Which ' +
        'two choices match the material? (Select 2.)',
      options: [
        {
          id: 'a',
          text:
            'Model-based input screening for ambiguous or injection-style input, with code for ' +
            'clear, defined rules such as regex, length and format.',
        },
        {
          id: 'b',
          text:
            'Code for tool-call authorization — permitted actions, identity checks, scope ' +
            'validation — because it must be provable and replayable.',
        },
        {
          id: 'c',
          text:
            'Model-based tool-call authorization, so that novel and unforeseen action patterns ' +
            'can be judged on their merits rather than against a fixed list.',
        },
        {
          id: 'd',
          text:
            'Code for output screening of toxicity and policy compliance, since a rule set is ' +
            'auditable where a model judgement is not.',
        },
        {
          id: 'e',
          text:
            'Model-based screening at every point, so that one screening component can be ' +
            'reused across input, output and tool calls.',
        },
      ],
      correct: ['a', 'b'],
      explanation:
        'The split follows how well-defined the judgement is. Input screening uses a model for ' +
        'ambiguous or injection input and code for clear, defined rules. Output screening ' +
        'inverts part of that: a model for toxicity and policy compliance, code for checking ' +
        'specific fields and schemas — which is why (d) has it backwards. Tool-call ' +
        'authorization is rarely model-based; it is code, because it must be provable and ' +
        'replayable, and a judgement that cannot be replayed cannot be evidence.',
      page: 12,
      verify: false,
    },
    {
      id: 'responsible-ai-004',
      domain: 'responsible-ai',
      type: 'single',
      stem:
        'A decision is irreversible and expensive to get wrong, but the model returns it with ' +
        'high confidence. The team proposes letting it through on the strength of the ' +
        'confidence score. What does the material say about the conflict?',
      options: [
        {
          id: 'a',
          text:
            'Give greater weight to cost and reversibility, because those determine the ' +
            'consequences; do not let confidence decide this case.',
        },
        {
          id: 'b',
          text:
            'Give greater weight to confidence, because it is the only one of the three that ' +
            'is measured per request rather than assumed at design time.',
        },
        {
          id: 'c',
          text:
            'Treat the three as equally weighted and route when a majority indicate risk, so ' +
            'that no single variable can force a review queue to grow.',
        },
        {
          id: 'd',
          text:
            'Escalate to a policy owner, since a conflict between the routing variables means ' +
            'the routing rule itself does not cover the case.',
        },
      ],
      correct: ['a'],
      explanation:
        'The routing rule sends a decision to a person when confidence is low, or when the ' +
        'decision is irreversible or high-cost to reverse; confident, reversible, low-cost ' +
        'decisions can be let through. When the variables conflict, the material is explicit ' +
        'that cost and reversibility carry the greater weight, because they determine the ' +
        'consequences — a confident model is still sometimes wrong, and here being wrong ' +
        'cannot be undone.',
      page: 13,
      verify: false,
    },
    {
      id: 'responsible-ai-005',
      domain: 'responsible-ai',
      type: 'single',
      stem:
        'Reviewers on a deployment approve almost every step put in front of them and have ' +
        'stopped reading closely. Which combination of changes does the material point to?',
      options: [
        {
          id: 'a',
          text:
            'Move review away from per-step approvals towards higher-value checkpoints such as ' +
            'plan review and exception handling, and give reviewers the inputs, the model ' +
            'output and the reason the item was flagged.',
        },
        {
          id: 'b',
          text:
            'Keep the per-step approvals but rotate reviewers more frequently, so that no ' +
            'individual sees enough consecutive items to become desensitised.',
        },
        {
          id: 'c',
          text:
            'Replace the human gate with sampled review across the board, since a gate that is ' +
            'always approved is providing no signal that sampling would not.',
        },
        {
          id: 'd',
          text:
            'Raise the confidence threshold so fewer items route to review, and accept the ' +
            'items below it without a record.',
        },
      ],
      correct: ['a'],
      explanation:
        'This is consent fatigue, and the material names the fix: drive review activity away ' +
        'from per-step approvals towards higher-value checkpoints — plan review or exception ' +
        'handling. The second half matters as much. Reviewers need the inputs, the model ' +
        'outputs and the reason the item was flagged, because that context is what lets them ' +
        'tell an edge case from a routine one and judge whether the output is accurate. ' +
        'Sampled review is a real placement, but it monitors the system overall rather than ' +
        'governing specific decisions, so it is not a drop-in replacement for a gate on ' +
        'high-stakes items.',
      page: 13,
      verify: false,
    },
    {
      id: 'responsible-ai-006',
      domain: 'responsible-ai',
      type: 'single',
      stem:
        'An architect is asked where unfairness could enter a claims system that retrieves ' +
        'precedent documents, uses few-shot examples in its prompt, and routes cases down ' +
        'different handling paths. Which answer matches the material?',
      options: [
        {
          id: 'a',
          text:
            'All of those points: a skewed retrieval corpus, assumptions in prompt framing, ' +
            'skew in the few-shot examples, and downstream routing — and an injection point ' +
            'left unmeasured can hide unfairness.',
        },
        {
          id: 'b',
          text:
            'Only the retrieval corpus, since the prompt and the routing logic are authored ' +
            'deliberately and can be inspected directly.',
        },
        {
          id: 'c',
          text:
            'Only the model itself, since fairness is a property of training and the ' +
            'surrounding system merely passes its outputs along.',
        },
        {
          id: 'd',
          text:
            'None of them individually — unfairness is only observable in aggregate outcomes, ' +
            'so the assessment belongs after deployment rather than in the design.',
        },
      ],
      correct: ['a'],
      explanation:
        'Four injection points are listed: the retrieval corpus (skewed knowledge), prompt ' +
        'framing (assumptions), few-shot examples (skew), and downstream routing (which ' +
        'determines paths). The associated risk is that an unmeasured injection point can hide ' +
        'unfairness — which is the argument against (d), since measuring outcomes without ' +
        'instrumenting the points where skew enters leaves you unable to attribute what you ' +
        'find. Discernment is what lets a reviewer recognise a skewed or unjustified outcome, ' +
        'and the transparency record is what makes that recognition possible.',
      page: 12,
      verify: false,
    },
  ],
});
