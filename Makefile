OUT_DIR='www'
# Must stay in sync with org-html-mathjax-options in $(PUBLISH_FILE), which
# loads MathJax from /static/js/mathjax/.
MATHJAX_DIR='static/js/mathjax'
PUBLISH_FILE='publish-website.el'
PUBLISH_FUNC='(org-publish "website")'
WS_CMD=python -m http.server 12345 --bind localhost --directory $(OUT_DIR)


all:
	rm -rf .cache www
	emacs -Q --batch --load $(PUBLISH_FILE) --eval $(PUBLISH_FUNC)
	rm -rf .cache


mathjax:
	rm -rf $(MATHJAX_DIR)
	git clone --depth 1 https://github.com/mathjax/MathJax.git $(MATHJAX_DIR)
	rm -rf $(MATHJAX_DIR)/.git


publish:
	git commit
	git push -u origin main


update:
	make all
	git add .
	git status


run:
	$(WS_CMD)


.PHONY: all mathjax publish update run
