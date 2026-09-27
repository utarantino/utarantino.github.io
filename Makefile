.PHONY: cv cv-tex clean-cv

cv-tex:
	./scripts/generate_cv.rb

cv: cv-tex
	cd cv && latexmk -lualatex -interaction=nonstopmode -halt-on-error cv.tex

clean-cv:
	cd cv && latexmk -C cv.tex