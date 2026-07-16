# QA

Required gates are model/service tests for pricing, revisions, acceptance and PI; request tests for workspace boundaries and Buyer Room state; duplicate-operation tests; system tests for seller and buyer journeys; Chrome desktop/mobile screenshots under `tmp/review_shots/<run>`; asset build; migration; Brakeman; and live health/HTTPS checks.

No gate is reported as passed until its command has actually completed. Demo writes must remain isolated from production business records.
