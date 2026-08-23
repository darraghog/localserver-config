// Domain: multimodal-batch — "Images, PDFs and high-volume processing".
// Source: notes.txt pages 27-28 (builder track).
BANK.register({
  id: 'multimodal-batch',
  title: 'Images, PDFs and high-volume processing',
  questions: [
    {
      id: 'multimodal-batch-001',
      domain: 'multimodal-batch',
      type: 'single',
      stem:
        'The same 40-page PDF is referenced by dozens of requests a day, and the team is ' +
        'currently base64-encoding it into each one. Which delivery method does the material ' +
        'point to, and what changes?',
      options: [
        {
          id: 'a',
          text:
            'The Files API: upload once, reference the `file_id` afterwards, so every later ' +
            'request carries an id instead of bytes and payload overhead is almost zero.',
        },
        {
          id: 'b',
          text:
            'A URL reference, since Claude fetching the document at request time removes the ' +
            'payload without any upload step to manage.',
        },
        {
          id: 'c',
          text:
            'Keep base64 but split the PDF into per-page documents, so each request carries ' +
            'only the pages it needs.',
        },
        {
          id: 'd',
          text:
            'The Message Batches API, which deduplicates repeated attachments across the ' +
            'requests in a batch.',
        },
      ],
      correct: ['a'],
      explanation:
        'Three delivery methods, three jobs. Inline base64 travels with every request, ' +
        'inflating request size and latency, and suits one-off images. A URL reference keeps ' +
        'the payload out of the request but creates a dependency on that URL staying reachable ' +
        '— fine for an asset you host and control, not otherwise. The Files API is the answer ' +
        'when the same image or PDF appears in multiple requests, or when asset management ' +
        'lives separately from inference: a one-time upload cost, then an id instead of bytes.',
      page: 27,
      verify: false,
    },
    {
      id: 'multimodal-batch-002',
      domain: 'multimodal-batch',
      type: 'single',
      stem:
        'How does the material say the token cost of an image is calculated?',
      options: [
        {
          id: 'a',
          text:
            'Width divided by 28, times height divided by 28 — each rounded up — since the ' +
            'image is measured in 28-pixel-square patches.',
        },
        {
          id: 'b',
          text:
            'By file size in bytes after base64 encoding, since that is what travels with the ' +
            'request.',
        },
        {
          id: 'c',
          text:
            'By a flat per-image token charge that is independent of the image\'s dimensions.',
        },
        {
          id: 'd',
          text:
            'By the number of distinct visual elements the model identifies, which is why the ' +
            'cost cannot be predicted before the call.',
        },
      ],
      correct: ['a'],
      explanation:
        'The formula is ⌈width / 28⌉ × ⌈height / 28⌉ visual tokens, with each patch a 28×28 ' +
        'pixel block. It is one of only two formulas in the material, and the reason it is ' +
        'worth holding is the takeaway attached to it: calculate the cost of a multimodal ' +
        'input before writing the ingestion code. Encoding affects payload size, not token ' +
        'count.',
      page: 28,
      verify: false,
    },
    {
      id: 'multimodal-batch-003',
      domain: 'multimodal-batch',
      type: 'multi',
      stem:
        'Which two of these workloads does the material route to the Message Batches API ' +
        'rather than the synchronous API? (Select 2.)',
      options: [
        {
          id: 'a',
          text: 'A nightly pipeline that classifies five thousand records.',
        },
        {
          id: 'b',
          text: 'An eval run testing a new prompt against two thousand examples.',
        },
        {
          id: 'c',
          text: 'A user uploading a photo and expecting an immediate classification.',
        },
        {
          id: 'd',
          text: 'A chatbot generating a reply to a user\'s message.',
        },
        {
          id: 'e',
          text: 'A support agent waiting for a summary of an attached document mid-call.',
        },
      ],
      correct: ['a', 'b'],
      explanation:
        'The Batches API accepts up to 100,000 requests or 256MB in a single call, returns a ' +
        '`batch_id` to poll, and may take up to 24 hours — with a lower per-token cost in ' +
        'exchange. That makes it right for offline pipelines, evaluation runs and bulk jobs, ' +
        'and wrong for every case where somebody is waiting. Misreading latency is one of the ' +
        'two named failure modes for this area: do not use batch if a user is waiting.',
      page: 28,
      verify: false,
    },
    {
      id: 'multimodal-batch-004',
      domain: 'multimodal-batch',
      type: 'single',
      stem:
        'A document-processing service loops over the synchronous API, firing one request per ' +
        'record, and describes this in its design doc as "using batch processing". What ' +
        'objection does the material make?',
      options: [
        {
          id: 'a',
          text:
            'Looping sequentially over the synchronous API is not the same as using the ' +
            'Batches API, and calling it one does not buy the batch price.',
        },
        {
          id: 'b',
          text:
            'None — a sequential loop is the recommended implementation of batch processing ' +
            'when the volume is below the batch size limit.',
        },
        {
          id: 'c',
          text:
            'The objection is only about latency; the per-token cost is the same either way, ' +
            'so a loop is an acceptable simplification.',
        },
        {
          id: 'd',
          text:
            'The loop should use an async client, which is what the Batches API provides ' +
            'underneath.',
        },
      ],
      correct: ['a'],
      explanation:
        'The material states it flatly: looping sequentially over the synchronous API is not ' +
        'the same as using the Batch API. They differ in submission model — many requests in a ' +
        'single call returning a `batch_id` to poll — and in price, since the batch pattern ' +
        'carries a lower per-token cost. An async client provides concurrency without ' +
        'blocking, which is a third thing again and not what the Batches API is.',
      page: 28,
      verify: false,
    },
    {
      id: 'multimodal-batch-005',
      domain: 'multimodal-batch',
      type: 'single',
      stem:
        'A pipeline sends a scanned form plus a long instruction block and hits the context ' +
        'limit sooner than the team predicted from the instruction length alone. Which named ' +
        'failure mode is this, and what does the material advise about the prompt itself?',
      options: [
        {
          id: 'a',
          text:
            'Underestimating context cost — images and PDFs consume budget before any text ' +
            'is processed — and visual prompts should say how to handle ambiguity.',
        },
        {
          id: 'b',
          text:
            'Misreading latency, addressed by moving the workload to the Batches API and ' +
            'relaxing the response-time expectation.',
        },
        {
          id: 'c',
          text:
            'Context overload from conversation history, addressed by compacting earlier turns ' +
            'before the document is attached.',
        },
        {
          id: 'd',
          text:
            'A chunking failure, addressed by splitting the form into smaller retrievable ' +
            'units with overlap between them.',
        },
      ],
      correct: ['a'],
      explanation:
        'Two failure modes are named for multimodal and batch work: misreading latency, and ' +
        'underestimating context cost — images and PDFs consume budget before Claude processes ' +
        'any text at all. The prompting guidance attached to multimodal inputs is specific: ' +
        'prompts for visual analysis should explain how to handle ambiguity, since a scan that ' +
        'is partly illegible is the normal case rather than the exception.',
      page: 28,
      verify: false,
    },
    {
      id: 'multimodal-batch-006',
      domain: 'multimodal-batch',
      type: 'single',
      stem:
        'A developer attaches a PDF and an image to the same request. What does the material ' +
        'say about how each is represented?',
      options: [
        {
          id: 'a',
          text:
            'The block type is `image` or `document` for a PDF, each with optional title and ' +
            'context fields.',
        },
        {
          id: 'b',
          text:
            'Both use the `image` block type; a PDF is distinguished by its media type rather ' +
            'than by the block.',
        },
        {
          id: 'c',
          text:
            'Both use the `document` block type, with images treated as single-page documents ' +
            'for consistency.',
        },
        {
          id: 'd',
          text:
            'Neither has a dedicated block type — both are attached through the Files API and ' +
            'referenced by id in a text block.',
        },
      ],
      correct: ['a'],
      explanation:
        'The block type is either `image` or `document`, the latter for PDFs, and each takes ' +
        'an optional title field and context field. This is independent of how the bytes are ' +
        'delivered: inline base64, a URL reference and a `file_id` from the Files API are all ' +
        'ways of populating the same block types.',
      page: 28,
      verify: false,
    },
  ],
});
