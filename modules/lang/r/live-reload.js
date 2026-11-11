// Reloads the page once another server process answers,
// but not after a session error on a server that kept running.
// Compares servers rather than waiting to see one down,
// because browsers throttle polling in background tabs.
// Reloads only once: Safari cancels a pending reload on the next call.
{
  const server = `data-server="${document.currentScript.dataset.server}"`;
  $(document).one("shiny:disconnected", async function () {
    for (;;) {
      await new Promise((resolve) => setTimeout(resolve, 500));
      const html = await fetch(location.href, { cache: "no-store" })
        .then((response) => (response.ok ? response.text() : ""))
        .catch(() => "");
      if (html && !html.includes(server)) return location.reload();
    }
  });
}
// A newly opened page of this app closes its older ones,
// so that each `process-compose up` replaces the pages of the last.
// Reloads are no openings.
{
  const pages = new BroadcastChannel("nullkomma-pages");
  pages.onmessage = () => window.close();
  if (performance.getEntriesByType("navigation")[0]?.type === "navigate") {
    pages.postMessage("opened");
  }
}
