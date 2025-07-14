OUT_DIR='www'
PUBLISH_FILE='publish-website.el'
PUBLISH_FUNC='(org-publish "website")'
WS_CMD=python -m http.server 12345 --bind localhost --directory $(OUT_DIR)

all:
	rm -rf .cache www
	emacs -Q --batch --load $(PUBLISH_FILE) --eval $(PUBLISH_FUNC)
	rm -rf .cache

mathjax:
	rm -rf files/js/mathjax
	git clone https://github.com/mathjax/MathJax.git files/js/mathjax
	rm -rf files/js/mathjax/.git

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
