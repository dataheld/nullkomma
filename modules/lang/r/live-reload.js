// Reloads the page once another server process answers,
// but not after a session error on a server that kept running.
// Compares servers rather than waiting to see one down,
// because browsers throttle polling in background tabs.
{
  const server = `data-server="${document.currentScript.dataset.server}"`;
  $(document).on("shiny:disconnected", function () {
    setInterval(function () {
      fetch(location.href, { cache: "no-store" })
        .then((response) => response.ok && response.text())
        .then((html) => html && !html.includes(server) && location.reload())
        .catch(() => {});
    }, 500);
  });
}
