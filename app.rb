require 'sinatra'
require 'killbill_client'

set :kb_url, ENV['KB_URL'] || 'http://127.0.0.1:8080'
set :publishable_key, ENV['PUBLISHABLE_KEY']

#
# Kill Bill configuration and helpers
#

KillBillClient.url = settings.kb_url
KillBillClient.disable_ssl_verification = true

# Multi-tenancy and RBAC credentials
options = {
    :username => 'admin',
    :password => 'password',
    :api_key => 'bob',
    :api_secret => 'lazar'
}

# Audit log data
user = 'demo'
reason = 'New subscription'
comment = 'Trigger by Sinatra'

def create_kb_account(user, reason, comment, options)
  account = KillBillClient::Model::Account.new
  account.name = 'John Doe'
  account.currency = 'USD'
  account.create(user, reason, comment, options)
end

def create_kb_payment_method(account, session_id, user, reason, comment, options)
  pm = KillBillClient::Model::PaymentMethod.new
  pm.account_id = account.account_id
  pm.plugin_name = 'killbill-stripe'

  prop_session_id = KillBillClient::Model::PluginPropertyAttributes.new
  prop_session_id.key = 'sessionId'
  prop_session_id.value = session_id
  options[:pluginProperty] = [prop_session_id]

  pm.create(true, user, reason, comment, options)
end

def create_subscription(account, user, reason, comment, options)
  subscription = KillBillClient::Model::Subscription.new
  subscription.account_id = account.account_id
  subscription.product_name = 'Sports'
  subscription.product_category = 'BASE'
  subscription.billing_period = 'MONTHLY'
  subscription.price_list = 'DEFAULT'
  subscription.price_overrides = []

  # For the demo to be interesting, override the trial price to be non-zero so we trigger a charge in Stripe
  override_trial = KillBillClient::Model::PhasePriceAttributes.new
  override_trial.phase_type = 'TRIAL'
  override_trial.fixed_price = 10.0
  subscription.price_overrides << override_trial

  subscription.create(user, reason, comment, nil, true, options.clone.merge( { :params => { :callCompletion => true, :callTimeoutSec => 20 } }))
end

def create_session(account, options)
  # Magic template, see https://stripe.com/docs/payments/checkout/fulfillment#webhooks
  success_url = 'http://localhost:4567/charge?kbAccountId=' + @account.account_id + '&sessionId={CHECKOUT_SESSION_ID}'
  response = KillBillClient::API.post '/plugins/killbill-stripe/checkout', nil, { :kbAccountId => account.account_id, :successUrl => success_url }, options
  JSON.parse(response.body)['formFields'].find {|x| x['key'] == 'id'}['value']
end

#
# Sinatra handlers
#

get '/' do
  erb :index
end

post '/checkout' do
  # Create an account
  @account = create_kb_account(user, reason, comment, options)

  # Create the Stripe session
  @session_id = create_session(@account, options)

  erb :checkout
end

get '/charge' do
  account = KillBillClient::Model::Account.find_by_id(params[:kbAccountId], true, true, options)

  # Add a payment method associated with the Stripe token
  create_kb_payment_method(account, params[:sessionId], user, reason, comment, options)

  # Add a subscription
  create_subscription(account, user, reason, comment, options)

  # Retrieve the invoice
  @invoice = account.invoices(options).first

  # And the Stripe authorization
  transaction = @invoice.payments(true, false, 'NONE', options).first.transactions.first
  @authorization = (transaction.properties.find { |p| p.key == 'id' }).value

  erb :charge
end

__END__

@@ layout
  <!DOCTYPE html>
  <html>
  <head></head>
  <body>
    <%= yield %>
  </body>
  </html>

@@index
  <span class="image"><img src="https://drive.google.com/uc?&amp;id=0Bw8rymjWckBHT3dKd0U3a1RfcUE&amp;w=960&amp;h=480" alt="uc?&amp;id=0Bw8rymjWckBHT3dKd0U3a1RfcUE&amp;w=960&amp;h=480"></span>
  <form id="checkout" action="/checkout" method="post">
    <article>
      <label class="amount">
        <span>Sports car, 30 days trial for only $10.00!</span>
      </label>
    </article>
  </form>
  <button type="submit" form="checkout" value="Submit">Buy</button>

@@checkout
  <script src="https://js.stripe.com/v3/"></script>
  <script>
    var stripe = Stripe('<%= settings.publishable_key %>');
    stripe.redirectToCheckout({
      sessionId: '<%= @session_id %>'
    }).then(function (result) {
      alert(result.error.message);
    });
  </script>

@@charge
  <h2>Thanks! Here is your invoice:</h2>
  <ul>
    <% @invoice.items.each do |item| %>
      <li><%= "subscription_id=#{item.subscription_id}, amount=#{item.amount}, phase=sports-monthly-trial, start_date=#{item.start_date}" %></li>
    <% end %>
  </ul>
  You can verify the payment at <a href="<%= "https://dashboard.stripe.com/test/payments/#{@authorization}" %>"><%= "https://dashboard.stripe.com/test/payments/#{@authorization}" %></a>.

