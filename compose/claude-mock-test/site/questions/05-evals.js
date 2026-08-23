// Domain: evals — "Evals as acceptance criteria".
// Source: notes.txt pages 4-5 (architect track) and 36 (builder track).
BANK.register({
  id: 'evals',
  title: 'Evals as acceptance criteria',
  questions: [
    {
      id: 'evals-001',
      domain: 'evals',
      type: 'single',
      stem:
        'A team is building an eval set for a claims-triage feature. They decide to keep the ' +
        'set to 20 cases so that a reviewer can read and grade every output carefully each ' +
        'release. What does the material recommend instead?',
      options: [
        {
          id: 'a',
          text:
            'Prioritise volume over per-question quality, structuring questions so the ' +
            'grading can be automated.',
        },
        {
          id: 'b',
          text:
            'Keep the set at 20 cases but have two reviewers grade each output ' +
            'independently, to raise the signal per question.',
        },
        {
          id: 'c',
          text:
            'Size the eval set to whatever the monthly API budget allows, since every eval ' +
            'run is billable API calls.',
        },
        {
          id: 'd',
          text:
            'Drop the eval set and rely on a staged production rollout to surface quality ' +
            'problems on real traffic.',
        },
      ],
      correct: ['a'],
      explanation:
        'The design principles are explicit: prioritise volume over quality — more questions ' +
        'of lower signal beat fewer questions that require human-graded evals — and automate ' +
        'where possible by structuring questions for automated grading. Human grading is the ' +
        'bottleneck that caps the set at 20 cases in the first place, so adding a second ' +
        'reviewer makes the bottleneck worse, not better.',
      page: 4,
      verify: false,
    },
    {
      id: 'evals-002',
      domain: 'evals',
      type: 'single',
      stem:
        'A team shipping a contract-clause extractor proposes using a well-known public ' +
        'benchmark as its eval, on the grounds that the benchmark is already built and ' +
        'independently maintained. How should the architect respond?',
      options: [
        {
          id: 'a',
          text:
            'Evals must be task-specific and cover the edge cases of that task, so the ' +
            'benchmark cannot stand in for an eval of this feature.',
        },
        {
          id: 'b',
          text:
            'The benchmark is sufficient as long as it is re-run on every release, since ' +
            'benchmark scores generalise across tasks of similar difficulty.',
        },
        {
          id: 'c',
          text:
            'Gate releases on the benchmark now and build a task-specific set only if the ' +
            'benchmark score ever drops below the threshold.',
        },
        {
          id: 'd',
          text:
            'Use the benchmark to pick the model tier, and treat that model choice as the ' +
            'quality bar for the feature.',
        },
      ],
      correct: ['a'],
      explanation:
        'The first design principle is that evals are task-specific, including edge cases. ' +
        'A general benchmark measures something other than what this feature has to do, so ' +
        'it cannot define done for it — and waiting for it to fail before building the real ' +
        'set means the failures it cannot see are never caught. Nor does it settle the model ' +
        'question: the material has evals guide model selection, not the reverse.',
      page: 4,
      verify: false,
    },
    {
      id: 'evals-003',
      domain: 'evals',
      type: 'single',
      stem:
        'A feature emits a JSON configuration block. The team plans to grade each eval case ' +
        'with an LLM judge given a rubric for correctness, because the judge returns reasoning ' +
        'along with its score. What does the material say about that choice?',
      options: [
        {
          id: 'a',
          text:
            'LLM-as-judge is expensive and noisy and is meant for open-ended output; a ' +
            'code-graded check fits this task.',
        },
        {
          id: 'b',
          text:
            'The judge is the right call, since the reasoning it returns alongside each score ' +
            'is what makes an automated grade auditable.',
        },
        {
          id: 'c',
          text:
            'Exact match against a reference block stored with each case is cheaper and just ' +
            'as reliable for structured output.',
        },
        {
          id: 'd',
          text:
            'Cosine similarity against reference configurations would score semantic ' +
            'consistency across the outputs more cheaply.',
        },
      ],
      correct: ['a'],
      explanation:
        'The material calls LLM-as-judge expensive and noisy and reserves it for open-ended ' +
        'output that cannot be evaluated by pattern matching — use it only when you have to. ' +
        'Structured or code output is the textbook case for a code-graded check instead: a ' +
        'function validating that the output satisfies a rule, which can often be as simple ' +
        'as whether it parses. Reasoning attached to a score does not make a noisy grade ' +
        'trustworthy. Exact match would fail on a harmless reordering, and cosine similarity ' +
        'measures consistency between outputs, not validity of one.',
      page: 36,
      verify: false,
    },
    {
      id: 'evals-004',
      domain: 'evals',
      type: 'single',
      stem:
        'A policy question-answering feature is graded by exact string match against a ' +
        'reference answer per case. The score is low, and inspection shows many failing ' +
        'outputs are correct answers phrased differently. What does the material say about ' +
        'this setup?',
      options: [
        {
          id: 'a',
          text:
            'Exact match fits only known return values, so it cannot credit a paraphrase: ' +
            'the technique is the wrong one here.',
        },
        {
          id: 'b',
          text:
            'The failures are correct: an eval should credit only exact matches, so ' +
            'constrain the prompt until the feature stops paraphrasing.',
        },
        {
          id: 'c',
          text:
            'The technique is fine and the threshold is wrong — lower it until paraphrase ' +
            'failures stop dominating the score.',
        },
        {
          id: 'd',
          text:
            'Exact match suits open-ended answers; the noise is from too few cases, so grow ' +
            'the dataset until paraphrases average out.',
        },
      ],
      correct: ['a'],
      explanation:
        'Exact match is listed as the cheapest and most brittle option, appropriate only ' +
        'where there is a single known return value and zero ambiguity, and explicitly not ' +
        'good for paraphrase or open-ended answers. The failures here are a mis-chosen ' +
        'grading technique, not a mis-set threshold or an undersized dataset — moving the ' +
        'threshold to accommodate false failures throws away the signal the eval exists to ' +
        'produce.',
      page: 36,
      verify: false,
    },
    {
      id: 'evals-005',
      domain: 'evals',
      type: 'multi',
      stem:
        'A team code-grades the eval for a feature that generates API request payloads. ' +
        'Which two statements about that grading technique match the material? (Select 2.)',
      options: [
        {
          id: 'a',
          text:
            'It catches invalid syntax and missing fields, often just by checking that the ' +
            'payload parses.',
        },
        {
          id: 'b',
          text:
            'It confirms the payload satisfies the rule, but does not evaluate the quality ' +
            'of the content.',
        },
        {
          id: 'c',
          text:
            'It scores how well the payload follows the instruction, with a confidence that ' +
            'needs calibrating.',
        },
        {
          id: 'd',
          text:
            'It removes the need for a pass threshold, because each case either satisfies ' +
            'the rule or does not.',
        },
      ],
      correct: ['a', 'b'],
      explanation:
        'For structured or code output the material recommends a code-graded check and names ' +
        'both its strength and its limit: good for invalid syntax, missing fields and the ' +
        'like, but it does not evaluate content quality. Scoring instruction-following with ' +
        'a confidence that needs calibration is the description of LLM-as-judge, not of a ' +
        'code-graded check; and a pass threshold is still needed, because the eval score is ' +
        'the proportion of cases that pass across the dataset.',
      page: 36,
      verify: false,
    },
    {
      id: 'evals-006',
      domain: 'evals',
      type: 'multi',
      stem:
        'Turning a business requirement into a measurable success criterion, a team has ' +
        'identified the specific behaviour the feature must show and set the threshold for ' +
        'passing. Which two steps does the material still require? (Select 2.)',
      options: [
        {
          id: 'a',
          text: 'Identify the failure modes — the specific ways the feature can get this wrong.',
        },
        {
          id: 'b',
          text: 'Include adversarial inputs, so the set covers cases built to break the behaviour.',
        },
        {
          id: 'c',
          text:
            'Average the per-case scores into a single headline figure for the design ' +
            'document.',
        },
        {
          id: 'd',
          text:
            'Agree a manual review rota so a human grades every case for the first few ' +
            'releases.',
        },
      ],
      correct: ['a', 'b'],
      explanation:
        'The material gives four steps for turning a business requirement into a measurable ' +
        'threshold: identify the specific behaviour, set the threshold for passing, identify ' +
        'failure modes, and include adversarial inputs. The first two are done here. ' +
        'Averaging scores is a step in running the eval pipeline, not in defining the ' +
        'success criteria, and a manual review rota runs against the principle of automating ' +
        'grading wherever possible.',
      page: 4,
      verify: false,
    },
    {
      id: 'evals-007',
      domain: 'evals',
      type: 'single',
      stem:
        'A support assistant must hold a constraint stated early in a conversation even when ' +
        'the user reframes the request several turns later. The current eval grades one ' +
        'prompt and one response per case and never catches the failure. What does the ' +
        'material call for?',
      options: [
        {
          id: 'a',
          text:
            'A multi-turn eval, where each case is a whole conversation rather than a single ' +
            'prompt and response.',
        },
        {
          id: 'b',
          text:
            'A single-turn eval whose prompt is the whole conversation pasted in as context, ' +
            'since only the final response is graded.',
        },
        {
          id: 'c',
          text:
            'A single-turn eval run once per turn of the conversation, with the per-turn ' +
            'scores averaged.',
        },
        {
          id: 'd',
          text:
            'No eval change — behaviour that only appears across turns is a tracing concern, ' +
            'not an eval concern.',
        },
      ],
      correct: ['a'],
      explanation:
        'The material distinguishes single-turn evals from multi-turn evals, which require ' +
        'whole conversations as cases. The behaviour under test only exists across turns, so ' +
        'a case has to be the conversation. Replaying a fixed transcript as one prompt, or ' +
        'grading turns in isolation, both remove the very thing being measured: how the ' +
        'assistant carries the constraint forward as the exchange develops.',
      page: 5,
      verify: false,
    },
    {
      id: 'evals-008',
      domain: 'evals',
      type: 'single',
      stem:
        'An engineer has tweaked a production prompt so that a customer-reported case now ' +
        'produces the right answer, and wants to ship the change today. What does the ' +
        'material say should happen first?',
      options: [
        {
          id: 'a',
          text:
            'Run the change through the eval suite and let the score gate the release, as ' +
            'for any change.',
        },
        {
          id: 'b',
          text:
            'Ship it and watch complaint volume — the reported case is fixed and real ' +
            'traffic is the honest test.',
        },
        {
          id: 'c',
          text:
            'Ship both prompts to a slice of production traffic and treat the A/B win rate ' +
            'as the eval for the change.',
        },
        {
          id: 'd',
          text:
            'Hand-check a handful of outputs; the eval suite is for model swaps, not for ' +
            'prompt edits.',
        },
      ],
      correct: ['a'],
      explanation:
        'Evals are used for gating changes to production: the suite is what says whether a ' +
        'change is safe to ship, and a fix verified on the one case that prompted it says ' +
        'nothing about the cases it may have broken. A prompt edit is a change to production ' +
        'like any other, so it goes through the same gate; hand-checking a few outputs or ' +
        'watching complaints afterwards moves the test onto users instead of removing the ' +
        'risk.',
      page: 5,
      verify: false,
    },
    {
      id: 'evals-009',
      domain: 'evals',
      type: 'single',
      stem:
        'While scoping an eval suite, a finance stakeholder asks that the dataset be capped ' +
        'at the number of cases the eval budget covers. How does the material frame the cost ' +
        'dimension of evals?',
      options: [
        {
          id: 'a',
          text:
            'Size the dataset against the confidence you need in the result; cost follows ' +
            'from that rather than setting it.',
        },
        {
          id: 'b',
          text:
            'Cap the dataset at the eval budget, since every eval run is billable API calls ' +
            'like any other workload.',
        },
        {
          id: 'c',
          text:
            'Cost is not a real dimension for evals, because grading runs as code on the ' +
            'team machines rather than against the API.',
        },
        {
          id: 'd',
          text:
            'Keep the full dataset but run a random tenth of it per release, so the spend ' +
            'per run stays flat as the suite grows.',
        },
      ],
      correct: ['a'],
      explanation:
        'The cost leg of the triad acknowledges that evals are API calls and therefore cost ' +
        'money, but is explicit that the dataset should be sized against confidence in the ' +
        'results, not primarily against cost. Denying that eval runs cost anything ignores ' +
        'the first half of that; sampling a tenth of the dataset per release honours the ' +
        'second half in name only, since it shrinks the evidence behind every run and buys ' +
        'the saving back with a weaker signal.',
      page: 5,
      verify: false,
    },
    {
      id: 'evals-010',
      domain: 'evals',
      type: 'multi',
      stem:
        'A sponsor has funded the eval suite as a one-off project, with no line in the ' +
        'following year budget. Which two consequences does the material name in its ' +
        'Cost / Complexity / Risk framing of evals? (Select 2.)',
      options: [
        {
          id: 'a',
          text:
            'Complexity: eval infrastructure needs maintaining — dataset, judge prompts ' +
            'and thresholds all drift.',
        },
        {
          id: 'b',
          text:
            'Risk: evals that fall out of date with the system provide false confidence when ' +
            'they pass.',
        },
        {
          id: 'c',
          text:
            'Cost: the suite is paid for at build time, so an unmaintained suite has no ' +
            'running cost between releases.',
        },
        {
          id: 'd',
          text:
            'Complexity: it falls away once the first dataset exists, leaving a scheduled ' +
            'job that runs itself.',
        },
      ],
      correct: ['a', 'b'],
      explanation:
        'Two of the three legs land on this sponsor. Complexity: eval infrastructure must be ' +
        'maintained — the golden dataset kept current, judge prompts engineered and tested, ' +
        'pass thresholds reviewed when requirements change — so it is a standing cost, not a ' +
        'build cost. Risk: out-of-date evals can provide false confidence, which is what an ' +
        'unfunded suite decays into. The cost leg does not vanish either: evals are API ' +
        'calls, so every run is billed however long the suite has gone untouched.',
      page: 5,
      verify: false,
    },
    {
      id: 'evals-011',
      domain: 'evals',
      type: 'multi',
      stem:
        'A feature passes its eval suite comfortably, yet quality complaints arrive from ' +
        'production. Which two risks of a passing suite does the material name? (Select 2.)',
      options: [
        {
          id: 'a',
          text: 'The dataset is not representative of the real data the feature sees in production.',
        },
        {
          id: 'b',
          text: 'The suite has not been kept current with the changes made to the prompts since.',
        },
        {
          id: 'c',
          text:
            'The threshold was set by the team that built the feature, not by an ' +
            'independent reviewer.',
        },
        {
          id: 'd',
          text:
            'The grading is automated, so no human has read any of the outputs the suite ' +
            'scored.',
        },
      ],
      correct: ['a', 'b'],
      explanation:
        'The two named risks of a passing eval suite are a dataset that does not represent ' +
        'real data and a suite that has not kept pace with changes to the prompts — either ' +
        'way the suite is measuring something other than the system now in production, which ' +
        'is the false confidence the risk leg of the triad warns about. Automated grading is ' +
        'a recommended practice rather than a risk, and who owns the threshold is a governance ' +
        'question the material does not raise here.',
      page: 5,
      verify: false,
    },
    {
      id: 'evals-012',
      domain: 'evals',
      type: 'single',
      stem:
        'An LLM-as-judge eval scores summaries against the rubric "rate the overall quality ' +
        'of this summary from 1 to 10". Re-running the same suite on an unchanged feature ' +
        'moves the average by more than the pass threshold. What does the material prescribe ' +
        'for LLM-based grading?',
      options: [
        {
          id: 'a',
          text:
            'Give the judge a detailed, clear rubric in specific, empirical terms, and have ' +
            'it reason before scoring.',
        },
        {
          id: 'b',
          text:
            'Move the judging to a larger model tier — grading noise is a capability problem ' +
            'and resolves with a stronger judge.',
        },
        {
          id: 'c',
          text:
            'Run the same judge prompt several times per case and average, until the run to ' +
            'run variance falls under the threshold.',
        },
        {
          id: 'd',
          text:
            'Replace the 1-10 scale with a pass or fail verdict so that disagreement between ' +
            'runs no longer moves the score.',
        },
      ],
      correct: ['a'],
      explanation:
        'LLM-based grading is described as needing detailed, clear rubrics that are empirical ' +
        'or specific — purely qualitative evals are to be avoided — and the judge should be ' +
        'encouraged to reason. "Overall quality from 1 to 10" is precisely the purely ' +
        'qualitative rubric that warning is about. Averaging more runs or collapsing the ' +
        'scale hides the disagreement rather than removing its cause, and a stronger judge ' +
        'still has nothing specific to grade against.',
      page: 4,
      verify: false,
    },
  ],
});
