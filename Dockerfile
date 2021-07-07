FROM jruby:9
# RUN apt-get -y install git
# RUN git clone https://github.com/killbill/killbill-stripe-demo.git
COPY ./killbill-stripe-demo /stripe-demo  
WORKDIR /stripe-demo  
RUN gem install bundler
RUN bundle install
