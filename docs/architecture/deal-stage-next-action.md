# Quote lifecycle and next action

```mermaid
flowchart LR
  I[Add inquiry communication] --> A[Automatic grouped analysis]
  A --> C{Enough to create quote?}
  C -->|No| Q[Show next buyer question]
  C -->|Yes| D[Create working quote]
  D --> B[Resolve publication blockers]
  B --> P[Customer-view preview]
  P --> V[Confirm and publish Version]
  V --> O[Copy link / PDF / Excel / send]
  O --> F{Customer response}
  F -->|Question| R[Reply with Version context]
  F -->|Change| U[Review difference and apply to draft]
  U --> B
  F -->|Accept| X[Lock acceptance snapshot]
```

`QuoteLifecycle` supplies shared state and next action for Quote list and detail. `QuoteReadinessAudit` is the single publication gate. Viewed, delivered, expired and awaiting deposit are signals rather than separate workspaces.
