# Static mock-test app. The site is not tracked here: build.sh copies the directory named by
# MOCK_TEST_SITE (staged by deployd's deploy-mock-test from a claude-mock-test release tag)
# to .build/site, and compose.yaml passes that path in as SITE_DIR.
FROM docker.io/library/nginx:alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
# Points at .build/site, which only build.sh creates, so a build without it fails on COPY
# instead of publishing something else.
ARG SITE_DIR=.build/site
COPY ${SITE_DIR}/ /usr/share/nginx/html/

EXPOSE 80
