FROM jruby:9
COPY ./killbill-stripe-demo /stripe-demo  
WORKDIR /stripe-demo  
RUN gem install bundler
RUN bundle install
CMD ["ruby", "-v"]
CMD ruby app.rb -p 4567  -o 0.0.0.0 PUBLISHABLE_KEY=<key>
EXPOSE 4567