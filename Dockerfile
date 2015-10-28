# ubuntu:14.04 -- https://hub.docker.com/_/ubuntu/
# |==> phusion/baseimage:0.9.17 -- https://goo.gl/ZLt61q
#      |==> phusion/passenger-ruby22:0.9.17 -- https://goo.gl/xsnWOP
#           |==> HERE
FROM phusion/passenger-ruby22:0.9.17

ENV APP_HOME=/home/app/pact_broker
RUN rm -f /etc/service/nginx/down
RUN rm /etc/nginx/sites-enabled/default
ADD container /

ADD pact_broker/Gemfile $APP_HOME/
ADD pact_broker/Gemfile.lock $APP_HOME/
RUN chown -R app:app $APP_HOME

USER app
WORKDIR $APP_HOME
RUN bundle install --deployment --without='development test'

USER root
ADD pact_broker/ $APP_HOME/
RUN chown -R app:app $APP_HOME

EXPOSE 443
CMD ["/sbin/my_init"]
