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
 )

(defvar skw-blog/header
  (skw-blog/get-file-content skw-blog/header-file))

(defvar skw-blog/footer
  (skw-blog/get-file-content skw-blog/footer-file))


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

 org-html-doctype "html5"
 org-html-head nil
 org-html-head-include-default-style nil
 org-html-head-include-scripts nil
 org-html-html5-fancy nil
 org-html-htmlize-output-type 'css

 org-html-table-use-header-tags-for-first-column nil

 org-html-mathjax-options '((path "/static/js/mathjax/es5/tex-mml-chtml.js")
                            (scale 1.0) (align "center") (font "mathjax-modern") (overflow "overflow")
                            (tags "ams") (indent "0em") (multlinewidth "85%") (tagindent ".8em")
                            (tagside "right")))


;; Preview block
(defun skw-blog/get-preview (file)
  "Extract the content between #+begin_preview and #+end_preview blocks
   in 'file'. The block tags have to be on their own lines, preferably
   before and after paragraphs."
  (with-temp-buffer
    (message file)
    (insert-file-contents file)
    (goto-char (point-min))
    (let ((beg (+ 1 (re-search-forward "^#\\+begin_preview$")))
          (end (progn (re-search-forward "^#\\+end_preview$")
                      (match-beginning 0))))
      (replace-regexp-in-string "\n" " " (buffer-substring beg end)))))


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


;; Same but add the content between the "preview" tags
(defun skw-blog/org-format-blog-post-with-preview (entry style project)
  "Format 'entry' in org-publish 'project' sitemap to include a timestamp
   and preview ('begin/end_preview' tag)."
  (let ((entry-title (org-publish-find-title entry project))
        (preview (skw-blog/get-preview (concat (skw-blog/get-root-directory) "src/posts/" entry)))) ;; dirty
    (if (= (length entry-title) 0)
        (format "*%s*" entry)
      (format "{{{timestamp(%s)}}}: [[file:%s][%s]]\n
%s {{{br}}}"
              (format-time-string "%Y-%m-%d" (org-publish-find-date entry project))
              entry
              entry-title
              preview))))


;; Exporting macros
(setq org-export-global-macros
      '(("timestamp" . "@@html:<span class=\"timestamp\">$1</span>@@")
        ("br" . "@@html:</br></br>@@")))


;; RSS feed generation
(defun skw-blog/publish-to-rss (plist filename dir)
  "Publish 'plist' when 'filename' corresponds to RSS feed Org-file to 'dir'."
  (if (equal skw-blog/rss-filename (file-name-nondirectory filename))
      (org-rss-publish-to-rss plist filename dir)))

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


(setq org-safe-remote-resources '("https://raw.githubusercontent.com/fniessen/org-html-themes/master/org/theme-readtheorg.setup"))

;; Publishing rules
(setq org-publish-project-alist
      `(
        ;; Main Org-mode sources
        ("website-src"
         :base-directory ,skw-blog/srcdir
         :base-extension "org"
         :exclude ,(regexp-opt '("rss.org" "index-no-preview.org"))

         :recursive t
         :publishing-directory ,skw-blog/outdir
         :publishing-function org-html-publish-to-html

         :auto-sitemap t
         :sitemap-title ,skw-blog/main-sitemap-title

         :html-preamble ,skw-blog/header
         :html-postamble ,skw-blog/footer
         :html-head ,(concat skw-blog/main-css skw-blog/favicon))

        ;; Index of all blog posts
        ("website-posts-index"
         :base-directory ,(concat skw-blog/srcdir "posts")
         :base-extension "org"
         :exclude ,(regexp-opt '("rss.org" "index.org" "index-no-preview.org"))
         :publishing-directory ,(concat skw-blog/outdir "posts")

         :html-preamble ,skw-blog/header
         :html-postamble ,skw-blog/footer
         :html-head ,(concat skw-blog/main-css skw-blog/favicon)

         :auto-sitemap t
         :sitemap-title "Posts (without preview)"
         :sitemap-filename "index-no-preview.org"
         :sitemap-format-entry skw-blog/org-format-blog-post
         :sitemap-sort-files anti-chronologically)

        ;; Index of all blog posts with preview
        ("website-posts-index-preview"
         :base-directory ,(concat skw-blog/srcdir "posts")
         :base-extension "org"
         :exclude ,(regexp-opt '("rss.org" "index.org" "index-no-preview.org"))
         :publishing-directory ,(concat skw-blog/outdir "posts")

         :html-preamble ,skw-blog/header
         :html-postamble ,skw-blog/footer
         :html-head ,(concat skw-blog/main-css skw-blog/favicon)

         :auto-sitemap t
         :sitemap-title "Posts"
         :sitemap-filename "index.org"
         :sitemap-format-entry skw-blog/org-format-blog-post-with-preview
         :sitemap-sort-files anti-chronologically)

        ;; RSS feed
        ("website-rss"
         :base-directory ,(concat skw-blog/srcdir "posts")
         :base-extension "org"
         :recursive nil
         :exclude ,(regexp-opt '("rss.org" "index.org" "index-no-preview.org"))
         :publishing-directory ,skw-blog/outdir
         :publishing-function skw-blog/publish-to-rss

         :with-author t
         :author ,skw-blog/author
         :email ,skw-blog/email

         :rss-extension "xml"
         :rss-image-url ,(concat skw-blog/upstream-url "/static/img/profile.jpg")
         :html-link-home ,(concat skw-blog/upstream-url "/posts/")
         :html-link-use-abs-url t
         :html-link-org-files-as-html t

         :auto-sitemap t
         :sitemap-filename ,skw-blog/rss-filename
         :sitemap-title ,skw-blog/rss-feedname
         :sitemap-sort-files anti-chronologically
         :sitemap-function skw-blog/format-rss-feed
         :sitemap-format-entry skw-blog/format-rss-feed-entry)

        ;; Attachment files
        ("website-files"
         :base-directory ,skw-blog/srcdir
         :base-extension "css\\|txt\\|jpg\\|gif\\|png"
         :recursive t
         :publishing-directory ,skw-blog/outdir
         :publishing-function org-publish-attachment)

        ;; Static files
        ("website-static"
         :base-directory ,(concat skw-blog/rootdir "static")
         :base-extension ".*"
         :exclude "*.org"
         :recursive t
         :publishing-directory ,(concat skw-blog/outdir "static")
         :publishing-function org-publish-attachment)

        ("website" :components
         ("website-src" "website-posts-index" "website-posts-index-preview" "website-rss" "website-files" "website-static"))))


(provide 'publish-website)
