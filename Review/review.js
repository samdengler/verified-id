// The site's bar: the site name and links between the parts of the site, added
// to the header of every page of the review document.  The page's <base> is
// the document root, so "../" is the site root, where the home page is; the
// progress page is at ../progress/.
// scripts/site_nav.py defines the same bar for the other pages; change both
// together.
document.addEventListener("DOMContentLoaded", () => {
  const header = document.querySelector("header");
  if (!header || header.querySelector(".site-nav")) return;
  const nav = document.createElement("nav");
  nav.className = "site-nav";
  nav.setAttribute("aria-label", "Site");
  const links = [
    ["../progress/", "Progress"],
    ["./", "Review document", true],
  ];
  for (const [href, text, current] of links) {
    const a = document.createElement("a");
    a.href = href;
    a.textContent = text;
    if (current) a.setAttribute("aria-current", "page");
    nav.appendChild(a);
  }
  // The site name, leading home, as on every other page (MARK_PATH in scripts/site_nav.py).
  const mark = "M4 5h16a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2zm4 3.5a2.25 2.25 0 1 0 0 4.5"
    + "a2.25 2.25 0 0 0 0-4.5zM4.5 16.5h7c0-1.9-1.6-3-3.5-3s-3.5 1.1-3.5 3zM14 9v1.5h5.5V9zm0 3.5V14h4v-1.5z";
  const brand = document.createElement("a");
  brand.className = "brand";
  brand.href = "../";
  brand.innerHTML = '<svg class="mark" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" '
    + 'fill-rule="evenodd" d="' + mark + '"/></svg>Verified ID';
  // The same mark as the browser tab's icon (FAVICON in scripts/site_nav.py).
  const icon = document.createElement("link");
  icon.rel = "icon";
  icon.href = "data:image/svg+xml," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
    + '<path fill="#2a78d6" fill-rule="evenodd" d="' + mark + '"/></svg>');
  document.head.appendChild(icon);
  // Inside the title area: Verso's search box overlaps anything placed after it.
  const wrapper = header.querySelector(".header-title-wrapper") || header;
  wrapper.append(brand, nav);
});
