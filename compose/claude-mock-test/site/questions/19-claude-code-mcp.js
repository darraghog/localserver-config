// Domain: claude-code-mcp — "Claude Code, MCP, plugins, hooks and secrets".
// Source: notes.txt pages 29-34.
// Four questions carry verify: true, where the notes disagree with the documented
// behaviour: the auto permission mode (003), deny-rule precedence under
// bypassPermissions (004), the base mode naming (005) and MCP tool-definition
// loading (014). Those are authored to the documentation, not to the note.
BANK.register({
  id: 'claude-code-mcp',
  title: 'Claude Code, MCP, plugins, hooks and secrets',
  questions: [
    {
      id: 'claude-code-mcp-001',
      domain: 'claude-code-mcp',
      type: 'single',
      stem:
        'A platform team runs Claude Code non-interactively in CI. The job must run a fixed ' +
        'set of tools without ever pausing for confirmation, and any call outside that set ' +
        'must be stopped rather than executed. Which permission mode is built for this?',
      options: [
        {
          id: 'a',
          text: 'dontAsk, which allows only pre-approved tools and gates any call not on the allow list.',
        },
        {
          id: 'b',
          text: 'acceptEdits, which auto-approves reads, edits and filesystem commands inside the working directory.',
        },
        {
          id: 'c',
          text: 'bypassPermissions, which approves every tool call, so a CI job is never interrupted by a prompt.',
        },
        {
          id: 'd',
          text: 'Plan mode, since it is read-only and so cannot execute anything unexpected during the CI run.',
        },
      ],
      correct: ['a'],
      explanation:
        'dontAsk permits only pre-approved tools and read-only work and gates any tool call ' +
        'not on the allow list, which is why the material describes it as built for ' +
        'locked-down CI and scripts. acceptEdits is called out as good for trusted local ' +
        'work but explicitly not for scripts. bypassPermissions gates nothing at all and ' +
        'belongs only inside an isolated container or VM with a disposable environment, so ' +
        'it fails the requirement that out-of-scope calls be stopped. Plan mode gates every ' +
        'edit and shell command and is not for tasks that write output, so the CI job could ' +
        'not do its work.',
      page: 29,
      verify: false,
    },
    {
      id: 'claude-code-mcp-002',
      domain: 'claude-code-mcp',
      type: 'single',
      stem:
        'A developer working locally wants file edits inside the repository to go through ' +
        'without prompting, while shell commands beyond filesystem operations still stop for ' +
        'approval. Which permission mode matches that description?',
      options: [
        {
          id: 'a',
          text: 'acceptEdits, auto-approving reads, edits and filesystem commands in the working directory.',
        },
        {
          id: 'b',
          text: 'Plan mode, which permits edits inside the working directory but blocks every shell command.',
        },
        {
          id: 'c',
          text: 'dontAsk, which approves the tools on the allow list and quietly skips over everything else.',
        },
        {
          id: 'd',
          text: 'Auto, which approves all tool calls and gates only deploys, migrations and mass deletes.',
        },
      ],
      correct: ['a'],
      explanation:
        'acceptEdits auto-approves reads, edits and filesystem commands in the working ' +
        'directory while gating other shell commands, writes outside the working directory ' +
        'and protected paths - exactly the split described. Plan mode is read-only with no ' +
        'edits at all, so it cannot permit the edits. dontAsk gates a call that is not on ' +
        'the allow list rather than skipping it, and it is aimed at locked-down CI. Auto ' +
        'approves far more than was asked for, reserving its gates for production deploys ' +
        'and migrations, mass deletes and credential exfiltration.',
      page: 29,
      verify: false,
    },
    {
      id: 'claude-code-mcp-003',
      domain: 'claude-code-mcp',
      type: 'single',
      stem:
        'Per the current documentation, which statement describes the auto permission mode in ' +
        'Claude Code?',
      options: [
        {
          id: 'a',
          text: 'It auto-approves tool calls while background safety checks verify that actions match your request.',
        },
        {
          id: 'b',
          text: 'It is labelled a research preview, so its approvals should not be relied on outside experimental work.',
        },
        {
          id: 'c',
          text: 'It approves every tool call with no checks at all, and belongs only in a disposable container.',
        },
        {
          id: 'd',
          text: 'It auto-approves reads and edits inside the working directory and gates the remaining shell commands.',
        },
      ],
      correct: ['a'],
      explanation:
        'The documentation describes auto mode as auto-approving tool calls with background ' +
        'safety checks that verify the actions align with your request. The notes label it ' +
        'Auto (research preview) in two places, but the documentation no longer does, so ' +
        'that label is stale and must not be treated as the defining fact. Approving every ' +
        'call with no checks describes bypassPermissions, which is container-only. ' +
        'Auto-approving reads and edits in the working directory describes acceptEdits.',
      page: 29,
      verify: true,
    },
    {
      id: 'claude-code-mcp-004',
      domain: 'claude-code-mcp',
      type: 'single',
      stem:
        'A platform team sets a deny rule on a destructive shell command in enterprise ' +
        'managed settings. A developer then starts a session in bypassPermissions mode. What ' +
        'happens when Claude attempts that command?',
      options: [
        {
          id: 'a',
          text: 'It is blocked: deny rules are evaluated before ask and allow rules in every permission mode.',
        },
        {
          id: 'b',
          text: 'It runs, because bypassPermissions skips rule evaluation and cannot be combined with deny rules.',
        },
        {
          id: 'c',
          text: 'It prompts, because bypassPermissions downgrades a deny rule to an ask rule for that session.',
        },
        {
          id: 'd',
          text: 'It runs if any matching allow rule happens to be written more specifically than the deny rule.',
        },
      ],
      correct: ['a'],
      explanation:
        'Permission rules are evaluated deny, then ask, then allow, first match wins, in ' +
        'every permission mode, and rule specificity does not change that order: if a tool ' +
        'is denied at any level, no other level can allow it. A consequence worth knowing is ' +
        'that a broad deny rule cannot carry allowlist exceptions. The notes agree, listing ' +
        'under configuration bugs that bypassPermissions still observes any deny rules, and ' +
        'the permissions page states that enterprise level deny is the most durable control ' +
        'even when bypass is set. The setting that ' +
        'actually prevents bypass mode being used at all is ' +
        'permissions.disableBypassPermissionsMode, normally applied in managed settings.',
      page: 29,
      verify: true,
    },
    {
      id: 'claude-code-mcp-005',
      domain: 'claude-code-mcp',
      type: 'single',
      stem:
        'A new team member asks about the base permission mode - the one the CLI labels ' +
        'Manual, that settings files write as default, and that also accepts manual as an ' +
        'alias. What does that mode do?',
      options: [
        {
          id: 'a',
          text: 'Reads are allowed, while edits and shell commands are gated behind approval.',
        },
        {
          id: 'b',
          text: 'Edits are blocked outright, so only read-only exploration is possible in the session.',
        },
        {
          id: 'c',
          text: 'Reads and edits inside the working directory go through, and other shell commands are gated.',
        },
        {
          id: 'd',
          text: 'Only tools on the allow list run, and anything else is gated before it can execute.',
        },
      ],
      correct: ['a'],
      explanation:
        'The base mode is read-only and gates edits and shell commands - safe but slow, in ' +
        'the words of the notes. Its naming is the thing most often got wrong rather than ' +
        'its behaviour: default is the value written into a settings file, the CLI presents ' +
        'the mode as Manual, and manual is accepted as an alias, so all three refer to the ' +
        'same mode and none of them is a separate mode. Blocking edits outright with no ' +
        'approval path is Plan mode. Auto-approving edits in the working directory is ' +
        'acceptEdits. Running only allow-listed tools is dontAsk.',
      page: 29,
      verify: true,
    },
    {
      id: 'claude-code-mcp-006',
      domain: 'claude-code-mcp',
      type: 'single',
      stem:
        'A developer wants a permission tweak that applies only to their own checkout of a ' +
        'shared repository and that is never committed. Which settings file is that?',
      options: [
        {
          id: 'a',
          text: 'settings.local.json, the local project layer, which is git-ignored.',
        },
        {
          id: 'b',
          text: '.claude/settings.json, the project layer, which travels with the repository.',
        },
        {
          id: 'c',
          text: '~/.claude/settings.json, the user layer, which applies across all of their projects.',
        },
        {
          id: 'd',
          text: 'managed-settings.json, the enterprise layer, deployed through centrally managed config.',
        },
      ],
      correct: ['a'],
      explanation:
        'Settings exist in four layers: user (~/.claude/settings.json), project ' +
        '(.claude/settings.json), local project (settings.local.json, git-ignored) and ' +
        'enterprise (managed-settings.json). Only the local project file is git-ignored, so ' +
        'it is the one place a per-checkout override stays out of the commit. The user layer ' +
        'would apply to every project rather than this checkout, the project file is ' +
        'committed and shared with the team, and enterprise managed settings are centrally ' +
        'deployed - which is also why the most durable deny rules are placed there.',
      page: 29,
      verify: false,
    },
    {
      id: 'claude-code-mcp-007',
      domain: 'claude-code-mcp',
      type: 'single',
      stem:
        'A team has a standing rule that a particular migration script must never be run by ' +
        'the agent. It has lived in CLAUDE.md for a year, the file has grown steadily, and ' +
        'the agent now breaches the rule from time to time. What does the material recommend?',
      options: [
        {
          id: 'a',
          text: 'Move the constraint into a PreToolUse hook, which can inspect the call and block it.',
        },
        {
          id: 'b',
          text: 'Restate the rule near the top of CLAUDE.md and in stronger, more emphatic wording.',
        },
        {
          id: 'c',
          text: 'Move the rule into a scoped file under .claude/rules/ so it loads only where relevant.',
        },
        {
          id: 'd',
          text: 'Delegate the work to the Explore subagent, which reads project rules before it acts.',
        },
      ],
      correct: ['a'],
      explanation:
        'The material is explicit that rules in CLAUDE.md get diluted over time as new ' +
        'constraints are added, while hooks never get diluted. A PreToolUse hook can examine ' +
        'the tool call and block it, which the notes call better than relying on a CLAUDE.md ' +
        'instruction. Rewording leaves the constraint inside the same diluting file. ' +
        'Scoping the rule under .claude/rules/ makes it load in fewer sessions, not more ' +
        'reliably. Explore and Plan subagents skip CLAUDE.md and project-level rules ' +
        'entirely, so delegating there removes the constraint rather than enforcing it.',
      page: 30,
      verify: false,
    },
    {
      id: 'claude-code-mcp-008',
      domain: 'claude-code-mcp',
      type: 'single',
      stem:
        'A team is dividing its durable project context between CLAUDE.md and files under ' +
        '.claude/rules/. Which division does the material describe?',
      options: [
        {
          id: 'a',
          text: 'Global constraints go in CLAUDE.md, and files under .claude/rules/ should be path-scoped.',
        },
        {
          id: 'b',
          text: 'Rules files are already path-scoped by default, so CLAUDE.md is only for whatever is left over.',
        },
        {
          id: 'c',
          text: 'Rules files load into every session, so CLAUDE.md should hold only on-demand procedures.',
        },
        {
          id: 'd',
          text: 'Both load into every session, so the division is only a matter of file size and readability.',
        },
      ],
      correct: ['a'],
      explanation:
        'Rules files apply instructions where relevant rather than being loaded into every ' +
        'session, and they can be scoped to specific paths - but by default a rule scope is ' +
        'global, the same as CLAUDE.md. That default is precisely why the guidance reads: ' +
        'include global rules in CLAUDE.md, and scope the rules files. CLAUDE.md content is ' +
        'appended to the prompt whenever it is found, so it is always present and should be ' +
        'kept small, holding only constraints that change agent behaviour; the mechanism for ' +
        'loading everything else on demand is skills, not rules files.',
      page: 30,
      verify: false,
    },
    {
      id: 'claude-code-mcp-009',
      domain: 'claude-code-mcp',
      type: 'multi',
      stem:
        'A team wants to inject repository context into each request before Claude begins ' +
        'work on it, and separately to write one final audit record at the point the session ' +
        'ends. Which two hook lifecycle events serve those jobs? (Select 2.)',
      options: [
        {
          id: 'a',
          text: 'UserPromptSubmit, which runs after a prompt is submitted, before execution.',
        },
        {
          id: 'b',
          text: 'SessionEnd, which runs when the session ends, for teardown and final writes.',
        },
        {
          id: 'c',
          text: 'Stop, which runs at the end of a turn, for cleanups and similar work.',
        },
        {
          id: 'd',
          text: 'PostToolUse, which runs after a tool call and applies automated side effects.',
        },
      ],
      correct: ['a', 'b'],
      explanation:
        'UserPromptSubmit runs when a prompt is submitted but before execution, which is ' +
        'where the material places context injection and request validation. SessionEnd runs ' +
        'when the session ends and is where teardown tasks, final audit writes and ' +
        'session-closed notifications belong. Stop runs at the end of a turn, so it fires ' +
        'many times in a session and is the wrong granularity for one end-of-session record. ' +
        'PostToolUse fires after each individual tool call. The seven events are PreToolUse, ' +
        'PostToolUse, UserPromptSubmit, Stop, Notification, SessionStart and SessionEnd.',
      page: 30,
      verify: false,
    },
    {
      id: 'claude-code-mcp-010',
      domain: 'claude-code-mcp',
      type: 'multi',
      stem:
        'An architect is choosing which agent to delegate a refactor to, given that the ' +
        'project constraints in CLAUDE.md must be respected and a team skill is needed. ' +
        'Which two statements about subagents at startup are accurate? (Select 2.)',
      options: [
        {
          id: 'a',
          text: 'The Explore and Plan subagents skip CLAUDE.md and project-level rules to stay fast.',
        },
        {
          id: 'b',
          text: 'Subagents do not inherit skills, so a custom subagent must load what it needs.',
        },
        {
          id: 'c',
          text: 'The general-purpose subagent also skips CLAUDE.md, since only the main agent loads it.',
        },
        {
          id: 'd',
          text: 'Built-in subagents come with the project skills preloaded, so no custom agent is needed.',
        },
      ],
      correct: ['a', 'b'],
      explanation:
        'Built-in agents differ in what they load at startup: Explore and Plan skip ' +
        'CLAUDE.md, project-level rules and git status to keep research fast and cheap, ' +
        'while the general-purpose subagent loads both. That is why the material says to use ' +
        'the general-purpose or a custom subagent for tasks where project constraints must ' +
        'be respected, and that a custom subagent must explicitly load the rules it needs. ' +
        'Subagents do not inherit skills, and built-in agents have no preloaded skills, so a ' +
        'task requiring a skill needs a custom subagent that loads it.',
      page: 30,
      verify: false,
    },
    {
      id: 'claude-code-mcp-011',
      domain: 'claude-code-mcp',
      type: 'single',
      stem:
        'A platform team has a working setup of skills, hooks, subagents and MCP server ' +
        'configuration that it wants other teams to install in one step, with versions and a ' +
        'distribution channel. Which packaging unit does the material point to?',
      options: [
        {
          id: 'a',
          text: 'A plugin, which is a versioned bundle distributed through a marketplace.',
        },
        {
          id: 'b',
          text: 'A set of skills committed under .claude/skills for each team to copy across.',
        },
        {
          id: 'c',
          text: 'A custom command under .claude/commands that runs the setup when it is invoked.',
        },
        {
          id: 'd',
          text: 'An entry in CLAUDE.md documenting how each team can reproduce the configuration.',
        },
      ],
      correct: ['a'],
      explanation:
        'A plugin bundles skills, hooks, subagents and MCP servers into a single installable ' +
        'unit, versioned and distributed through a marketplace, and a single install wires ' +
        'each piece into its target location - skills into a skills directory, hooks, ' +
        'subagents and settings into theirs. A skill is the right unit when a procedure ' +
        'should stay out of context until needed; a custom command is the right unit when a ' +
        'developer wants a predictable named entry point for a high-frequency procedure. ' +
        'Neither carries hooks, subagents or MCP configuration, and CLAUDE.md documents ' +
        'rather than installs.',
      page: 32,
      verify: false,
    },
    {
      id: 'claude-code-mcp-012',
      domain: 'claude-code-mcp',
      type: 'single',
      stem:
        'A team packages its internal workflow as a plugin and installs it on a clean ' +
        'machine. The workflow behaved safely in the original repository, which had a deny ' +
        'rule and a PreToolUse hook in project settings. What should the team check first?',
      options: [
        {
          id: 'a',
          text: 'Whether the deny rule and hook were added to the plugin, as local ones do not carry over.',
        },
        {
          id: 'b',
          text: 'Whether the marketplace was registered with /plugin marketplace add before installing.',
        },
        {
          id: 'c',
          text: 'Whether the plugin name collides with another plugin, which would break command namespacing.',
        },
        {
          id: 'd',
          text: 'Whether the skills in the plugin landed in a skills directory instead of in .claude/rules/.',
        },
      ],
      correct: ['a'],
      explanation:
        'The risk the material names for plugins is exactly this one: a deny rule or hook ' +
        'relied on locally is not included in the plugin unless it is added explicitly, so ' +
        'the protection may not carry over to the installation. Installing does place skills ' +
        'in a skills directory and hooks, subagents and settings in their respective ' +
        'locations, so misplacement is not the failure mode. A missing marketplace would ' +
        'stop the install rather than silently drop a guardrail. Plugin names do prefix ' +
        'every command in the bundle, but that is an interface concern, not a safety one.',
      page: 32,
      verify: false,
    },
    {
      id: 'claude-code-mcp-013',
      domain: 'claude-code-mcp',
      type: 'single',
      stem:
        'A team is connecting Claude Code to an MCP server that runs on a remote host inside ' +
        'the corporate network. A colleague suggests SSE, because an older internal server ' +
        'uses it. What should the team do?',
      options: [
        {
          id: 'a',
          text: 'Use HTTP, which is the recommended transport for a non-local server; SSE is legacy.',
        },
        {
          id: 'b',
          text: 'Use SSE, which remains the supported transport for any server reached over the network.',
        },
        {
          id: 'c',
          text: 'Use stdio, which reaches a remote server by relaying standard input and output over SSH.',
        },
        {
          id: 'd',
          text: 'Either HTTP or SSE, since the transport choice only affects local process management.',
        },
      ],
      correct: ['a'],
      explanation:
        'HTTP is the recommended transport for a non-local server, and SSE has been ' +
        'superseded by HTTP transport and should be treated as legacy. Stdio runs the server ' +
        'as a local process on the same machine as the client, communicating over standard ' +
        'input and output, so it is not a remote transport at all. The transport choice is ' +
        'not cosmetic either: transport and configuration scope are independent decisions ' +
        'with co-dependent consequences, which is why the guidance is to match the transport ' +
        'to where the server runs before choosing a scope for it.',
      page: 33,
      verify: false,
    },
    {
      id: 'claude-code-mcp-014',
      domain: 'claude-code-mcp',
      type: 'single',
      stem:
        'A study note states that MCP tool definitions occupy the context window up front for ' +
        'connected servers, with an opt-in mode that loads them only while they stay under ' +
        '10% of the context window. What correction does the documentation require?',
      options: [
        {
          id: 'a',
          text: 'Tool search is on by default and defers definitions; the 10% figure is for the auto setting.',
        },
        {
          id: 'b',
          text: 'The default is definitions loaded up front, and connecting fewer servers is the only remedy.',
        },
        {
          id: 'c',
          text: 'The 10% threshold is measured against the output token limit rather than the context window.',
        },
        {
          id: 'd',
          text: 'Server instructions are deferred with the definitions, so only tool names load at session start.',
        },
      ],
      correct: ['a'],
      explanation:
        'The documented default is tool search on, which defers MCP tool definitions until ' +
        'they are needed, so only tool names and server instructions load at session start - ' +
        'server instructions are not deferred. The 10% figure is real but belongs ' +
        'specifically to ENABLE_TOOL_SEARCH=auto, the threshold mode: definitions load up ' +
        'front while they total less than 10% of the context window, and all of them defer ' +
        'once they reach 10%. The notes now name that mode, calling it the opt-in auto mode, ' +
        'so the number and the setting line up. What remains stale is the blanket claim ' +
        'above it that definitions occupy context up front for connected servers, which is ' +
        'true only of the threshold mode below its threshold. Connecting only the servers ' +
        'you need is still sound advice, but it is not the ' +
        'correction being asked for.',
      page: 33,
      verify: true,
    },
    {
      id: 'claude-code-mcp-015',
      domain: 'claude-code-mcp',
      type: 'single',
      stem:
        'A developer adds an MCP server that runs as a local process over stdio, then wants ' +
        'to commit it at project scope in .mcp.json so the whole team picks it up. Why does ' +
        'the material advise against that combination?',
      options: [
        {
          id: 'a',
          text: 'A stdio server runs on one machine, so it cannot serve a scope shared across the team.',
        },
        {
          id: 'b',
          text: 'Project scope is reserved for enterprise deployment through centrally managed config.',
        },
        {
          id: 'c',
          text: 'Project scope stores servers in ~/.claude.json, which is personal and never committed.',
        },
        {
          id: 'd',
          text: 'User scope is the only scope able to start a server process on the machine in front of you.',
        },
      ],
      correct: ['a'],
      explanation:
        'Transport and scope are independent decisions with co-dependent consequences, and a ' +
        'stdio server cannot be project-scoped because it runs on one machine. A ' +
        'project-scoped server declared in .mcp.json at the repository root runs from each ' +
        'teammate machine, so every team member would need the same runtime installed. The ' +
        'four scopes are local (current project, stored in ~/.claude.json and not shared), ' +
        'user (personal settings across all projects), project (.mcp.json, accessible to the ' +
        'team) and enterprise (deployed through centrally managed config). So it is local ' +
        'scope, not project scope, that lives in ~/.claude.json, and enterprise scope, not ' +
        'project scope, that is centrally deployed.',
      page: 34,
      verify: false,
    },
    {
      id: 'claude-code-mcp-016',
      domain: 'claude-code-mcp',
      type: 'single',
      stem:
        'A team connects the GitHub MCP server and wants issue creation to run without a ' +
        'prompt, while every other tool on that same server continues to prompt. Which ' +
        'control does the material describe for this?',
      options: [
        {
          id: 'a',
          text: 'An allow rule on mcp__github__create_issue, which targets a tool not the server.',
        },
        {
          id: 'b',
          text: 'An allow rule on the github server as a whole, plus a deny rule for each other tool.',
        },
        {
          id: 'c',
          text: 'Switching the session to acceptEdits, which auto-approves the tools the team uses most.',
        },
        {
          id: 'd',
          text: 'A PreToolUse hook approving issue creation, since permission rules apply per server only.',
        },
      ],
      correct: ['a'],
      explanation:
        'MCP tool permission rules are identified by server and tool name in the form ' +
        'mcp__server__tool, so an allow rule on mcp__github__create_issue lets that one tool ' +
        'run without prompting while other tools on the GitHub server still prompt. The rule ' +
        'decides whether an exposed tool may run, which the material calls a governance ' +
        'control. Because rules already target a single tool, blanket server allowance with ' +
        'per-tool denials is unnecessary. acceptEdits governs edits and filesystem commands, ' +
        'not MCP tools. On the API side the comparable control is the mcp_toolset object, ' +
        'whose per-tool enabled flag exposes only specific tools.',
      page: 33,
      verify: false,
    },
    {
      id: 'claude-code-mcp-017',
      domain: 'claude-code-mcp',
      type: 'multi',
      stem:
        'A repository is found with an API key written inline into .mcp.json. Beyond moving ' +
        'the value into an environment variable, which two measures does the material name ' +
        'to stop this recurring? (Select 2.)',
      options: [
        {
          id: 'a',
          text: 'A CLAUDE.md instruction that credentials are never written inline into .mcp.json.',
        },
        {
          id: 'b',
          text: 'A PreToolUse hook inspecting write and edit ops on .mcp.json for credentials.',
        },
        {
          id: 'c',
          text: 'A PostToolUse hook that logs every tool call for later audit and compliance review.',
        },
        {
          id: 'd',
          text: 'A rotation schedule that replaces the credential on a fixed interval after exposure.',
        },
      ],
      correct: ['a', 'b'],
      explanation:
        'The two mitigations named are an instruction in CLAUDE.md that credentials are ' +
        'never written inline into .mcp.json, and a PreToolUse hook that inspects write and ' +
        'edit operations against .mcp.json for credentials and blocks them where needed. A ' +
        'PostToolUse hook logging tool calls is the audit control for regulated ' +
        'environments: it records what happened rather than preventing it. Rotation matters ' +
        'but replaces an exposed credential rather than keeping the next one out of the ' +
        'config file, and it is automatable only when the key is not stored where it is ' +
        'used. The underlying principle is separation - a credential never travels with the ' +
        'config that references it, because config files get committed, shared and cloned.',
      page: 34,
      verify: false,
    },
  ],
});
