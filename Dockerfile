FROM jruby:9
COPY ./killbill-stripe-demo /stripe-demo  
# COPY . /stripe-demo
WORKDIR /stripe-demo  
RUN rm -f Gemfile.lock
RUN gem install bundler
RUN bundle install
CMD ruby app.rb -p 4567  -o 0.0.0.0
EXPOSE 4567