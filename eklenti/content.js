// content.js
// YouTube video elementinin currentTime'ini periyodik okuyup
// background service worker'a iletir.
(function () {
  let lastSentSecond = -1;
  let intervalId = null;

  function getMainVideo() {
    return (
      document.querySelector("#movie_player video.html5-main-video") ||
      document.querySelector(".html5-video-player video.html5-main-video") ||
      document.querySelector("video.html5-main-video") ||
      document.querySelector("#movie_player video") ||
      document.querySelector("video")
    );
  }

  function tick() {
    if (!chrome.runtime || !chrome.runtime.id) {
      if (intervalId) clearInterval(intervalId);
      return;
    }

    const video = getMainVideo();
    if (!video || video.paused || video.seeking) return;

    const t = video.currentTime;
    const sec = Math.floor(t);

    if (sec !== lastSentSecond) {
      lastSentSecond = sec;
      try {
        chrome.runtime.sendMessage({
          type: "time",
          time: t,
          url: location.href,
        });
      } catch (e) {
      }
    }
  }

  intervalId = setInterval(tick, 500);
})();
