FROM ruby:3.3

WORKDIR /usr/src/app

COPY Gemfile activerecord-bulk_update.gemspec ./
RUN bundle install

COPY . .

CMD ["irb"]
