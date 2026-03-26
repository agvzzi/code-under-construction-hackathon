# Code Under Construction - Hackathon

![Hackathon Logo](docs/images/hackathon-logo.png)

> **Build Your Own AI-Powered Workflow with GitHub Copilot**
>
> Choose a use case. Design your own agents, prompts, skills, and MCP server configuration. Execute your workflow and deliver results.

---

## The Challenge

Your team will **build a custom agentic workflow from scratch** using GitHub Copilot's extensibility features:

- **Custom Agents** (`.github/agents/`) — specialized AI roles with specific tools and handoffs
- **Reusable Prompts** (`.github/prompts/`) — sequential workflow steps your agents execute
- **Skills** (`.github/skills/`) — domain knowledge packages for your agents
- **MCP Servers** (`.vscode/mcp.json`) — tool integrations (Azure, Playwright, docs, etc.)

You decide what agents you need, what each one does, how they hand off to each other, and what prompts drive the workflow. Then you execute it and deliver the output.

---

## Choose Your Use Case

| | Use Case 1: IaC | Use Case 2: Discovery | Use Case 3: Spec-Driven |
|---|---|---|---|
| **Type** | Greenfield IaC | Brownfield Assessment | Greenfield Application |
| **Goal** | Deploy Azure infrastructure from scratch | Discover & assess a live Azure environment | Build a web app from specifications |
| **You Build** | Agents + prompts for an IaC pipeline | Agents + prompts for a discovery pipeline | Agents + prompts for a spec-driven pipeline |
| **Output** | Bicep modules + deployed resources | Assessment reports + Mermaid diagrams | Working app + Playwright tests |
| **Guide** | [Use Case 1 Guide](docs/use-case-iac.md) | [Use Case 2 Guide](docs/use-case-discovery.md) | [Use Case 3 Guide](docs/use-case-spec-driven.md) |

---

## Prerequisites

- **Azure Subscription** with Contributor access
- **GitHub Copilot** license (Business or Enterprise recommended)
- **VS Code** (or Codespaces) with GitHub Copilot & Copilot Chat
- **Azure CLI** with Bicep installed

> **Tip**: Open this repo in **GitHub Codespaces** — the devcontainer pre-installs all tools automatically!

### Azure Login (Required Before Exercises)

Before starting any exercise, log in to Azure using the credentials provided by the hackathon coaches:

```bash
az login
```

After logging in, verify you are on the correct subscription:

```bash
az account show --query "{name:name, id:id, tenantId:tenantId}" -o table
```

> **Important**: Confirm with the hackathon coaches that the displayed subscription and tenant are correct before proceeding.

---

## Quick Start

### 1. Clone and Open

```bash
git clone https://github.com/pascalvanderheiden/code-under-construction-hackathon.git
cd code-under-construction-hackathon
```

Open in VS Code or Codespaces. The devcontainer will install all required tools.

### 2. Pick Your Use Case

Choose one use case and follow its step-by-step participant guide:

- [Use Case 1: Infrastructure as Code](docs/use-case-iac.md) — Build Azure infra with Bicep
- [Use Case 2: Agentic Discovery](docs/use-case-discovery.md) — Discover & assess a live Azure environment
- [Use Case 3: Spec-Driven Development](docs/use-case-spec-driven.md) — Build a web app from specs

### 3. Build Your Agentic Workflow

Each guide walks you through:

1. **Define your goal** — What exactly are you building or discovering?
2. **Choose your tools** — Which MCP servers, skills, and extensions do you need?
3. **Design your agents** — What roles do you need? How do they hand off?
4. **Write your prompts** — One prompt per workflow step, executed in order
5. **Execute & iterate** — Run your prompts, verify output, refine
6. **Verify & present** — Demo your workflow and results

### 4. Or Follow the Pre-Built Walkthrough

Don't want to build your own agentic template? Each use case has a **sample walkthrough** that walks you step-by-step through executing the pre-built agents and prompts:

- [Sample Walkthrough: IaC](docs/sample/sample-iac.md)
- [Sample Walkthrough: Discovery](docs/sample/sample-discovery.md)
- [Sample Walkthrough: Spec-Driven](docs/sample/sample-spec-driven.md)

### 5. Get Unstuck

If you're building your own template and get stuck, this repo includes **reference examples** — agents, prompts, skills, and MCP configuration. Browse them for inspiration, but build your own!

---

## Available MCP Servers

These MCP servers are pre-configured in `.vscode/mcp.json` and ready to use in your agents:

| Server | Purpose | Useful For |
|---|---|---|
| **Azure MCP** | Azure resource management, discovery, deployment | All use cases |
| **Learn MCP** | Microsoft documentation, WAF/CAF references | Use Cases 1 & 2 |
| **Playwright MCP** | Browser automation and E2E testing | Use Case 3 |

> The **Bicep MCP** is auto-enabled by the `ms-azuretools.vscode-bicep` extension — no manual configuration needed.

You can add more MCP servers to `.vscode/mcp.json` as needed for your workflow.

---

## Reference Examples

