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

(defun skw-blog/get-preview (file)
  "The comments (begin/end_preview) in FILE have to be on their own lines,
   preferably before and after paragraphs."
  (with-temp-buffer
    (message file)
    (insert-file-contents file)
    (goto-char (point-min))
    (let ((beg (+ 1 (re-search-forward "^#\\+begin_preview$")))
          (end (progn (re-search-forward "^#\\+end_preview$")
                      (match-beginning 0))))
      (replace-regexp-in-string "\n" " " (buffer-substring beg end)))))


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

 ;; RSS Feed
 skw-blog/rss-feedname "Skywhi's blog"
 skw-blog/rss-filename "rss.org"
 skw-blog/rss-channel-description "Fuzz all the things"

 ;; Main sitemap
 skw-blog/main-sitemap-title "\"Not all those who wander are lost.\" - J. R. R. Tolkien"

 ;; Stylesheets to include by default
 skw-blog/main-css
 "<link rel=\"stylesheet\" type=\"text/css\" href=\"/files/css/style.css\"/>
<link rel=\"stylesheet\" type=\"text/css\" href=\"/files/css/htmlize.css\"/>
"

 ;; Favicon
 skw-blog/favicon
 "<link rel=\"icon\" href=\"/files/img/favicon.ico\" type=\"image/x-icon\">
"
 )


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

 org-html-mathjax-options '((path "/files/js/mathjax/es5/tex-mml-chtml.js")
                           (scale 1.0) (align "center") (font "mathjax-modern") (overflow "overflow")
                           (tags "ams") (indent "0em") (multlinewidth "85%") (tagindent ".8em")
                           (tagside "right")))


;; Import header and footer from HTML templates
(defvar skw-blog/header
  (skw-blog/get-file-content skw-blog/header-file))


(defvar skw-blog/footer
  (format (skw-blog/get-file-content skw-blog/footer-file)
          (format-time-string "%d %b %Y")))

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

(defun skw-blog/org-format-blog-post-with-description (entry style project)
  "Format 'entry' in org-publish 'project' sitemap to include a timestamp
   and description ('begin/end_preview' tag)."
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


;; Exporting macros
(setq org-export-global-macros
      '(("timestamp" . "@@html:<span class=\"timestamp\">$1</span>@@")))


;; RSS feed generation
(defun skw-blog/publish-posts-rss-feed (plist filename dir)
  "Publish 'plist' when 'filename' corresponds to RSS feed Org-file to 'dir'."
  (if (equal skw-blog/rss-filename (file-name-nondirectory filename))
      (org-rss-publish-to-rss plist filename dir)))


(defun skw-blog/posts-rss-feed (title list)
  "Generate a sitemap of posts that will be exported as a RSS feed. 'title' is
title of the RSS feed and 'list' the files to be included."
  (concat "#+TITLE: " title "\n\n" (org-list-to-subtree list)))


(defun skw-blog/format-posts-rss-feed-entry (entry style project)
  "Format 'entry' for the posts RSS feed in given 'project'."
  (let* ((title (org-publish-find-title entry project))
         (link (concat (file-name-sans-extension entry) ".html"))
         (pubdate (format-time-string (car org-time-stamp-formats)
                                      (org-publish-find-date entry project))))

    (format "%s
:properties:
:rss_permalink: %s
:pubdate: %s
:end:" title link pubdate)))


;; Publishing rules
(setq org-publish-project-alist
      `(
        ("website" :components
         ("website-posts-index" "website-posts-index-description" "website-posts-rss" "website-files" "website-src"))

        ;; Main Org-mode sources
        ("website-src"
         :base-directory ,skw-blog/srcdir
         :base-extension "org"
         :exclude ,(regexp-opt (list "posts/" "rss.org"))

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
         :publishing-directory ,(concat skw-blog/outdir "posts")
         :exclude "rss.org\\|index.org\\|index-no-description.org"

         :auto-sitemap t
         :sitemap-title "Posts"
         :sitemap-filename "index-no-description.org"
         :sitemap-format-entry skw-blog/org-format-blog-post
         :sitemap-sort-files anti-chronologically

         :html-preamble ,skw-blog/header
         :html-postamble ,skw-blog/footer
         :html-head ,(concat skw-blog/main-css skw-blog/favicon))

        ;; Index of all blog posts with description
        ("website-posts-index-description"
         :base-directory ,(concat skw-blog/srcdir "posts")
         :base-extension "org"
         :publishing-directory ,(concat skw-blog/outdir "posts")
         :exclude "rss.org\\|index.org\\|index-no-description.org"

         :auto-sitemap t
         :sitemap-title "Posts"
         :sitemap-filename "index.org"
         :sitemap-format-entry skw-blog/org-format-blog-post-with-description
         :sitemap-sort-files anti-chronologically

         :html-preamble ,skw-blog/header
         :html-postamble ,skw-blog/footer
         :html-head ,(concat skw-blog/main-css skw-blog/favicon))

        ;; RSS feed
        ("website-posts-rss"
         :base-directory ,(concat skw-blog/srcdir "posts")
         :base-extension "org"
         :publishing-directory ,skw-blog/outdir
         :exclude "rss.org\\|index.org\\|index-no-description.org"
         :publishing-function skw-blog/publish-posts-rss-feed
         :rss-extension "xml"

         :rss-image-url ,(concat skw-blog/upstream-url "/files/img/profile.jpg")
         :html-link-home ,(concat skw-blog/upstream-url "/posts/")
         :html-link-use-abs-url t
         :html-link-org-files-as-html t

         :author ,skw-blog/author
         :with-author t
         :email ,skw-blog/email
         :description ,skw-blog/rss-channel-description

         :auto-sitemap t
         :sitemap-function skw-blog/posts-rss-feed
         :sitemap-title ,skw-blog/rss-feedname
         :sitemap-filename ,skw-blog/rss-filename
         :sitemap-style list
         :sitemap-sort-files anti-chronologically
         :sitemap-format-entry skw-blog/format-posts-rss-feed-entry)

        ;; Attachment files
        ("website-files"
         :base-directory ,(concat skw-blog/rootdir "files")
         :base-extension ".*"
         :recursive t
         :publishing-directory ,(concat skw-blog/outdir "files")
         :publishing-function org-publish-attachment)))


(provide 'publish-website)
