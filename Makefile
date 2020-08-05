URL = git@github.com:jcrd/awesome-dovetail

rock:
	luarocks make --local rockspec/awesome-dovetail-devel-1.rockspec

gh-pages:
	git clone -b gh-pages --single-branch $(URL) gh-pages

ldoc: gh-pages
	ldoc . -d gh-pages

serve: gh-pages
	python -m http.server --directory gh-pages

.PHONY: rock ldoc serve
