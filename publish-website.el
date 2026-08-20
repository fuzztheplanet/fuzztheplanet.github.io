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

 ;; Location of custom directories and files
 skw-blog/rootdir      (skw-blog/get-root-directory)
 skw-blog/outdir       (concat skw-blog/rootdir "www/")
 skw-blog/srcdir       (concat skw-blog/rootdir "src/")
 skw-blog/header-file  (concat skw-blog/rootdir "templates/header.html")
 skw-blog/footer-file  (concat skw-blog/rootdir "templates/footer.html")

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

 org-html-mathjax-options '((path "/static/js/mathjax/tex-mml-chtml.js")
                            (scale 1.0) (align "center") (font "mathjax-modern") (overflow "overflow")
                            (tags "ams") (indent "0em") (multlinewidth "85%") (tagindent ".8em")
                            (tagside "right")))


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
         :sitemap-title ,skw-blog/main-sitemap-title)

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
