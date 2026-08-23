// Domain: governance-risk — "Governance, delegation criteria, skill trust, data sensitivity".
// Source: notes.txt pages 16-17 (architect track).
BANK.register({
  id: 'governance-risk',
  title: 'Governance, delegation criteria, skill trust, data sensitivity',
  questions: [
    {
      id: 'governance-risk-001',
      domain: 'governance-risk',
      type: 'single',
      stem:
        'A practitioner is offered an internally built skill that would genuinely help with ' +
        'their task, but its bundle requests permissions well beyond what the task needs and ' +
        'no one can say who owns it. Which outcome does the skill trust check give?',
      options: [
        {
          id: 'a',
          text:
            'Decline — the permissions are disproportionate to the task and the owner cannot ' +
            'be established, and either alone is enough.',
        },
        {
          id: 'b',
          text:
            'Escalate for security review, since the skill is useful and a reviewer can decide ' +
            'whether the permissions are justified.',
        },
        {
          id: 'c',
          text:
            'Enable it, because it comes from an internal source, and internal provenance is ' +
            'what the source check is asking about.',
        },
        {
          id: 'd',
          text:
            'Enable it for a trial period with the permissions unchanged, and review whether ' +
            'the broader permissions are ever actually exercised.',
        },
      ],
      correct: ['a'],
      explanation:
        'The check has three outcomes. Enable when source, permissions and appropriateness are ' +
        'all good, with least privilege applied. Escalate when the skill is useful but needs ' +
        'security review. Decline when permissions are disproportionate or the owner cannot be ' +
        'established — and here both conditions hold, which is what separates this from an ' +
        'escalation. Note that the material asks for a trustworthy source of skills including ' +
        'internal sources: internal provenance is not by itself an answer, because a skill is ' +
        'software and its permissions are inherited by whoever enables it.',
      page: 16,
      verify: false,
    },
    {
      id: 'governance-risk-002',
      domain: 'governance-risk',
      type: 'single',
      stem:
        'A practitioner is deciding what may be pasted into Claude. Which classification does ' +
        'the material give for a confidential internal document containing a client contact\'s ' +
        'name?',
      options: [
        {
          id: 'a',
          text:
            'Review first — confidential internal documents and material carrying names or ' +
            'contract details sit in that middle tier.',
        },
        {
          id: 'b',
          text:
            'Keep out unless approved, since any document containing a named individual is ' +
            'treated as regulated data.',
        },
        {
          id: 'c',
          text:
            'Safe to use, provided the document is already circulated internally rather than ' +
            'externally.',
        },
        {
          id: 'd',
          text:
            'Review first only if the deployment is subject to GDPR; otherwise it falls into ' +
            'safe to use.',
        },
      ],
      correct: ['a'],
      explanation:
        'The three tiers are: safe to use (published material, anonymised or aggregated data, ' +
        'internal docs cleared for public sharing), review first (confidential internal ' +
        'documents, documents with names or contract details, draft material tied to an ' +
        'unannounced deal or product), and keep out unless approved (regulated data — health, ' +
        'financial, government — plus credentials and secrets). The classification comes ' +
        'first; feature controls such as incognito, memory management and redaction are how ' +
        'you then act on it.',
      page: 17,
      verify: false,
    },
    {
      id: 'governance-risk-003',
      domain: 'governance-risk',
      type: 'single',
      stem:
        'A practitioner plans to handle regulated health data by turning on incognito, ' +
        'reasoning that the session then stays out of history and memory. What is wrong with ' +
        'that reasoning?',
      options: [
        {
          id: 'a',
          text:
            'Incognito only controls whether something gets remembered. It does not establish ' +
            'that the data was allowed in at all, which is the primary requirement here.',
        },
        {
          id: 'b',
          text:
            'Incognito is the right control but is insufficient alone; it needs to be paired ' +
            'with memory management so that no prior session can surface the same data.',
        },
        {
          id: 'c',
          text:
            'Incognito exempts the session from data retention policies, which is more than ' +
            'the practitioner needs and creates its own audit gap.',
        },
        {
          id: 'd',
          text:
            'Nothing is wrong: keeping regulated data out of history and memory is exactly ' +
            'what the keep-out-unless-approved tier requires.',
        },
      ],
      correct: ['a'],
      explanation:
        'Two separate points. First, memory exclusion and data retention are separate ' +
        'controls: an incognito session still follows data retention policies and may appear ' +
        'in org exports, so (c) has it backwards. Second, and more important, incognito only ' +
        'controls whether something is remembered — it says nothing about whether the data was ' +
        'permitted in the first place, which is the primary requirement for regulated data. ' +
        'Classify first, then use the feature control; the control cannot substitute for the ' +
        'classification.',
      page: 17,
      verify: false,
    },
    {
      id: 'governance-risk-004',
      domain: 'governance-risk',
      type: 'multi',
      stem:
        'A team redacts customer names and account numbers before sending case notes to ' +
        'Claude. Which two failure modes does the material tell them to watch for? (Select 2.)',
      options: [
        {
          id: 'a',
          text:
            'Partial redaction that still leaves enough information for the individual to be ' +
            'identified.',
        },
        {
          id: 'b',
          text:
            'Redaction that breaks the task, in which case an approved path for the data has ' +
            'to be confirmed instead.',
        },
        {
          id: 'c',
          text:
            'Redaction that reduces token count enough to change how the prompt is cached ' +
            'across requests.',
        },
        {
          id: 'd',
          text:
            'Redaction applied to the response as well as the request, which removes the ' +
            'reviewer\'s ability to audit the output.',
        },
        {
          id: 'e',
          text:
            'Redaction that makes the output impossible to grade against the eval suite, since ' +
            'the expected answers contain the original values.',
        },
      ],
      correct: ['a', 'b'],
      explanation:
        'Redaction and anonymisation are for when the task does not require the sensitive ' +
        'specifics — names, account numbers, identifiers. Two failure modes are named: partial ' +
        'redaction, which leaves enough behind to allow identification, and redaction that ' +
        'breaks the task, where the answer is not to redact less but to confirm an approved ' +
        'path for the data. Both point the same way: redaction is a decision about whether the ' +
        'task needs the specifics, not a formatting step applied on the way out.',
      page: 17,
      verify: false,
    },
    {
      id: 'governance-risk-005',
      domain: 'governance-risk',
      type: 'single',
      stem:
        'An administrator on a Team plan is asked to disable memory across the organisation ' +
        'for a compliance reason. What does the material say is available?',
      options: [
        {
          id: 'a',
          text:
            'Team plans have no org-level memory controls; owners and primary owners hold ' +
            'org-wide memory controls, including disabling memory, on Enterprise plans.',
        },
        {
          id: 'b',
          text:
            'Any plan\'s administrator can disable memory org-wide; what differs between plans ' +
            'is whether the change is audited.',
        },
        {
          id: 'c',
          text:
            'Memory can only ever be managed per project by the individual practitioner, ' +
            'regardless of plan.',
        },
        {
          id: 'd',
          text:
            'Team plans allow memory to be disabled org-wide but not re-enabled selectively, ' +
            'which is why the control is usually left alone.',
        },
      ],
      correct: ['a'],
      explanation:
        'The split is by plan: Team plans have no org-level controls for memory at all, while ' +
        'on Enterprise plans owners and primary owners hold org-wide memory controls, ' +
        'including disabling memory for the organisation. It matters for governance ' +
        'conversations because it decides whether a memory-related obligation can be met by ' +
        'configuration or has to be met by practice.',
      page: 17,
      verify: false,
    },
    {
      id: 'governance-risk-006',
      domain: 'governance-risk',
      type: 'single',
      stem:
        'A practitioner is unsure whether to disclose that a client-facing document was drafted ' +
        'with Claude. How does the material frame the question?',
      options: [
        {
          id: 'a',
          text:
            'Default to disclosing rather than concealing. Whether disclosure is needed ' +
            'depends on the setting and the audience, and an ambiguous case is reasoned ' +
            'through rather than settled by rule.',
        },
        {
          id: 'b',
          text:
            'Disclosure is required in every setting without exception, since concealing AI ' +
            'assistance is what creates the ethical risk.',
        },
        {
          id: 'c',
          text:
            'Disclosure is a matter for the organisation\'s policy binder rather than the ' +
            'practitioner, who should follow whatever the policy states.',
        },
        {
          id: 'd',
          text:
            'Disclosure is only warranted where the output was not reviewed by a human, since ' +
            'a reviewed output is the reviewer\'s work product.',
        },
      ],
      correct: ['a'],
      explanation:
        'Transparency and disclosure depend on the setting and the audience, with an explicit ' +
        'default: disclose rather than conceal. For genuinely ambiguous cases the material ' +
        'gives four questions — who is affected, what could go wrong, what a fair outcome ' +
        'looks like, and what disclosure is needed. Option (c) is the specific failure the ' +
        'section pushes against: governance is a practitioner skill rather than a policy ' +
        'binder, and policies followed only when someone is watching are not governance.',
      page: 17,
      verify: false,
    },
  ],
});
