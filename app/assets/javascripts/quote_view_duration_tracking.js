// Quote View Duration Tracking
(function () {
  const QUOTE_SHARE_ID = document.currentScript.dataset.quoteShareId;
  const API_ENDPOINT = `/public/quote_view_events`;

  let startTime = Date.now();

  // Send duration when user leaves the page
  window.addEventListener("beforeunload", function () {
    const duration = Date.now() - startTime;

    // Use sendBeacon for reliable delivery even if page is closing
    const data = JSON.stringify({
      quote_share_id: QUOTE_SHARE_ID,
      duration_ms: duration,
    });

    navigator.sendBeacon(API_ENDPOINT, data);
  });

  // Also send duration periodically while user is still on page (every 5 minutes)
  setInterval(
    function () {
      const duration = Date.now() - startTime;

      fetch(API_ENDPOINT, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          quote_share_id: QUOTE_SHARE_ID,
          duration_ms: duration,
        }),
      }).catch((err) =>
        console.error("Failed to send quote view duration:", err),
      );
    },
    5 * 60 * 1000,
  ); // Every 5 minutes
})();
