FROM ruby

WORKDIR /usr/src/app

COPY Gemfile activerecord-bulk_update.gemspec ./
RUN bundle install

COPY . .

CMD ["rake", "test"]
