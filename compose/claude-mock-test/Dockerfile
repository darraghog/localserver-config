# Static mock-test app. Content comes from site/, refreshed by sync-site.sh on the
# authoring machine (beeblebox has no node, so the test/check-bank gate runs there).
FROM docker.io/library/nginx:alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY site/ /usr/share/nginx/html/

EXPOSE 80
