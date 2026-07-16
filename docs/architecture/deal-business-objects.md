# Deal business objects

```mermaid
erDiagram
  DEAL ||--o| INQUIRY : originates_from
  DEAL }o--|| BUYER : commercial_party
  DEAL ||--|| WORKING_DRAFT : edits
  DEAL ||--o{ PUBLISHED_VERSION : freezes
  PUBLISHED_VERSION ||--o{ DELIVERY : delivered_through
  PUBLISHED_VERSION ||--o{ BUYER_RESPONSE : receives
  PUBLISHED_VERSION ||--o| ACCEPTANCE : accepted_by
  ACCEPTANCE ||--o{ FINAL_DOCUMENT : generates
  DEAL ||--o{ ACTIVITY : records

  PUBLISHED_VERSION {
    jsonb snapshot "immutable commercial content"
    integer number
    datetime published_at
  }
  DELIVERY {
    string channel
    string status
    datetime delivered_at
    string recipient
  }
  ACCEPTANCE {
    string acceptance_method
    jsonb snapshot "immutable accepted terms"
    jsonb selection
    boolean seller_recorded
  }
```

The Rails `Quote` model remains the persistence root for compatibility but is presented as Deal. `QuoteRevision` is the Published Version. `VersionDelivery`, `DealResponse` and `QuoteAcceptance` deliberately reference that immutable Version. Working-draft edits never mutate a Published Version or Acceptance snapshot.
