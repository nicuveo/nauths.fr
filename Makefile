# include

-include dev/config


# configuration

PREPROD_CMD =                                           \
open '$(PREPROD_HOST)';                                 \
user '$(PREPROD_USER)';                                 \
mirror -Renpv _site '$(PREPROD_DIR)';                   \
put dev/dev_robots.txt -o '$(PREPROD_DIR)/robots.txt';  \
put dev/dev_htaccess -o '$(PREPROD_DIR)/.htaccess';  \
bye

PROD_CMD =                              \
open '$(PROD_HOST)';                    \
user '$(PROD_USER)';                    \
mirror -Renpv _site '$(PROD_DIR)';      \
bye


# rules

build:
	jekyll build

run:
	jekyll serve --drafts -wD -d _debug

check: build
	htmlproofer --check-html --check-favicon --only-4xx ./_site

preprod: build
	@lftp -c "$(PREPROD_CMD)"

prod: build
	@lftp -c "$(PROD_CMD)"
