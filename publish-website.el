(require 'package)
(package-initialize)

(require 'org)
(require 'ox-publish)
(require 'ox-html)
(require 'ox-rss)


;; Utility functions
(defun skw-blog/get-root-directory ()
  "Return the blog's root directory (where this file is located)."
  (if (null load-file-name)
      (expand-file-name default-directory)
    (file-name-directory load-file-name)))


(defun skw-blog/get-file-content (file)
  "Return the content of 'file' as a string"
  (with-temp-buffer
    (insert-file-contents file)
    (buffer-string)))


;; Custom variables. Edit them please!
(setq
 ;; General variables
 skw-blog/author "Skywhi"
 skw-blog/email "skywhi@skywhi.net"
 skw-blog/upstream-url "https://www.skywhi.net"
 skw-blog/site-name "Skywhi's Blog"

 ;; Shown when a page is shared on a platform that renders a link preview.
 ;; A 256x256 crop of the same picture as the favicon: the square shape suits
 ;; the summary card, and profile.jpg is 138x138, under the 144px floor below
 ;; which several platforms drop the image entirely.
 skw-blog/og-image (concat skw-blog/upstream-url "/static/img/og-image.jpg")

 ;; Pages that exist but should stay out of the sitemaps: the feed and the
 ;; homepage's include file are not pages at all, and the 404 is served for
 ;; every unknown path rather than visited on purpose.
 skw-blog/unlisted-pages '("rss.org" "index-no-preview.org" "404.org")

 ;; Location of custom directories and files
 skw-blog/rootdir      (skw-blog/get-root-directory)
 skw-blog/outdir       (concat skw-blog/rootdir "www/")
 skw-blog/srcdir       (concat skw-blog/rootdir "src/")
 skw-blog/header-file  (concat skw-blog/rootdir "templates/header.html")
 skw-blog/footer-file  (concat skw-blog/rootdir "templates/footer.html")

 ;; Where the vendored MathJax lives, as served. Must stay in sync with
 ;; MATHJAX_DIR in the Makefile, which is what puts the files there.
 skw-blog/mathjax-dir "/static/js/mathjax"

 ;; RSS feed
 skw-blog/rss-feedname "Skywhi's Blog"
 skw-blog/rss-filename "rss.org"
 skw-blog/rss-description "Sporadic posts about Emacs, security and other rabbit holes."

 ;; Number of entries listed under "Latest posts" on the homepage
 skw-blog/latest-posts-count 5

 ;; Main sitemap
 skw-blog/main-sitemap-title "\"Not all those who wander are lost.\" - J. R. R. Tolkien"

 ;; Stylesheets included by default
 skw-blog/main-css
 "<link rel=\"stylesheet\" type=\"text/css\" href=\"/static/css/style.css\"/>
<link rel=\"stylesheet\" type=\"text/css\" href=\"/static/css/htmlize.css\"/>
"
 ;; Favicon
 skw-blog/favicon
 "<link rel=\"icon\" href=\"/static/img/favicon.ico\" type=\"image/x-icon\">
"
 ;; Feed autodiscovery, so readers can find the feed from any page
 skw-blog/rss-link
 (concat "<link rel=\"alternate\" type=\"application/rss+xml\" title=\""
         skw-blog/rss-feedname "\" href=\"/rss.xml\">\n")
 )

(defvar skw-blog/header
  (skw-blog/get-file-content skw-blog/header-file))

(defvar skw-blog/footer
  (skw-blog/get-file-content skw-blog/footer-file))


(defun skw-blog/nav-href-for (input-file)
  "Return the header nav href matching 'input-file', or nil when none does."
  (let ((f (or input-file "")))
    (cond ((string-match-p "/posts/" f)        "/posts/")
          ((string-match-p "/notes/" f)        "/notes/")
          ((string-match-p "links\\.org\\'" f) "/links.html")
          ((string-match-p "now\\.org\\'" f)   "/now.html")
          ((string-match-p "about\\.org\\'" f) "/about.html"))))


(defun skw-blog/html-preamble (info)
  "Return the site header, marking the nav entry for the page being exported."
  (let ((href (skw-blog/nav-href-for (plist-get info :input-file))))
    (if (null href)
        skw-blog/header
      (replace-regexp-in-string
       (concat "<a href=\"" (regexp-quote href) "\"")
       (concat "<a href=\"" href "\" aria-current=\"page\"")
       skw-blog/header t t))))


;; MathJax resolves its font package against 'loader.paths.fonts', which
;; defaults to cdn.jsdelivr.net. The fonts are vendored (see the 'mathjax'
;; target in the Makefile), so that path has to be pointed at the local copy:
;; without it, every page carrying math quietly pulls ~1 MB of woff2 from a
;; third party -- on a site that otherwise makes no external request at all.
;; Org's stock template has no 'loader' section, hence the injection.
(defun skw-blog/mathjax-template-with-local-fonts (template)
  "Return 'template' with a loader path pointing MathJax at the vendored fonts."
  (let ((anchor "window.MathJax = {"))
    (unless (string-match-p (regexp-quote anchor) template)
      (error "MathJax template changed upstream: cannot inject the local font path"))
    (replace-regexp-in-string
     (regexp-quote anchor)
     (concat anchor "\n    loader: {paths: {fonts: '"
             skw-blog/mathjax-dir "/fonts'}},")
     template t t)))


;; Emacs and org-mode general options
;; (might redefine them later in templates or on a per-file basis)
(setq
 make-backup-files nil
 org-odd-levels-only t
 org-publish-timestamp-directory ".cache/"

 org-export-with-author nil
 org-export-with-email nil
 org-export-with-creator nil
 org-export-with-toc nil

 ;; Org stamps every exported page with a "<!-- build date -->" comment. Since
 ;; www/ is committed, that comment alone made every single page show up as
 ;; modified after a rebuild, whether or not anything about it had changed.
 org-export-time-stamp-file nil

 org-export-headline-levels 3
 org-export-with-section-numbers nil
 org-export-with-sub-superscripts nil
 org-export-with-toc nil
 org-export-with-broken-links t

 org-html-divs '((preamble  "header" "preamble")
                 (content   "main"   "content")
                 (postamble "footer" "postamble"))

 org-html-doctype "html5"
 org-html-head nil
 org-html-head-include-default-style nil
 org-html-head-include-scripts nil
 org-html-html5-fancy nil
 org-html-htmlize-output-type 'css

 org-html-table-use-header-tags-for-first-column nil

 org-html-mathjax-options `((path ,(concat skw-blog/mathjax-dir "/tex-mml-chtml.js"))
                            (scale 1.0) (align "center") (font "mathjax-modern") (overflow "overflow")
                            (tags "ams") (indent "0em") (multlinewidth "85%") (tagindent ".8em")
                            (tagside "right"))

 org-html-mathjax-template
 (skw-blog/mathjax-template-with-local-fonts org-html-mathjax-template))


;; Preview block
(defun skw-blog/get-preview (file)
  "Extract the content between #+begin_preview and #+end_preview blocks
   in 'file'. The block tags have to be on their own lines, preferably
   before and after paragraphs. Return an empty string when 'file' has
   no such block."
  (with-temp-buffer
    (message file)
    (insert-file-contents file)
    (goto-char (point-min))
    (let* ((beg (and (re-search-forward "^#\\+begin_preview$" nil t)
                     (+ 1 (point))))
           (end (and beg
                     (re-search-forward "^#\\+end_preview$" nil t)
                     (match-beginning 0))))
      (if end
          (replace-regexp-in-string "\n" " " (buffer-substring beg end))
        ""))))


;; Format list of blog post for the sitemap / index
(defun skw-blog/org-format-blog-post (entry style project)
  "Format 'entry' in org-publish 'project' sitemap to include a timestamp."
  (let ((entry-title (org-publish-find-title entry project)))
    (if (= (length entry-title) 0)
        (format "*%s*" entry)
      (format "{{{timestamp(%s)}}}: [[file:%s][%s]]"
              (format-time-string "%Y-%m-%d" (org-publish-find-date entry project))
              entry
              entry-title))))


;; org-publish always exports the sitemap it just generated, :exclude or not.
;; Both index projects only want the Org file, so they publish nothing.
(defun skw-blog/publish-nothing (_plist _filename _dir)
  "Publish nothing.  Used by projects that only exist to generate a sitemap."
  nil)


;; Latest posts for the homepage. The cap lives here so index.org can include
;; the whole file instead of guessing line numbers.
(defun skw-blog/format-latest-posts (title list)
  "Format the 'skw-blog/latest-posts-count' first entries of 'list' as a
sitemap titled 'title'."
  (let ((entries (seq-take (cdr list) skw-blog/latest-posts-count)))
    (concat "#+TITLE: " title "\n\n"
            (org-list-to-org (cons (car list) entries)))))


;; Same but add the content between the "preview" tags
(defun skw-blog/org-format-blog-post-with-preview (entry style project)
  "Format 'entry' in org-publish 'project' sitemap to include a timestamp
   and preview ('begin/end_preview' tag)."
  (let ((entry-title (org-publish-find-title entry project))
        (preview (skw-blog/get-preview (concat (skw-blog/get-root-directory) "src/posts/" entry)))) ;; dirty
    (if (= (length entry-title) 0)
        (format "*%s*" entry)
      (format "{{{timestamp(%s)}}}: [[file:%s][%s]]\n
%s"
              (format-time-string "%Y-%m-%d" (org-publish-find-date entry project))
              entry
              entry-title
              preview))))


;; The RSS backend derives from HTML, so filters that assume a full document
;; have to rule it out explicitly or they end up rewriting feed items.
(defun skw-blog/html-page-backend-p (backend)
  "Return non-nil when 'backend' exports whole HTML pages rather than feed items."
  (and (org-export-derived-backend-p backend 'html)
       (not (org-export-derived-backend-p backend 'rss))))


;; Headings are linkable but had nothing to click, so sharing a link to one
;; meant reading the id out of the page source.
(defun skw-blog/add-heading-anchor (headline backend info)
  "Append a permalink anchor to the heading that opens 'headline'.
Only headings carrying a CUSTOM_ID get one: Org derives every other id from
a counter that shifts as soon as the document changes, so such a link would
rot silently."
  (if (not (skw-blog/html-page-backend-p backend))
      headline
    (save-match-data
      ;; Children are filtered before their parent, so the first heading tag in
      ;; 'headline' is always the one this call is responsible for.
      (if (not (string-match "<h\\([1-6]\\) id=\"\\([^\"]+\\)\">" headline))
          headline
        (let ((level (match-string 1 headline))
              (id (match-string 2 headline))
              (from (match-end 0)))
          (if (string-match-p "\\`org[0-9a-f]+\\'" id)
              headline
            (let ((close (string-match (concat "</h" level ">") headline from)))
              (if (null close)
                  headline
                (concat (substring headline 0 close)
                        (format (concat "<a class=\"heading-anchor\" href=\"#%s\""
                                        " aria-label=\"Permalink to this section\">#</a>")
                                id)
                        (substring headline close))))))))))

