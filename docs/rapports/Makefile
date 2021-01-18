PANDOC = pandoc
PANDOC-TEMPLATE = template.latex
PANDOC-FLAGS = --template $(PANDOC-TEMPLATE) --listings --pdf-engine=xelatex -V geometry:a4paper -V geometry:margin=2cm
PANDOC-BEAMER-FLAGS = --template $(PANDOC-TEMPLATE) --listings --slide-level 2 --pdf-engine=xelatex

XELATEX = xelatex
BIBTEX = bibtex

REPORT_SRC = report.md
REPORT_PDF = report.pdf

PRESENTATION_SRC = slides.md
PRESENTATION_PDF = presentation.pdf

ARTIFACTS_DIR = artifacts

all: report presentation
clean:
	rm -rf $(ARTIFACTS_DIR)

mk_artifacts_dir:
	mkdir -p $(ARTIFACTS_DIR)

report: mk_artifacts_dir $(ARTIFACTS_DIR)/$(REPORT_PDF)
presentation: mk_artifacts_dir $(ARTIFACTS_DIR)/$(PRESENTATION_PDF)

$(ARTIFACTS_DIR)/$(REPORT_PDF): $(REPORT_SRC)
	$(PANDOC) $(REPORT_SRC) $(PANDOC-FLAGS) -o $@

$(ARTIFACTS_DIR)/$(PRESENTATION_PDF): $(PRESENTATION_SRC)
	$(PANDOC) -t beamer $(PRESENTATION_SRC) $(PANDOC-BEAMER-FLAGS) -o $@
