import test from "node:test";
import assert from "node:assert/strict";

import { normalizeMessage } from "../src/core/message-normalizer.js";

test("normalizes platform messages without retaining page HTML", async () => {
  const message = await normalizeMessage({
    platform: "whatsapp",
    platformAccountId: "sales@example.com",
    platformConversationId: "buyer-1",
    direction: "customer",
    senderName: "Maria",
    sentAt: "2026-07-25T09:00:00Z",
    type: "text",
    text: "Please quote five units",
    sourceMetadata: { visibleIndex: 3 },
    html: "<strong>must not upload</strong>"
  }, {
    platform: "whatsapp",
    platformAccountId: "sales@example.com",
    platformConversationId: "buyer-1"
  });

  assert.equal(message.platform, "whatsapp");
  assert.equal(message.direction, "customer");
  assert.equal(message.text, "Please quote five units");
  assert.equal(message.html, undefined);
  assert.match(message.rawFingerprint, /^[a-f0-9]{64}$/);
});

test("same visible message gets a stable fingerprint", async () => {
  const source = {
    platform: "alibaba",
    platformConversationId: "thread-2",
    senderName: "Buyer",
    sentAt: "2026-07-25T09:10:00Z",
    type: "text",
    text: "FOB Shanghai"
  };

  const context = {
    platform: "alibaba",
    platformAccountId: "seller-1",
    platformConversationId: "thread-2"
  };
  const first = await normalizeMessage(source, context);
  const second = await normalizeMessage(source, context);
  assert.equal(first.rawFingerprint, second.rawFingerprint);
});
