# usage

define USAGE
Available commands:

    help            display this help
    serve           run jekyll locally
    check           run tests
    build-staging   builds the staging version of the site
    build-release   builds the release version of the site
    staging         builds and push to staging.nauths.fr
    release         builds and push to nauths.fr
endef

export USAGE


# include

-include dev/config


# configuration

STAGING_CMD =                                         \
open $(STAGING_HOST);                                 \
user $(STAGING_USER) $(STAGING_PWD);                  \
mkdir -f $(STAGING_DIR);                              \
mirror -Renpv _site $(STAGING_DIR);                   \
put dev/dev_htaccess -o $(STAGING_DIR)/.htaccess;     \
put dev/dev_robots.txt -o $(STAGING_DIR)/robots.txt;  \
bye

RELEASE_CMD =                         \
open $(RELEASE_HOST);                 \
user $(RELEASE_USER) $(RELEASE_PWD);  \
mkdir -f $(RELEASE_DIR);              \
mirror -Renpv _site $(RELEASE_DIR);   \
bye


# rules

help:
	@echo "$$USAGE"

build-staging:
	bundle exec jekyll build --config _config.yml,_config_staging.yml

build-release:
	bundle exec jekyll build --config _config.yml,_config_release.yml

serve:
	bundle exec jekyll serve --drafts -wD -d _debug

check: build-release
	bundle exec htmlproofer \
	  --ignore-urls="/fonts.googleapis.com/,/fonts.gstatic.com/,http://jackkelly.name" \
	  --only-4xx \
	  ./_site

staging: build-staging
	@lftp -c "$(STAGING_CMD)"

release: build-release
	@lftp -c "$(RELEASE_CMD)"

.PHONY: help build-staging build-release serve check staging release
