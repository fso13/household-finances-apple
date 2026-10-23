(function () {
  "use strict";

  var root = document.documentElement;
  var toggle = document.getElementById("theme-toggle");
  var year = document.getElementById("year");

  if (year) {
    year.textContent = String(new Date().getFullYear());
  }

  if (!toggle) {
    return;
  }

  function sync() {
    var dark = root.dataset.theme === "dark";
    var label = dark ? "Включить светлую тему" : "Включить тёмную тему";
    toggle.setAttribute("aria-label", label);
    toggle.setAttribute("title", label);
  }

  toggle.addEventListener("click", function () {
    var next = root.dataset.theme === "dark" ? "light" : "dark";
    root.dataset.theme = next;
    try {
      localStorage.setItem("theme", next);
    } catch (error) {
      /* localStorage может быть недоступен */
    }
    sync();
  });

  sync();
})();
