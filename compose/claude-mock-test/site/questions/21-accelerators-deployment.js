// Domain: accelerators-deployment — "Accelerators, IP contribution and deployment platforms".
// Source: notes.txt pages 40-41 (builder track).
BANK.register({
  id: 'accelerators-deployment',
  title: 'Accelerators, IP contribution and deployment platforms',
  questions: [
    {
      id: 'accelerators-deployment-001',
      domain: 'accelerators-deployment',
      type: 'single',
      stem:
        'An engagement produced a working agent that a future project could start from. Which ' +
        'three asset types does the material recognise as reusable, and what makes each one ' +
        'reusable?',
      options: [
        {
          id: 'a',
          text:
            'An agent template with its domain-specific values parameterised, an MCP server ' +
            'package installable without code edits, and an eval suite shipping its dataset ' +
            'and rubric together.',
        },
        {
          id: 'b',
          text:
            'A reference architecture diagram, a cost model spreadsheet, and a slide deck ' +
            'describing the engagement outcome.',
        },
        {
          id: 'c',
          text:
            'The full application source, its deployment scripts, and the customer\'s ' +
            'configuration, kept together so the next team can fork it.',
        },
        {
          id: 'd',
          text:
            'A prompt library, a set of CLAUDE.md standards, and a skill, since those are the ' +
            'three mechanisms that carry instructions between projects.',
        },
      ],
      correct: ['a'],
      explanation:
        'Packaging for reuse means separating engagement-specific code from a reusable core ' +
        'and parameterising the rest. The three asset types follow from that: an agent ' +
        'template carrying system prompt, tool schemas and loop structure with domain values ' +
        'in configuration; an MCP server package whose tools, inputs and scope are controlled ' +
        'by the installing team and which installs without code edits; and an eval suite whose ' +
        'graded test set and judge rubric ship together so the installing team can run it in ' +
        'their own context. Option (c) is the anti-pattern — a fork of engagement-specific code ' +
        'is exactly what parameterisation is meant to avoid.',
      page: 40,
      verify: false,
    },
    {
      id: 'accelerators-deployment-002',
      domain: 'accelerators-deployment',
      type: 'multi',
      stem:
        'A reviewer is assessing an accelerator for contribution. Which two warning signs does ' +
        'the material name? (Select 2.)',
      options: [
        {
          id: 'a',
          text:
            'No parameters where customer-specific values belong.',
        },
        {
          id: 'b',
          text:
            'No bundled eval to demonstrate that the asset works in a different context.',
        },
        {
          id: 'c',
          text:
            'No continuous integration pipeline configured for the repository.',
        },
        {
          id: 'd',
          text:
            'No versioned changelog covering the engagement it came from.',
        },
        {
          id: 'e',
          text:
            'More than one asset type bundled in a single contribution.',
        },
      ],
      correct: ['a', 'b'],
      explanation:
        'Three warning signs are listed: no parameters where customer-specific values belong, ' +
        'no documentation of assumptions, and no bundled eval to prove the asset works in a ' +
        'different context. They share a theme — each one leaves the next team unable to tell ' +
        'whether the asset fits their situation. The documentation requirement is framed the ' +
        'same way: cover what cannot be inferred from reading the source, including assumptions ' +
        'about environment, inputs, failure modes and evals, plus which data assets are ' +
        'touched, which identity it runs under, and what it logs.',
      page: 40,
      verify: false,
    },
    {
      id: 'accelerators-deployment-003',
      domain: 'accelerators-deployment',
      type: 'single',
      stem:
        'A maintainer is offered a large, fully functional application as a contribution, with ' +
        'no example and no tests, and asks whether the licensing was cleared. What does the ' +
        'material say the contribution should look like?',
      options: [
        {
          id: 'a',
          text:
            'Code that does one thing, a runnable example, a test proving the behaviour, ' +
            'named assumptions — and rights settled before technical review.',
        },
        {
          id: 'b',
          text:
            'A complete application is preferable, since it demonstrates the asset end to end; ' +
            'the missing pieces are the example and the tests.',
        },
        {
          id: 'c',
          text:
            'The technical review comes first, and rights and attribution are settled once the ' +
            'maintainer has decided to accept the contribution.',
        },
        {
          id: 'd',
          text:
            'Tests are optional if the reviewer can reproduce the author\'s reasoning from the ' +
            'documentation, which is what the assumptions section is for.',
        },
      ],
      correct: ['a'],
      explanation:
        'The verification list is deliberately narrow: code that does one thing rather than a ' +
        'fully functional application, an example that shows it running so the reviewer does ' +
        'not have to build a harness, a test that proves it works so behaviour can be verified ' +
        'without reproducing the author\'s reasoning, and named assumptions. Rights and ' +
        'attribution happen *before* technical review — which is what (c) reverses. The ' +
        'takeaway behind all of it is that a maintainer accepts only what they can verify.',
      page: 40,
      verify: false,
    },
    {
      id: 'accelerators-deployment-004',
      domain: 'accelerators-deployment',
      type: 'single',
      stem:
        'A team benchmarks latency from a developer laptop, compares published per-token ' +
        'rates, and picks the cheapest platform. Which corrections does the material make?',
      options: [
        {
          id: 'a',
          text:
            'Measure latency from the customer\'s actual region and payload, and factor data ' +
            'transfer and integration costs into the comparison — they can offset a lower ' +
            'token price.',
        },
        {
          id: 'b',
          text:
            'Latency measured anywhere is representative because the model is the dominant ' +
            'term; the real omission is the compliance dimension.',
        },
        {
          id: 'c',
          text:
            'Per-token rates are the correct basis for comparison, and latency should be ' +
            'measured only after the platform is chosen and provisioned.',
        },
        {
          id: 'd',
          text:
            'Neither correction matters if the customer already has a cloud, since the ' +
            'deployment platform is then fixed and no comparison is required.',
        },
      ],
      correct: ['a'],
      explanation:
        'Both corrections are stated directly: latency should be measured from the customer\'s ' +
        'actual region and payload rather than from a laptop, and per-token rates need data ' +
        'transfer and integration costs factored in, since those can offset a lower headline ' +
        'price. The takeaway generalises it — measure the dimension that decides the ' +
        'placement: compliance against existing certifications, cost as total per call, latency ' +
        'from the customer\'s region. The platform is usually determined by the customer\'s ' +
        'existing cloud, but that settles where the workload runs, not whether the numbers work.',
      page: 41,
      verify: false,
    },
    {
      id: 'accelerators-deployment-005',
      domain: 'accelerators-deployment',
      type: 'single',
      stem:
        'A deployment chains a first-party API entry point, a Claude Code task that fetches ' +
        'external content, and an MCP server that reaches a customer system. Each component ' +
        'was reviewed and works correctly on its own. How does the material frame the ' +
        'remaining risk?',
      options: [
        {
          id: 'a',
          text:
            'Every seam where data or instructions move between deployment environments is a ' +
            'trust boundary — do not assume a component is trusted because it worked correctly ' +
            'alone, and apply least privilege to the whole application.',
        },
        {
          id: 'b',
          text:
            'The risk is concentrated at the entry point, since that is where input and ' +
            'identity are validated and everything downstream inherits that validation.',
        },
        {
          id: 'c',
          text:
            'Once each component is individually reviewed, the composition is covered: trust ' +
            'boundaries exist between organisations, not between components of one deployment.',
        },
        {
          id: 'd',
          text:
            'The risk sits with the MCP server alone, because it is the only component that ' +
            'reaches a customer system and therefore the only one with a blast radius.',
        },
      ],
      correct: ['a'],
      explanation:
        'A trust boundary is where data or instructions move from one deployment environment ' +
        'to another, and the material\'s instruction is to mark every seam as a boundary — ' +
        'explicitly warning against assuming a component is trusted because it worked ' +
        'correctly on its own. Least privilege applies to the whole application, not ' +
        'component by component. Regulated review then requires justifying audit logging, ' +
        'data-residency decisions and permission controls across the full application, ' +
        'including confirming zero-data-retention and HIPAA BAA eligibility for each component.',
      page: 41,
      verify: false,
    },
    {
      id: 'accelerators-deployment-006',
      domain: 'accelerators-deployment',
      type: 'single',
      stem:
        'A production deployment references a model family alias rather than a specific ' +
        'version, so it always picks up the latest. What does the material say, and how does ' +
        'this relate to "Claude on AWS" versus Bedrock?',
      options: [
        {
          id: 'a',
          text:
            'Pin the model version to avoid silent production changes. Claude on AWS runs ' +
            'under Anthropic identity and terms via the customer\'s AWS account, and is listed ' +
            'separately from Amazon Bedrock.',
        },
        {
          id: 'b',
          text:
            'Tracking the latest version is correct practice, since evals gate every release ' +
            'and a pinned version accumulates known defects. Claude on AWS is Anthropic\'s name ' +
            'for Bedrock.',
        },
        {
          id: 'c',
          text:
            'Pinning matters only on first-party APIs; CSP-mediated routes pin the version on ' +
            'the customer\'s behalf, which is one reason they lag on new features.',
        },
        {
          id: 'd',
          text:
            'Pinning is a compliance requirement rather than a reliability one, and applies ' +
            'only where a regulator requires reproducible outputs.',
        },
      ],
      correct: ['a'],
      explanation:
        'Pin the model version to avoid silent production changes — a model swap is treated as ' +
        'a release elsewhere in the material, gated by evals, and an unpinned alias performs ' +
        'that swap without anyone deciding to. The platform list keeps Claude on AWS distinct ' +
        'from Claude on Amazon Bedrock: Claude on AWS is Anthropic-operated, reached with ' +
        'Anthropic identity and terms through the customer\'s AWS account, whereas Bedrock is ' +
        'partner-operated with its own pricing. Vertex AI likewise uses Google Cloud identity, ' +
        'IAM and billing.',
      page: 41,
      verify: false,
    },
  ],
});
