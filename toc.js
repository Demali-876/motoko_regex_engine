// Populate the sidebar
//
// This is a script, and not included directly in the page, to control the total size of the book.
// The TOC contains an entry for each page, so if each page includes a copy of the TOC,
// the total size of the page becomes O(n**2).
class MDBookSidebarScrollbox extends HTMLElement {
    constructor() {
        super();
    }
    connectedCallback() {
        this.innerHTML = '<ol class="chapter"><li class="chapter-item expanded "><a href="introduction.html"><strong aria-hidden="true">1.</strong> Introduction</a></li><li class="chapter-item expanded "><a href="syntax.html"><strong aria-hidden="true">2.</strong> Regular Expression Syntax</a></li><li class="chapter-item expanded "><a href="flags.html"><strong aria-hidden="true">3.</strong> Flags</a></li><li class="chapter-item expanded "><a href="functions.html"><strong aria-hidden="true">4.</strong> Functions</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="functions/search.html"><strong aria-hidden="true">4.1.</strong> search()</a></li><li class="chapter-item expanded "><a href="functions/match.html"><strong aria-hidden="true">4.2.</strong> match()</a></li><li class="chapter-item expanded "><a href="functions/findall.html"><strong aria-hidden="true">4.3.</strong> findAll()</a></li><li class="chapter-item expanded "><a href="functions/finditer.html"><strong aria-hidden="true">4.4.</strong> findIter()</a></li><li class="chapter-item expanded "><a href="functions/replace.html"><strong aria-hidden="true">4.5.</strong> replace()</a></li><li class="chapter-item expanded "><a href="functions/sub.html"><strong aria-hidden="true">4.6.</strong> sub()</a></li><li class="chapter-item expanded "><a href="functions/split.html"><strong aria-hidden="true">4.7.</strong> split()</a></li><li class="chapter-item expanded "><a href="functions/inspectregex.html"><strong aria-hidden="true">4.8.</strong> inspectRegex()</a></li><li class="chapter-item expanded "><a href="functions/inspectState.html"><strong aria-hidden="true">4.9.</strong> inspectState()</a></li><li class="chapter-item expanded "><a href="functions/enabledebug.html"><strong aria-hidden="true">4.10.</strong> enableDebug()</a></li></ol></li><li class="chapter-item expanded "><a href="match-records.html"><strong aria-hidden="true">5.</strong> Match Records</a></li><li class="chapter-item expanded "><a href="unicode-properties.html"><strong aria-hidden="true">6.</strong> Unicode Properties</a></li><li class="chapter-item expanded "><a href="backreferences.html"><strong aria-hidden="true">7.</strong> Backreferences</a></li><li class="chapter-item expanded "><a href="lookaround-assertions.html"><strong aria-hidden="true">8.</strong> Look Around Assertions</a></li><li class="chapter-item expanded "><a href="examples.html"><strong aria-hidden="true">9.</strong> Examples</a></li><li class="chapter-item expanded "><a href="contributing.html"><strong aria-hidden="true">10.</strong> Contributions</a></li></ol>';
        // Set the current, active page, and reveal it if it's hidden
        let current_page = document.location.href.toString().split("#")[0];
        if (current_page.endsWith("/")) {
            current_page += "index.html";
        }
        var links = Array.prototype.slice.call(this.querySelectorAll("a"));
        var l = links.length;
        for (var i = 0; i < l; ++i) {
            var link = links[i];
            var href = link.getAttribute("href");
            if (href && !href.startsWith("#") && !/^(?:[a-z+]+:)?\/\//.test(href)) {
                link.href = path_to_root + href;
            }
            // The "index" page is supposed to alias the first chapter in the book.
            if (link.href === current_page || (i === 0 && path_to_root === "" && current_page.endsWith("/index.html"))) {
                link.classList.add("active");
                var parent = link.parentElement;
                if (parent && parent.classList.contains("chapter-item")) {
                    parent.classList.add("expanded");
                }
                while (parent) {
                    if (parent.tagName === "LI" && parent.previousElementSibling) {
                        if (parent.previousElementSibling.classList.contains("chapter-item")) {
                            parent.previousElementSibling.classList.add("expanded");
                        }
                    }
                    parent = parent.parentElement;
                }
            }
        }
        // Track and set sidebar scroll position
        this.addEventListener('click', function(e) {
            if (e.target.tagName === 'A') {
                sessionStorage.setItem('sidebar-scroll', this.scrollTop);
            }
        }, { passive: true });
        var sidebarScrollTop = sessionStorage.getItem('sidebar-scroll');
        sessionStorage.removeItem('sidebar-scroll');
        if (sidebarScrollTop) {
            // preserve sidebar scroll position when navigating via links within sidebar
            this.scrollTop = sidebarScrollTop;
        } else {
            // scroll sidebar to current active section when navigating via "next/previous chapter" buttons
            var activeSection = document.querySelector('#sidebar .active');
            if (activeSection) {
                activeSection.scrollIntoView({ block: 'center' });
            }
        }
        // Toggle buttons
        var sidebarAnchorToggles = document.querySelectorAll('#sidebar a.toggle');
        function toggleSection(ev) {
            ev.currentTarget.parentElement.classList.toggle('expanded');
        }
        Array.from(sidebarAnchorToggles).forEach(function (el) {
            el.addEventListener('click', toggleSection);
        });
    }
}
window.customElements.define("mdbook-sidebar-scrollbox", MDBookSidebarScrollbox);
