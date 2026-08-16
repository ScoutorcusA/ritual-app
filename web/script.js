(async () => {
  const scriptUrl = new URL(document.currentScript.src);
  const localeRoot = new URL("assets/i18n/", scriptUrl);
  const manifest = await fetch(new URL("manifest.json", localeRoot)).then(
    (response) => response.json(),
  );
  const available = manifest.locales;
  const saved = localStorage.getItem("ritual-locale");
  const requested = [saved, ...navigator.languages].filter(Boolean);
  const selected =
    requested
      .map((code) =>
        available.find(
          (locale) =>
            locale.code.toLowerCase() === code.toLowerCase() ||
            locale.code.split("-")[0] === code.split("-")[0],
        ),
      )
      .find(Boolean) || available[0];

  const catalog = await fetch(
    new URL(`${selected.code}.json`, localeRoot),
  ).then((response) => response.json());
  const strings = catalog.strings;
  const translate = (source) => strings[source] || source;

  document.documentElement.lang = selected.code;
  document.documentElement.dir = selected.direction;
  document.title = translate(document.title);
  const webManifest = document.querySelector('link[rel="manifest"]');
  if (webManifest) {
    webManifest.href = new URL(`site-${selected.code}.webmanifest`, localeRoot);
  }

  const walker = document.createTreeWalker(
    document.body,
    NodeFilter.SHOW_TEXT,
  );
  const nodes = [];
  while (walker.nextNode()) nodes.push(walker.currentNode);
  for (const node of nodes) {
    if (node.parentElement?.closest("script, style")) continue;
    const source = node.nodeValue.trim().replace(/\s+/g, " ");
    if (!source || !strings[source]) continue;
    const leading = node.nodeValue.match(/^\s*/)[0];
    const trailing = node.nodeValue.match(/\s*$/)[0];
    node.nodeValue = `${leading}${translate(source)}${trailing}`;
  }

  for (const element of document.querySelectorAll("[aria-label], [title], [alt]")) {
    for (const attribute of ["aria-label", "title", "alt"]) {
      const source = element.getAttribute(attribute);
      if (source && strings[source]) {
        element.setAttribute(attribute, translate(source));
      }
    }
  }
  for (const meta of document.querySelectorAll("meta[content]")) {
    const source = meta.getAttribute("content");
    if (source && strings[source]) meta.setAttribute("content", translate(source));
  }

  const year = document.getElementById("year");
  if (year) year.textContent = new Date().getFullYear();

  if (available.length > 1) {
    const picker = document.createElement("select");
    picker.className = "language-picker";
    picker.setAttribute("aria-label", translate("Language"));
    for (const locale of available) {
      const option = document.createElement("option");
      option.value = locale.code;
      option.textContent = locale.name;
      option.selected = locale.code === selected.code;
      picker.append(option);
    }
    picker.addEventListener("change", () => {
      localStorage.setItem("ritual-locale", picker.value);
      location.reload();
    });
    document.querySelector(".site-header")?.insertBefore(
      picker,
      document.querySelector(".header-download"),
    );
  }
})().catch(() => {
  const year = document.getElementById("year");
  if (year) year.textContent = new Date().getFullYear();
});
