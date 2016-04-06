.PHONY: build-moderator build-embed-script build-setup test deploy-static-s3
.SILENT:

brunch_build_opts = 
herokuapp = 
gitbranch = 

ifneq ($(NODE_ENV),)
	for = $(NODE_ENV)
endif

ifeq ($(for),production)
	brunch_build_opts = --production
	herokuapp = burnzone
	gitbranch = master
endif

ifeq ($(for),production_aws)
	brunch_build_opts = --production
endif

ifeq ($(for),staging)
	brunch_build_opts = --production
	herokuapp = burnzonestaging
	gitbranch = dev
endif

ifeq ($(for),)
	for = development
endif

ifeq ($(gitbranch),)
	gitbranch = $(shell git rev-parse --abbrev-ref HEAD)
endif

# using comma as sed delimiter for this
host = $(shell MAKE=1 NODE_ENV=$(for) node server/main.js --config serverHost)
domain = $(shell MAKE=1 NODE_ENV=$(for) node server/main.js --config domain)
loginRoot = $(shell MAKE=1 NODE_ENV=$(for) node server/main.js --config loginRoot)
s3bucket = $(shell MAKE=1 NODE_ENV=$(for) node server/main.js --config aws.bucket)
resourcePath = $(shell MAKE=1 NODE_ENV=$(for) node server/main.js --config resourcePath)
domainAndPort = $(shell MAKE=1 NODE_ENV=$(for) node server/main.js --config domainAndPort)

build-counts:
	cd client/counts/app; \
	sed 's,{{{host}}},$(host),' _counts.coffee > counts.coffee; \
	cd ..; \
	echo "Building comments count script"; \
	node_modules/brunch/bin/brunch build $(brunch_build_opts); \
	cd ../..;

client/common/app/lib/qs.js: client/common/app/lib/_qs.js
	client/node_modules/browserify/bin/cmd.js $^ -s qs > $@

