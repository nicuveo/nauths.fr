# include

-include dev/config



# configuration

PREPROD_CMD =						\
open '$(PREPROD_HOST)';					\
user '$(PREPROD_USER)';                     		\
mirror -Renpv _site '$(PREPROD_DIR)';			\
put dev/dev_robots.txt -o '$(PREPROD_DIR)/robots.txt';  \
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
	jekyll serve -w

stop:
	killall -9 jekyll

preprod:
	@lftp -c "$(PREPROD_CMD)"

prod:
	@lftp -c "$(PROD_CMD)"
