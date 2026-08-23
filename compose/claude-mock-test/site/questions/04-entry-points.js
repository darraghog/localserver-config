// Domain: entry-points — "Entry points, routes and Claude Code governance layers".
// Source: notes.txt pages 3-4 (architect track).
BANK.register({
  id: 'entry-points',
  title: 'Entry points, routes and Claude Code governance layers',
  questions: [
    {
      id: 'entry-points-001',
      domain: 'entry-points',
      type: 'single',
      stem:
        'A partner is building a claims-summarisation feature that lives entirely inside one ' +
        'internal web product. No other team or client will call the tools it defines. Which ' +
        'build-time interface does the material point them at, and why?',
      options: [
        {
          id: 'a',
          text:
            'The API or SDK, because the tools live inside a single product and MCP exists to ' +
            'share tools across clients and entry points — a problem this partner does not have.',
        },
        {
          id: 'b',
          text:
            'MCP, because standing the tools up behind a server now is what keeps the option ' +
            'open to reuse them from other products later, and retro-fitting a server onto ' +
            'tools already written against the API costs more than building it once up front.',
        },
        {
          id: 'c',
          text:
            'The Agent SDK, because any feature that calls tools needs a managed agent loop ' +
            'rather than a single request-response exchange.',
        },
        {
          id: 'd',
          text:
            'Claude Code, because it already ships the tool-calling loop and the permission ' +
            'system, so the team writes no integration code at all.',
        },
      ],
      correct: ['a'],
      explanation:
        'The rule is about reach, not sophistication: MCP earns its cost when tools must be ' +
        'reusable across clients and shared across products; use the API when the tools live ' +
        'inside a single product. The material separately warns against reaching for MCP as ' +
        'the default integration layer, which is exactly the "keep the option open" reasoning ' +
        'in (b). The Agent SDK is for when an in-code managed agent loop is needed and the ' +
        'Claude Code CLI is the wrong shape — not a requirement of tool use itself — and ' +
        'Claude Code on non-engineering work is another named anti-pattern.',
      page: 3,
      verify: false,
    },
    {
      id: 'entry-points-002',
      domain: 'entry-points',
      type: 'single',
      stem:
        'An architect is describing Claude Code\'s customisation and governance layers to a ' +
        'platform team. Which description matches the material\'s split between the two layers?',
      options: [
        {
          id: 'a',
          text:
            'Layer 1 shapes what the agent knows and does — CLAUDE.md, skills, subagents, MCP; ' +
            'Layer 2 governs what it can touch — hooks, permission boundaries, approval flows ' +
            'and sandboxing.',
        },
        {
          id: 'b',
          text:
            'Layer 1 covers everything an individual configures for themselves, and Layer 2 ' +
            'covers everything an administrator pushes down at the enterprise level, so the ' +
            'split follows who owns the setting rather than what the setting controls.',
        },
        {
          id: 'c',
          text:
            'Layer 1 is what applies before the agent starts, and Layer 2 is what applies once ' +
            'it is running, so the two never take effect at the same time.',
        },
        {
          id: 'd',
          text:
            'Layer 1 is the free tier of configuration and Layer 2 unlocks with an enterprise ' +
            'plan, so the split is commercial rather than technical.',
        },
      ],
      correct: ['a'],
      explanation:
        'A layer is defined as a discrete configuration entry point controlling one aspect of ' +
        'agent behaviour, and the layers are independent, composable, and applied at different ' +
        'points. The split is by what they control — shaping knowledge and capability versus ' +
        'governing reach — not by who sets them, when they fire, or what they cost. Both ' +
        'layers contain per-user and administrator-set mechanisms.',
      page: 3,
      verify: false,
    },
    {
      id: 'entry-points-003',
      domain: 'entry-points',
      type: 'single',
      stem:
        'A partner already standardised on AWS and asks whether moving from the direct ' +
        'Anthropic API to Bedrock will change the answers their application produces, and what ' +
        'the real trade-off is. What should the architect tell them?',
      options: [
        {
          id: 'a',
          text:
            'Model behaviour is the same regardless of route — only the wrapper changes — but ' +
            'CSP-mediated routes lag the first-party API on new features by weeks or more.',
        },
        {
          id: 'b',
          text:
            'Bedrock-hosted models are tuned for the platform, so outputs differ enough that ' +
            'the eval suite has to be re-baselined after the move and the acceptance ' +
            'thresholds renegotiated with the business owner before cut-over.',
        },
        {
          id: 'c',
          text:
            'Behaviour and feature availability are both identical, so the choice is purely a ' +
            'procurement and billing decision with no engineering consequence.',
        },
        {
          id: 'd',
          text:
            'The direct API lags the CSP routes, because Anthropic ships to the hyperscaler ' +
            'partners first and to its own endpoint afterwards.',
        },
      ],
      correct: ['a'],
      explanation:
        'The delivery route is about cloud account, identity system, region and procurement ' +
        'contract; the material is explicit that model behaviour is the same regardless of ' +
        'route and only the wrapper changes. What does differ is timing — CSP-mediated routes ' +
        'lag the first-party API on new features. That is why the direct API is the answer ' +
        'when there is no strong cloud preference or the partner needs features as soon as ' +
        'they ship, and it makes (c) wrong: the consequence is feature latency, not behaviour.',
      page: 3,
      verify: false,
    },
    {
      id: 'entry-points-004',
      domain: 'entry-points',
      type: 'single',
      stem:
        'A regulated law firm wants its lawyers using Claude for drafting. Attorney-client ' +
        'privilege applies and the firm must be able to produce a complete record of what was ' +
        'sent. What does the material prescribe?',
      options: [
        {
          id: 'a',
          text:
            'Route requests through a firm-approved LLM gateway that logs them, so the firm ' +
            'owns the audit trail end to end; consumer tiers of claude.ai are not suitable ' +
            'under these constraints.',
        },
        {
          id: 'b',
          text:
            'Have each lawyer use a consumer claude.ai account and export their conversation ' +
            'history monthly into the firm\'s document management system.',
        },
        {
          id: 'c',
          text:
            'Rely on the provider\'s retention and logging guarantees, since the audit trail ' +
            'is a property of the platform rather than of the firm\'s own systems.',
        },
        {
          id: 'd',
          text:
            'Prohibit Claude for any privileged matter and permit it only for administrative ' +
            'and marketing work, since privilege cannot survive a model call.',
        },
      ],
      correct: ['a'],
      explanation:
        'The constraint list — attorney-client privilege, HIPAA, GDPR and data residency, ' +
        'FedRAMP — leads to two conclusions in the material: consumer tiers of claude.ai are ' +
        'not suitable, and requests should route through a firm-approved LLM gateway that logs ' +
        'them. The load-bearing phrase is that the firm must own the audit trail end to end, ' +
        'which is what rules out both an export-after-the-fact workflow and leaning on the ' +
        'provider\'s own logging. The material treats these as routing constraints, not as a ' +
        'reason to keep Claude away from the work.',
      page: 4,
      verify: false,
    },
    {
      id: 'entry-points-005',
      domain: 'entry-points',
      type: 'single',
      stem:
        'A partner proposes adopting Claude.ai, Claude Code and Claude for Excel simultaneously ' +
        'in the first quarter, reasoning that broad availability lets each team find its own ' +
        'use. How should the architect frame the cost and risk?',
      options: [
        {
          id: 'a',
          text:
            'Each entry point carries non-trivial integration cost, so adopt one unless the ' +
            'use case genuinely spans entry points — and pick it from the work to be done.',
        },
        {
          id: 'b',
          text:
            'Adopting all three at once is the cheaper path, because the integration work ' +
            'shares identity and procurement and is mostly duplicated if staged.',
        },
        {
          id: 'c',
          text:
            'Entry-point choice is reversible at low cost, so the risk is over-analysis rather ' +
            'than picking wrongly; start everywhere and consolidate on evidence.',
        },
        {
          id: 'd',
          text:
            'Start with whichever entry point the partner already has licensed, and let the ' +
            'use cases be shaped around what that entry point supports.',
        },
      ],
      correct: ['a'],
      explanation:
        'Three rules combine here. Each entry point has non-trivial integration cost, so use ' +
        'one unless the use case spans entry points. The entry point follows the work rather ' +
        'than preceding it — which is what (d) inverts, and why the material warns against ' +
        'picking by what is available now. And the named risk is that outgrowing the wrong ' +
        'entry point is expensive, so starting on the right one is the cheapest total cost — ' +
        'directly contradicting the "reversible at low cost" premise in (c).',
      page: 3,
      verify: false,
    },
    {
      id: 'entry-points-006',
      domain: 'entry-points',
      type: 'single',
      stem:
        'A platform team writes a deny rule blocking Claude Code from running `terraform apply`. ' +
        'A developer asks whether running in bypassPermissions mode would let them through it ' +
        'anyway. What is the accurate answer?',
      options: [
        {
          id: 'a',
          text:
            'No. Rules evaluate deny, then ask, then allow in every mode — if a tool is ' +
            'denied at any level, no other level can allow it.',
        },
        {
          id: 'b',
          text:
            'Yes. bypassPermissions skips the permission system entirely, which is why it is ' +
            'restricted to container environments in the first place.',
        },
        {
          id: 'c',
          text:
            'No, because a deny rule and bypassPermissions mode cannot be configured on the ' +
            'same installation — enabling the mode makes the settings file fail to load.',
        },
        {
          id: 'd',
          text:
            'It depends on precedence: an enterprise-managed deny rule holds, but a deny rule ' +
            'in project settings is overridden by the mode.',
        },
      ],
      correct: ['a'],
      explanation:
        'Permission rules are evaluated deny, then ask, then allow, in all modes: if a tool is ' +
        'denied at any level, no other level can allow it. So a deny rule survives ' +
        'bypassPermissions, and it survives regardless of whether it came from enterprise or ' +
        'project settings. A deny rule and bypassPermissions mode configure perfectly well ' +
        'together, which is where (c) goes wrong; what stops the mode being used at all is a ' +
        'separate setting, `permissions.disableBypassPermissionsMode`. This is ' +
        'version-sensitive: the mode list ' +
        'and its labels have moved (the base mode is now shown as Manual, and `auto` is no ' +
        'longer a research preview), so re-check it against the documentation.',
      page: 3,
      verify: true,
    },
  ],
});