build-embedded: client/common/app/lib/qs.js
	echo "Building files for embedded"; \
	cp -Rf client/common/* client/embedded/; \
	cd client/embedded/app; \
	sed 's,{{{resourcePath}}},$(resourcePath),' stylesheets/bootstrap/_font-awesome.less > stylesheets/bootstrap/font-awesome.less; \
	sed 's,{{{resourcePath}}},$(resourcePath),' stylesheets/_variables.styl > stylesheets/variables.styl; \
	sed 's,{{{resourcePath}}},$(resourcePath),g' stylesheets/_burnzone-fonts.styl > stylesheets/burnzone-fonts.styl; \
	if [ ! -d lib/shared ]; then mkdir -p lib/shared; fi; \
	cd ../../..; \
	cd client/embedded/vendor; \
	sed 's,{{{resourcePath}}},$(resourcePath),' stylesheets/_bootstrap-formhelpers-flags.css > stylesheets/bootstrap-formhelpers-flags.css; \
	cd ../../..; \
	cp -Rf ./shared/* client/embedded/app/lib/shared/
	cd client/embedded; \
	node_modules/brunch/bin/brunch build $(brunch_build_opts); \
	cd ../..;

build-zeus:
	echo "Building files for zeus"; \
	cp -Rf client/common/* client/zeus/; \
	cd client/zeus/app; \
	if [ ! -d lib/shared ]; then mkdir -p lib/shared; fi; \
	cd ../../..; \
	cd client/zeus/vendor; \
	sed 's,{{{resourcePath}}},$(resourcePath),' stylesheets/_bootstrap-formhelpers-flags.css > stylesheets/bootstrap-formhelpers-flags.css; \
	cd ../../..; \
	cp -Rf ./shared/* client/zeus/app/lib/shared/
	cd client/zeus; \
	node_modules/brunch/bin/brunch build $(brunch_build_opts); \
	cd ../..;

build-moderator:
	echo "Building files for moderator"; \
	cp -Rf client/common/app client/moderator; \
	cp -Rf client/common/vendor/stylesheets client/moderator/vendor/; \
	cd client/moderator/app; \
	sed 's,{{{resourcePath}}},$(resourcePath),g' stylesheets/_burnzone-fonts.styl > stylesheets/burnzone-fonts.styl; \
	if [ ! -d lib/shared ]; then mkdir -p lib/shared; fi; \
	cd ../../..; \
	cd client/moderator/vendor; \
	sed 's,{{{resourcePath}}},$(resourcePath),' stylesheets/_bootstrap-formhelpers-flags.css > stylesheets/bootstrap-formhelpers-flags.css; \
	cd ../../..; \
	cp -Rf ./shared/* client/moderator/app/lib/shared/
	cd client/moderator; \
	node_modules/brunch/bin/brunch build $(brunch_build_opts); \
	cd ../..;

build-embed:
	echo "Building files for embed"; \
	cd client/embed/app; \
	sed 's,{{{host}}},$(host),' _embed.coffee > embed.coffee; \
	cd ..; \
	node_modules/brunch/bin/brunch build $(brunch_build_opts); \
	cd ../..;

build-marketing:
	echo "Building files for marketing"; \
	cp -Rf client/common/* client/marketing/; \
	cd client/marketing/app; \
	if [ ! -d lib/shared ]; then mkdir -p lib/shared; fi; \
	cd ../../..; \
	cd client/marketing/vendor; \
	sed 's,{{{resourcePath}}},$(resourcePath),' stylesheets/_bootstrap-formhelpers-flags.css > stylesheets/bootstrap-formhelpers-flags.css; \
	cd ../../..; \
	cp -Rf ./shared/* client/marketing/app/lib/shared/
	cd client/marketing/app/stylesheets; \
	sed 's,{{{resourcePath}}},$(resourcePath),g' _burnzone-fonts.styl > burnzone-fonts.styl; \
	sed 's,{{{resourcePath}}},$(resourcePath),g' _font-awesome.css > font-awesome.css; \
	sed 's,{{{resourcePath}}},$(resourcePath),g' _colorpicker.styl > colorpicker.styl; \
	sed 's,{{{resourcePath}}},$(resourcePath),g' _home.styl > home.styl; \
	cd ../../; \
	node_modules/brunch/bin/brunch build $(brunch_build_opts); \
	cd ../..;

build-blogger-posts:
	echo "Building files for blogger-posts"; \
	cd client/blogger-posts/app; \
	sed 's,{{{host}}},$(host),' _blogger-posts.js > blogger-posts.js; \
	cd ..; \
	node_modules/brunch/bin/brunch build $(brunch_build_opts); \
	cd ../..;	

build-plugin-embed-script-core:
	echo "Building generic plugin script core"; \
	cd plugins/generic/; \
	sed 's,{{{host}}},$(host),' _embed_script_core > embed_script_core; \
	cd ../..;

build-plugin-embed-script:
	echo "Building generic plugin script"; \
	cd plugins/generic/; \
	sed 's,{{{host}}},$(host),' _embed_script > embed_script; \
	cd ../..;

build-plugin-embed-script-typepad:
	echo "Building plugin script Typepad"; \
	cd plugins/generic/; \
	sed 's,{{{host}}},$(host),' _embed_script_typepad > embed_script_typepad; \
	cd ../..;

build-plugin-blogger:
	echo "Building blogger plugin script"; \
	cd plugins/blogger/; \
	sed 's,{{{host}}},$(host),' _widget.xml > widget.xml; \
	cd ../..;

build-plugin-wp: build-plugin-embed-script
	echo "Setting the domain name for login return_to"; \
	cd plugins/wordpress/conversait/; \
	sed -e 's,{{{loginRoot}}},$(loginRoot),' -e 's,{{{host}}},$(host),' -e 's,{{{domain}}},$(domain),' -e 's,{{{resourcePath}}},$(resourcePath),' -e 's,{{{domainAndPort}}},$(domainAndPort),' _options.php > options.php; \
	cd ../../..

build-plugin-vbulletin: build-plugin-embed-script
	echo "Building plugin Vbulletin"; \
	cd plugins/vbulletin/; \
	sed -e 's,{{{loginRoot}}},$(loginRoot),' -e 's,{{{host}}},$(host),' -e 's,{{{domain}}},$(domain),' -e 's,{{{resourcePath}}},$(resourcePath),' -e 's,{{{domainAndPort}}},$(domainAndPort),' _product-burnzone.xml > product-burnzone.xml; \
	cd ../..

archive-wpplugin: build-plugin-wp
	rm -f server/static/plugins/wordpress.zip; \
	if [ ! -d server/static/plugins ]; then mkdir server/static/plugins; fi; \
	cd plugins/wordpress/; \
	find ./conversait -name "[^_]*" -print | zip ../../server/static/plugins/wordpress.zip -@ ;\
	cd ../..

clean-plugin-wp:
	rm -rf server/static/plugins/wordpress.zip

test-embedded: build-embedded
	cd client/embedded; \
	node_modules/brunch/bin/brunch test; \
	cd ../..;\

build-setup:
	echo "Copying shared files to the server directory"; \
	if [ ! -d server/shared ]; then mkdir -p server/shared; fi; \
	cp -Rf shared/* server/shared/; \
	echo "Copying to static directory"; \
	if [ ! -d server/static/img ]; then mkdir server/static/img/; fi; \
	cp -Rf client/embedded/public/img/* server/static/img/; \
	if [ -d client/moderator/public/img/ ]; then cp -Rf client/moderator/public/img/* server/static/img/; fi; \

	if [ ! -d server/static/js ]; then mkdir server/static/js/; fi; \
	cp -Rf client/embedded/public/javascripts/* server/static/js/; \
	cp -Rf client/counts/public/javascripts/* server/static/js/; \
	cp -Rf client/embed/public/javascripts/* server/static/js/; \
	cp -Rf client/moderator/public/javascripts/* server/static/js/; \
	cp -Rf client/blogger-posts/public/javascripts/* server/static/js/; \
	cp -Rf client/marketing/public/javascripts/* server/static/js/; \
	cp -Rf client/zeus/public/javascripts/* server/static/js/; \

	if [ ! -d server/static/css ]; then mkdir server/static/css/; fi; \
	cp -Rf client/embedded/public/stylesheets/* server/static/css/; \
	cp -Rf client/moderator/public/stylesheets/* server/static/css/; \
	cp -Rf client/marketing/public/stylesheets/* server/static/css/; \
	cp -Rf client/zeus/public/stylesheets/* server/static/css/; \

all: build-embedded build-zeus build-moderator build-marketing build-embed build-counts build-blogger-posts build-setup build-plugin-embed-script build-plugin-embed-script-core build-plugin-embed-script-typepad build-plugin-blogger archive-wpplugin build-plugin-vbulletin

invalidate-cdn:
	python ./scripts/Cloudfront-Invalidator/invalidate.py web/js/counts.js web/js/embed.js web/js/blogger-posts.js; \

clean:
	rm -f plugins/blogger/widget.xml*
	rm -f plugins/wordpress/conversait/options.php*
	rm -f plugins/generic/embed_script*
	rm -f server/static/plugins/wordpress.zip*
	rm -f server/static/css/site.css*
	rm -f server/static/css/embedded.css*
	rm -f server/static/css/moderator.css*
	rm -f server/static/js/embedded.js*
	rm -f server/static/js/moderator.js*
	rm -f server/static/js/counts.js*
	rm -f server/static/js/counts-c.js*
	rm -f server/static/js/embed.js*
	rm -f server/static/js/embed-c.js*
	rm -f server/static/js/embedded-vendor.js*
	rm -f server/static/js/moderator-vendor.js*
	rm -f server/static/js/blogger-posts.js*
	rm -f server/static/js/blogger-posts-c.js*
	rm -f server/static/js/site.js*

clean-merge:
	find -L . -name "*.orig" -print | xargs rm -v

deploy-static-s3:
	s3cmd -r --delete-removed --guess-mime-type sync server/static/auth/ s3://$(s3bucket)/web/auth/; \
	s3cmd -m "text/css" -r --delete-removed sync server/static/css/ s3://$(s3bucket)/web/css/; \
	# s3cmd -m "application/octet-stream" --delete-removed --guess-mime-type sync server/static/font/ s3://$(s3bucket)/web/font/

	s3cmd -m "application/x-font-opentype" sync server/static/font/FontAwesome.otf s3://$(s3bucket)/web/font/FontAwesome.otf; \
	s3cmd -m "application/vnd.ms-fontobject" sync server/static/font/fontawesome-webfont.eot s3://$(s3bucket)/web/font/fontawesome-webfont.eot; \
	s3cmd -m "image/svg+xml" sync server/static/font/fontawesome-webfont.svg s3://$(s3bucket)/web/font/fontawesome-webfont.svg; \
	s3cmd -m "application/x-font-ttf" sync server/static/font/fontawesome-webfont.ttf s3://$(s3bucket)/web/font/fontawesome-webfont.ttf; \
	s3cmd -m "application/x-font-woff" sync server/static/font/fontawesome-webfont.woff s3://$(s3bucket)/web/font/fontawesome-webfont.woff; \

	s3cmd -r --delete-removed --guess-mime-type sync server/static/img/ s3://$(s3bucket)/web/img/; \
	s3cmd -r --delete-removed --guess-mime-type sync server/static/js/ s3://$(s3bucket)/web/js/; \
	s3cmd -r --delete-removed --guess-mime-type sync server/static/plugins/ s3://$(s3bucket)/web/plugins/; \
	s3cmd -r --delete-removed --guess-mime-type sync server/static/w3c/ s3://$(s3bucket)/web/w3c/; \

deploy: all
	git branch -D deploy; \
	git checkout -b deploy; \
	git add .; \
	git commit -m "assets"; \
	git push $(for) deploy:master; \

test_port = 27018
test:
	if [ ! -d /dev/shm/mongo_test ]; then mkdir /dev/shm/mongo_test; fi; \
	if [ ! -h ./test_data ]; then ln -sf -T /dev/shm/mongo_test ./test_data; fi; \
	if [ ! -d ./pid ]; then mkdir pid; fi; \
	mongod --quiet --port $(test_port) --dbpath ./test_data/ > /dev/null & echo "$$!" > ./pid/mongo_test.pid; \
	cd server; \
	export NODE_ENV=test && ../node_modules/mocha/bin/mocha; \
	cd ..; \
	./kill_mongo_test.sh ; \
	rm -rf ./test_data/*; \

test-debug:
	@cd server; \
	export NODE_ENV=test && ../node_modules/mocha/bin/mocha debug; \
	cd ..; \

initial-client:
	cd client/embedded && npm install && cd ../..; \
	cd client/moderator && npm install && cd ../..; \
	cd client/embed && npm install && cd ../..; \
	cd client/counts && npm install && cd ../..; \
	cd client/blogger-posts && npm install && cd ../..; \

initial: initial-client
	npm install