(add-to-list 'org-export-filter-headline-functions
             #'skw-blog/add-heading-anchor)


;; Page metadata. Org emits a title and, given a '#+DESCRIPTION', a description;
;; it emits neither a canonical URL nor any link-preview tag, so a page shared
;; anywhere used to render as a bare URL with no blurb and no image.
(defun skw-blog/page-path (input-file)
  "Return the site-root-relative path at which 'input-file' is served."
  (let* ((relative (file-relative-name (expand-file-name input-file)
                                       skw-blog/srcdir))
         (html (concat (file-name-sans-extension relative) ".html")))
    (cond ((equal html "index.html") "/")
          ((string-suffix-p "/index.html" html)
           (concat "/" (file-name-directory html)))
          (t (concat "/" html)))))


(defun skw-blog/attribute-value (string)
  "Return 'string' escaped for use as an HTML attribute value.
'org-html-encode-plain-text' leaves double quotes alone, which is fine for
text nodes and silently breaks an attribute the first time a title or a
description contains one."
  (replace-regexp-in-string "\"" "&quot;" (org-html-encode-plain-text string) t t))


(defun skw-blog/page-metadata (info)
  "Return the canonical, Open Graph and Twitter tags for the page in 'info'."
  (let* ((input (plist-get info :input-file))
         (path (and input (skw-blog/page-path input)))
         (url (and path (concat skw-blog/upstream-url path)))
         (title (skw-blog/attribute-value
                 (org-element-interpret-data (plist-get info :title))))
         (description (skw-blog/attribute-value
                       (or (org-string-nw-p (plist-get info :description))
                           skw-blog/rss-description)))
         ;; Posts and notes are articles; the homepage and the standing pages
         ;; around them are not.
         (type (if (and path (string-match-p "\\`/\\(posts\\|notes\\)/." path))
                   "article"
                 "website"))
         (tags '()))
    (when url
      (push (format "<link rel=\"canonical\" href=\"%s\">" url) tags)
      (push (format "<meta property=\"og:url\" content=\"%s\">" url) tags))
    (push (format "<meta property=\"og:type\" content=\"%s\">" type) tags)
    (push (format "<meta property=\"og:site_name\" content=\"%s\">"
                  (skw-blog/attribute-value skw-blog/site-name))
          tags)
    (push (format "<meta property=\"og:title\" content=\"%s\">" title) tags)
    (push (format "<meta property=\"og:description\" content=\"%s\">" description) tags)
    (push (format "<meta property=\"og:image\" content=\"%s\">" skw-blog/og-image) tags)
    (push "<meta name=\"twitter:card\" content=\"summary\">" tags)
    ;; The 404 is served for every unknown path. Indexing it would scatter
    ;; "No such file or directory" across search results.
    (when (and input (equal (file-name-nondirectory input) "404.org"))
      (push "<meta name=\"robots\" content=\"noindex\">" tags))
    (concat (mapconcat #'identity (nreverse tags) "\n") "\n")))


(defun skw-blog/insert-page-metadata (output backend info)
  "Insert the tags built by 'skw-blog/page-metadata' into 'output's head."
  (if (not (skw-blog/html-page-backend-p backend))
      output
    (save-match-data
      (if (not (string-match "</head>" output))
          output
        (replace-match (concat (skw-blog/page-metadata info) "</head>")
                       t t output)))))

(add-to-list 'org-export-filter-final-output-functions
             #'skw-blog/insert-page-metadata)


;; Wide tables used to drag the whole page sideways. Now only the table scrolls.
(defun skw-blog/wrap-table-in-scroll-container (table backend info)
  "Wrap an exported HTML 'table' in a horizontally scrollable container."
  (if (org-export-derived-backend-p backend 'html)
      (format "<div class=\"table-scroll\" tabindex=\"0\">\n%s</div>\n" table)
    table))

(add-to-list 'org-export-filter-table-functions
             #'skw-blog/wrap-table-in-scroll-container)


;; Exporting macros
(setq org-export-global-macros
      '(("timestamp" . "@@html:<span class=\"timestamp\">$1</span>@@")
        ("toc" . "*$1*\n#+TOC: headlines $2 local")))


;; RSS feed generation
(defun skw-blog/publish-to-rss (plist filename dir)
  "Publish 'plist' when 'filename' corresponds to RSS feed Org-file to 'dir'."
  (if (equal skw-blog/rss-filename (file-name-nondirectory filename))
      ;; Not `org-rss-publish-to-rss': it stamps a random :ID: on every headline
      ;; of rss.org and writes it back, so a plain "make all" dirties the source
      ;; tree for nothing -- <guid> is the permalink here anyway.
      (org-publish-org-to 'rss filename
                          (concat "." (or (plist-get plist :rss-extension)
                                          org-rss-extension))
                          plist dir)))

(defun skw-blog/format-rss-feed (title list)
  "Generate a sitemap of posts that will be exported as a RSS feed. 'title' is
title of the RSS feed and 'list' the files to be included."
  (concat "#+TITLE: " title "\n\n" (org-list-to-subtree list)))

(defun skw-blog/format-rss-feed-entry (entry style project)
  "Format 'entry' for the posts RSS feed in given 'project'."
  (let* ((title (org-publish-find-title entry project))
         (link (concat (file-name-sans-extension entry) ".html"))
         (pubdate (format-time-string (car org-time-stamp-formats)
                                      (org-publish-find-date entry project)))
         (preview (skw-blog/get-preview (concat (skw-blog/get-root-directory) "src/posts/" entry))))

    (format "%s
:properties:
:rss_permalink: %s
:pubdate: %s
:end:
%s" title link pubdate preview)))


;; robots.txt and sitemap.xml. Org publishes neither, so crawlers had no
;; machine-readable index of the site and no pointer to the feed.
(defun skw-blog/page-date (file)
  "Return the date to advertise for 'file', as a YYYY-MM-DD string.
Prefer the '#+DATE' keyword and fall back to the modification time, which is
what the pages carrying no date of their own -- the notes -- end up using."
  (or (with-temp-buffer
        (insert-file-contents file)
        (goto-char (point-min))
        (when (re-search-forward
               "^#\\+DATE:[ \t]*[<[]\\([0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}\\)"
               nil t)
          (match-string 1)))
      (format-time-string "%Y-%m-%d"
                          (file-attribute-modification-time
                           (file-attributes file)))))


(defun skw-blog/listed-pages ()
  "Return the source files of every page that belongs in a sitemap."
  (sort (seq-remove
         (lambda (file)
           (member (file-name-nondirectory file) skw-blog/unlisted-pages))
         (directory-files-recursively skw-blog/srcdir "\\.org\\'"))
        #'string<))


(defun skw-blog/generate-seo-files (project-plist)
  "Write robots.txt and sitemap.xml at the root of the published site."
  (let ((outdir (plist-get project-plist :publishing-directory)))
    (with-temp-file (expand-file-name "sitemap.xml" outdir)
      (insert "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
              "<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">\n")
      (dolist (file (skw-blog/listed-pages))
        (insert (format "  <url>\n    <loc>%s%s</loc>\n    <lastmod>%s</lastmod>\n  </url>\n"
                        skw-blog/upstream-url
                        (skw-blog/page-path file)
                        (skw-blog/page-date file))))
      (insert "</urlset>\n"))
    (with-temp-file (expand-file-name "robots.txt" outdir)
      (insert "User-agent: *\n"
              "Allow: /\n"
              "\n"
              "Sitemap: " skw-blog/upstream-url "/sitemap.xml\n"))))


;; Generated index pages have no source file to carry a '#+DESCRIPTION', yet
;; they still need a blurb for search results and link previews.
(defun skw-blog/with-description (org description)
  "Insert a '#+DESCRIPTION' keyword for 'description' into generated 'org'."
  (replace-regexp-in-string "\\`\\(#\\+TITLE:.*\n\\)"
                            (concat "\\1#+DESCRIPTION: " description "\n")
                            org t))


(defun skw-blog/format-main-sitemap (title list)
  "Format the site-wide sitemap, leaving the 404 page out of 'list'.
That page answers every unknown path, so listing it as a destination of its
own only invites visitors and crawlers to walk into it."
  (skw-blog/with-description
   (replace-regexp-in-string
    "^[ \t]*-[ \t]*\\[\\[file:404\\.org\\]\\[[^]]*\\]\\][ \t]*\n" ""
    (org-publish-sitemap-default title list))
   "Every page on this website, in one list."))


(defun skw-blog/format-posts-index (title list)
  "Format the full post listing named 'title' from 'list'."
  (skw-blog/with-description
   (org-publish-sitemap-default title list)
   skw-blog/rss-description))


;; Publishing rules
(setq org-publish-project-alist
      `(
        ;; Main Org-mode sources
        ("website-src"
         :auto-sitemap t
         :base-directory ,skw-blog/srcdir
         :base-extension "org"
         :exclude ,(regexp-opt '("rss.org" "index-no-preview.org"))
         :html-head ,(concat skw-blog/main-css skw-blog/favicon skw-blog/rss-link)
         :html-postamble ,skw-blog/footer
         :html-preamble skw-blog/html-preamble
         :publishing-directory ,skw-blog/outdir
         :publishing-function org-html-publish-to-html
         :recursive t
         :sitemap-function skw-blog/format-main-sitemap
         :sitemap-title ,skw-blog/main-sitemap-title
         :completion-function skw-blog/generate-seo-files)

        ;; Bare list of recent posts, included by the homepage. Never a page of its own.
        ("website-posts-index"
         :auto-sitemap t
         :base-directory ,(concat skw-blog/srcdir "posts")
         :base-extension "org"
         :exclude ,(regexp-opt '("rss.org" "index.org" "index-no-preview.org"))
         :publishing-directory ,(concat skw-blog/outdir "posts")
         :publishing-function skw-blog/publish-nothing
         :sitemap-filename "index-no-preview.org"
         :sitemap-format-entry skw-blog/org-format-blog-post
         :sitemap-function skw-blog/format-latest-posts
         :sitemap-sort-files anti-chronologically
         :sitemap-title "Latest posts")

        ;; Full post list with previews. website-src is what turns it into a page.
        ("website-posts-index-preview"
         :auto-sitemap t
         :base-directory ,(concat skw-blog/srcdir "posts")
         :base-extension "org"
         :exclude ,(regexp-opt '("rss.org" "index.org" "index-no-preview.org"))
         :publishing-directory ,(concat skw-blog/outdir "posts")
         :publishing-function skw-blog/publish-nothing
         :sitemap-filename "index.org"
         :sitemap-format-entry skw-blog/org-format-blog-post-with-preview
         :sitemap-function skw-blog/format-posts-index
         :sitemap-sort-files anti-chronologically
         :sitemap-title "Posts")

        ;; RSS feed
        ("website-rss"
         :author ,skw-blog/author
         :auto-sitemap t
         :base-directory ,(concat skw-blog/srcdir "posts")
         :base-extension "org"
         :description ,skw-blog/rss-description
         :email ,skw-blog/email
         :exclude ,(regexp-opt '("rss.org" "index.org" "index-no-preview.org"))
         :html-link-home ,(concat skw-blog/upstream-url "/posts/")
         :html-link-org-files-as-html t
         :html-link-use-abs-url t
         :publishing-directory ,skw-blog/outdir
         :publishing-function skw-blog/publish-to-rss
         :recursive nil
         :rss-extension "xml"
         :rss-feed-url ,(concat skw-blog/upstream-url "/rss.xml")
         :rss-image-url ,(concat skw-blog/upstream-url "/static/img/profile.jpg")
         :sitemap-filename ,skw-blog/rss-filename
         :sitemap-format-entry skw-blog/format-rss-feed-entry
         :sitemap-function skw-blog/format-rss-feed
         :sitemap-sort-files anti-chronologically
         :sitemap-title ,skw-blog/rss-feedname
         :with-author t)

        ;; Attachment files
        ("website-files"
         :base-directory ,skw-blog/srcdir
         :base-extension "css\\|txt\\|jpg\\|gif\\|png"
         :publishing-directory ,skw-blog/outdir
         :publishing-function org-publish-attachment
         :recursive t)

        ;; Static files
        ("website-static"
         :base-directory ,(concat skw-blog/rootdir "static")
         :base-extension ".*"
         :exclude "*.org"
         :publishing-directory ,(concat skw-blog/outdir "static")
         :publishing-function org-publish-attachment
         :recursive t)

        ;; Indexes first: website-src exports the homepage that includes their output.
        ;; Swap the order and every new post lands on the homepage one build late.
        ("website" :components
         ("website-posts-index" "website-posts-index-preview" "website-src" "website-rss" "website-files" "website-static"))))


(provide 'publish-website)
