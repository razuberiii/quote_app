# Deal stages and Next action

```mermaid
flowchart LR
  D[Draft] -->|Publish immutable Version| C{Successful Delivery?}
  C -->|No| CD[Choose delivery method / Retry delivery]
  C -->|Yes: any channel| L[Live]
  L -->|Question| R[Reply to buyer]
  L -->|Returned file| RF[Review returned file]
  L -->|PO| PO[Review PO differences]
  L -->|Requested change| U[Prepare update → publish updated Version]
  L -->|Acceptance via any channel| A[Accepted]
  A -->|Final document required| FD[Generate / send final document]
  A -->|Payment workflow required| P[Confirm payment]
  A -->|No mandatory document/payment| W[Close as won]
  D --> X[Closed: Lost / Cancelled]
  L --> X
  A --> X
  X -->|Reopen with history| D
```

`DealProgress` is the single derivation point used by Inbox, Deals and Deal Overview. Viewed, Delivered, Expired, PO received, PI generated and payment received remain conditions or activities rather than user-visible top-level stages.
