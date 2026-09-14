class CustomersController < ActionController::Base
  layout "application"
  def new
    @heading = "New customer"
  end
end
