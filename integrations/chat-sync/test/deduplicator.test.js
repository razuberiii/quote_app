import test from "node:test";
import assert from "node:assert/strict";

import { Deduplicator } from "../src/core/deduplicator.js";

test("persists and recognizes fingerprints", async () => {
  const values = new Map();
  const runtime = {
    storage: {
      get: async (key, fallback) => values.get(key) || fallback,
      set: async (key, value) => values.set(key, value)
    }
  };
  const deduplicator = new Deduplicator(runtime, "conversation-1");
  await deduplicator.load();
  assert.equal(deduplicator.has({ rawFingerprint: "a" }), false);
  await deduplicator.remember([{ rawFingerprint: "a" }]);
  assert.equal(deduplicator.has({ rawFingerprint: "a" }), true);

  const restored = new Deduplicator(runtime, "conversation-1");
  await restored.load();
  assert.equal(restored.has({ rawFingerprint: "a" }), true);
});
