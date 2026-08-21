OUT_DIR='www'
PUBLISH_FILE='publish-website.el'
PUBLISH_FUNC='(org-publish "website")'
WS_CMD=python -m http.server 12345 --bind localhost --directory $(OUT_DIR)

# MathJax is vendored so the site works offline and makes no third-party
# requests. Upstream ships ~20 MB: several output formats, Node entry points and
# every speech locale, none of which are served here. The 'mathjax' target below
# keeps only what a page actually loads and drops the rest.
#
# MATHJAX_DIR must stay in sync with org-html-mathjax-options in $(PUBLISH_FILE),
# and MATHJAX_FONT with the 'font' entry of that same variable. The font package
# lives under $(MATHJAX_DIR)/fonts/, where the loader path set in $(PUBLISH_FILE)
# expects it -- otherwise MathJax silently falls back to the jsdelivr CDN.
MATHJAX_DIR=static/js/mathjax
MATHJAX_VERSION=4.1.3
MATHJAX_FONT=mathjax-modern
MATHJAX_FONT_VERSION=$(MATHJAX_VERSION)
# Speech locales kept for the screen-reader output. 'base' is mandatory.
MATHJAX_LOCALES=base en
NPM=https://registry.npmjs.org
TMP=$(MATHJAX_DIR).tmp


all:
	rm -rf .cache www
	emacs -Q --batch --load $(PUBLISH_FILE) --eval $(PUBLISH_FUNC)
	rm -rf .cache


mathjax:
	rm -rf $(MATHJAX_DIR) $(TMP)
	mkdir -p $(TMP)/mathjax $(TMP)/font
	curl -fsSL $(NPM)/mathjax/-/mathjax-$(MATHJAX_VERSION).tgz \
	    | tar xz -C $(TMP)/mathjax --strip-components=1
	curl -fsSL $(NPM)/@mathjax/$(MATHJAX_FONT)-font/-/$(MATHJAX_FONT)-font-$(MATHJAX_FONT_VERSION).tgz \
	    | tar xz -C $(TMP)/font --strip-components=1
	mkdir -p $(MATHJAX_DIR)/input/tex $(MATHJAX_DIR)/sre/mathmaps \
	         $(MATHJAX_DIR)/fonts/$(MATHJAX_FONT)-font/chtml
# The combined TeX+MathML -> CommonHTML bundle, the only one referenced.
	cp $(TMP)/mathjax/LICENSE $(TMP)/mathjax/tex-mml-chtml.js $(MATHJAX_DIR)/
# Pulled in on demand by the TeX autoloader (\color, \cancel, \mathtools, ...).
	cp -r $(TMP)/mathjax/input/tex/extensions $(MATHJAX_DIR)/input/tex/
# Speech-rule engine: loaded on every page carrying math, for screen readers.
	cp $(TMP)/mathjax/sre/require.mjs $(TMP)/mathjax/sre/speech-worker.js $(MATHJAX_DIR)/sre/
	for locale in $(MATHJAX_LOCALES); do \
	    cp $(TMP)/mathjax/sre/mathmaps/$$locale.json $(MATHJAX_DIR)/sre/mathmaps/; \
	done
# Fonts. Without these the browser would fetch them from cdn.jsdelivr.net.
	cp $(TMP)/font/package.json $(TMP)/font/chtml.js $(MATHJAX_DIR)/fonts/$(MATHJAX_FONT)-font/
	cp -r $(TMP)/font/chtml/woff2 $(TMP)/font/chtml/dynamic \
	      $(MATHJAX_DIR)/fonts/$(MATHJAX_FONT)-font/chtml/
	rm -rf $(TMP)


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
