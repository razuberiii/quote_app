# Quote business objects

```mermaid
erDiagram
  INQUIRY ||--o{ INQUIRY_MESSAGE : retains
  INQUIRY ||--o| QUOTE : creates
  QUOTE }o--|| CUSTOMER : prepared_for
  QUOTE ||--o{ QUOTE_ITEM : contains
  QUOTE ||--o{ QUOTE_REVISION : publishes
  QUOTE_REVISION ||--o{ VERSION_DELIVERY : delivered_through
  QUOTE_REVISION ||--o{ BUYER_QUESTION : receives
  QUOTE_REVISION ||--o{ CHANGE_REQUEST : receives
  QUOTE_REVISION ||--o| QUOTE_ACCEPTANCE : accepted_as
```

`Quote` is the editable commercial aggregate. `QuoteRevision` is the immutable Published Version used by the customer page, PDF and Excel. Customer questions and requested changes always reference the Version the buyer saw. Applying a structured change updates the working Quote and creates no historical mutation; a later publish creates the next Version.

Legacy Deal naming is compatibility-only in older controllers and persistence associations.
