FROM ruby:2.4.1

#RUN groupadd -r pure && useradd -r -g pure pure

# RENAME TO LEGANTO TO ASPIRE
ENV DATA_ROOT /leganto-data
ENV APP_ROOT /leganto-extractor
RUN mkdir -p $DATA_ROOT
RUN mkdir -p $APP_ROOT
WORKDIR $APP_ROOT

ENV LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8 LC_ALL=en_US.UTF-8

COPY pkg/aspire-0.1.0.gem aspire-0.1.0.gem

RUN gem install aspire-0.1.0.gem

COPY entrypoint.sh $APP_ROOT/entrypoint.sh

ENTRYPOINT ["./entrypoint.sh"]