This repo includes a complete set of example agents, prompts, and skills that demonstrate one way to solve each use case. **These are NOT mandatory** — they exist so you can peek at them when stuck.

### Example Agents (`.github/agents/`)

| Agent | Role | Use Case |
|---|---|---|
| `architect` | Architecture designer | IaC |
| `reviewer` | WAF/CAF reviewer & assessor | IaC, Discovery |
| `planner` | Development task planner | IaC |
| `implementer` | Bicep code writer | IaC |
| `tester` | Infrastructure validator | IaC |
| `documenter` | Documentation generator | IaC |
| `deployer` | Azure deployer | IaC, Spec-Driven |
| `discoverer` | Azure environment scanner | Discovery |
| `reporter` | Report & diagram writer | Discovery |
| `migration-planner` | PaaS migration planner | Discovery |
| `spec-coach` | Spec-driven methodology coach | Spec-Driven |

### Example Prompts (`.github/prompts/`)

| Workflow | Prompts |
|---|---|
| **IaC** | `iac-1-architect` → `iac-2-review` → `iac-3-plan` → `iac-4-implement` → `iac-5-test` → `iac-6-document` → `iac-7-deploy` |
| **Discovery** | `disc-1-discover` → `disc-2-assess` → `disc-3-report` → `disc-4-migration` → `disc-5-full-pipeline` |
| **Spec-Driven** | `spec-1-brainstorm` → `spec-2-setup` → Spec Kit/OpenSpec commands |

### Copilot Instruction Files (`.github/instructions/`)

These instruction files **auto-activate** when you create or edit agents, prompts, skills, or instructions — giving Copilot real-time guidance on how to write them correctly:

| File | Auto-Activates On | What It Does |
|---|---|---|
| `agents.instructions.md` | `**/*.agent.md` | Guides you through agent frontmatter, tools, handoffs, and best practices |
| `prompt.instructions.md` | `**/*.prompt.md` | Guides you through prompt structure, frontmatter, inputs, and output definitions |
| `agent-skills.instructions.md` | `**/.github/skills/**/SKILL.md` | Guides you through skill creation, descriptions, and resource bundling |
| `instructions.instructions.md` | `**/*.instructions.md` | Guides you through writing custom instruction files |

> **Pro tip**: Just start creating a file (e.g., `.github/agents/my-agent.agent.md`) and Copilot will automatically load the matching guidelines!

### Example Skills (`.github/skills/`)

| Skill | Purpose |
|---|---|
| `find-skills` | Discover and install additional skills |
| `update-avm-modules-in-bicep` | Keep AVM module versions current |
| `terraform-style-guide` | Terraform HCL standards |
| `spec-driven-guide` | Spec-driven methodology reference |

### Sample Walkthroughs ([docs/sample/](docs/sample/))

Step-by-step guides that execute the pre-built agentic template — for teams who want to follow along rather than build from scratch:

| Walkthrough | Use Case | What You'll Do |
|---|---|---|
| [IaC Walkthrough](docs/sample/sample-iac.md) | Use Case 1 | Run all 9 IaC prompts end-to-end: architect → review → plan → implement → test → document → deploy |
| [Discovery Walkthrough](docs/sample/sample-discovery.md) | Use Case 2 | Run all 5 discovery prompts: discover → assess → report → migration plan |
| [Spec-Driven Walkthrough](docs/sample/sample-spec-driven.md) | Use Case 3 | Run all 6 spec-driven prompts: brainstorm → setup → specify → implement → test → deploy |

---

## Project Structure

```
.
├── .devcontainer/
│   └── devcontainer.json               # Dev environment (Codespaces-ready)
├── .github/
│   ├── agents/                          # 📖 Example agents (reference)
│   ├── instructions/                    # 🤖 Auto-activating Copilot guidelines
│   ├── skills/                          # 📖 Example skills (reference)
│   ├── prompts/                         # 📖 Example prompts (reference)
│   └── copilot-instructions.md         # Workspace-wide Copilot context
├── .vscode/
│   └── mcp.json                         # MCP server configuration
├── docs/
│   ├── use-case-iac.md                  # Use Case 1 participant guide
│   ├── use-case-discovery.md            # Use Case 2 participant guide
│   ├── use-case-spec-driven.md          # Use Case 3 participant guide
│   ├── images/
│   └── sample/                          # 📖 Step-by-step walkthroughs & examples
├── LICENSE
└── README.md
```

---

## Tips for Hackathon Teams

1. **Pick ONE use case** — Focus your team's energy on one path
2. **Build your own agents** — Don't just use the examples; create agents tailored to your workflow
3. **Start simple** — One agent, one prompt, get it working, then expand
4. **Number your prompts** — Sequential numbering makes the workflow easy to follow
5. **Use Codespaces** — Everything is pre-configured, no local setup needed
6. **Test each step** — Verify agent output before moving to the next prompt
7. **Peek at examples when stuck** — The reference agents, prompts, and samples are there to help
8. **Be creative** — There's no single right answer; design the workflow your way

---

## License

[MIT](LICENSE)

---

*Built for the Code Under Construction Hackathon*
