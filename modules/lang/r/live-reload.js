// Reloads the page once a restarted server answers again,
// but not after a session error on a server that kept running.
$(document).on("shiny:disconnected", function () {
  var down = false;
  setInterval(function () {
    fetch(location.href).then(
      function (response) {
        if (down && response.ok) location.reload();
      },
      function () {
        down = true;
      },
    );
  }, 500);
});
