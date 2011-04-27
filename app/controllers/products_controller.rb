class ProductsController < ApplicationController
  unloadable
  add_breadcrumb 'Home', 'root_path'
  # require "net/http"
  # require "uri"
  # require "base64"
  require 'httparty'
  # require 'rufus/scheduler'
	before_filter :find_page
  skip_before_filter :verify_authenticity_token, :only => :google_response
  
  def index
    # @products = Product.find(:all, :conditions =>{:active => true})
    # @heading = "Product"
    # add_breadcrumb 'Product'
    redirect_to(product_path(Product.first))
  end

  def show
    begin
      @menu_selected = "products"
      @product = Product.find params[:id], :conditions => { :active => true, :deleted => false }
      @product.menus.empty? ? @menu = @page.menus.first : @menu = @product.menus.first
      @heading = @product.name
      @testimonial = Testimonial.find(:all, :conditions => ["quotable_id = ?" , @product.id]).sort_by(&:rand).first #Select a random testimonial
      add_breadcrumb 'Products', 'products_path'
      if @product.product_categories.any?
        @productcategory = @product.product_categories.first
        @product_category_tmp = []
        build_tree(@productcategory)
        for product_category in @product_category_tmp.reverse
          add_breadcrumb product_category.title, product_category_path(product_category)
        end
			end
			if @product.product_options
			  product_prices = []
		    @product.product_options.each do |po|
		      product_prices << [po.id,po.price,po.sale_price]
		    end 
        @product_price_string = ""
        product_prices.each_with_index do |p, index|
          @product_price_string += "[#{p.join(",")}]#{product_prices.length != index + 1 ? "," : ""}"
        end
		  end
			add_breadcrumb @product.name
    rescue ActiveRecord::RecordNotFound
      flash[:error] = "The product you were looking for was not found."
      redirect_to products_path
    end
  end
  
  def google_post
    if params["product-price"].match(/^[\d]*(\.[\d]{1,2})?$/)
      google_params = { 
        '_type' => 'checkout-shopping-cart', 
        'shopping-cart.items.item-1.item-name' => params['anonymous'] ? params['product-attr-option']+'-anonymous' : params['product-attr-option'], 
        'shopping-cart.items.item-1.item-description' => params['product-title'],
        'shopping-cart.items.item-1.unit-price' => params['product-price'], 
        'shopping-cart.items.item-1.unit-price.currency' => 'USD',
        'shopping-cart.items.item-1.quantity' => '1',
        'shopping-cart.items.item-1.merchant-item-id' =>'UNITYDONATION'
        }
      site_settings = @cms_config["site_settings"]
      google_merchant_id = site_settings['google_merchant_id']
      if site_settings['google_sandbox']
        post_url = "https://sandbox.google.com/checkout/api/checkout/v2/requestForm/Merchant/#{google_merchant_id}"
      else
        post_url = "https://checkout.google.com/api/checkout/v2/requestForm/Merchant/#{google_merchant_id}"
      end

      headers = { 'Content-Type' => 'application/xml;charset=UTF-8', 'Accept' => 'application/xml;charset=UTF-8' }
      options = { :body => google_params, :headers => headers, 
        :basic_auth => {
          :username => @cms_config["site_settings"]["google_merchant_id"],
          :password => @cms_config["site_settings"]["google_merchant_key"]
        } 
      }
      #post_url = "https://#{@cms_config["site_settings"]["google_merchant_id"]}:#{@cms_config["site_settings"]["google_merchant_key"]}@checkout.google.com/api/checkout/v2/request/Merchant/#{@cms_config["site_settings"]["google_merchant_id"]}/diagnose"
      response = HTTParty.post(post_url, options)

      redirect_url = URI.decode(response.parsed_response).strip.gsub(/_type=checkout-redirect&redirect-url=(.{0,}?)\z/,'\1')
      
      # Need to save serial number that comes back from the order and get person info 
      # Person.find_or_create_by_email
      redirect_to(redirect_url)
    else
      flash[:error] = "Please enter a valid donation amount"
      redirect_to(products_path)
    end
  end
  
  def google_response
    if params["serial-number"]
      options = {:body => {"_type" => "notification-history-request", "serial-number" => params["serial-number"]}, :headers => {'Content-Type' => 'application/xml;charset=UTF-8', 'Accept' => 'application/xml;charset=UTF-8'},:basic_auth => {:username =>  @cms_config["site_settings"]["google_merchant_id"],:password => @cms_config["site_settings"]["google_merchant_key"]}}
      base_uri = @cms_config["site_settings"]["google_sandbox"] ? 'https://sandbox.google.com/checkout/api/checkout/v2/reportsForm/Merchant/' : 'https://checkout.google.com/api/checkout/v2/reportsForm/Merchant/'
      response = HTTParty.post(base_uri+"#{@cms_config["site_settings"]["google_merchant_id"]}", options)
      response_hash = CGI.parse(response.parsed_response)
      #If the request is of _type new-order-notification then it has the info we want
      logger.info response_hash["_type"]
      if response_hash["_type"].to_s == "new-order-notification"
        logger.info "Making new person"
        gs = GoogleSerial.create(:serial => params["serial-number"])
        person = Person.find_or_create_by_email(response_hash["buyer-billing-address.email"].to_s)
        logger.info "Person found or created"
        person.first_name = response_hash["buyer-billing-address.contact-name"].to_s.split(" ")[0]
        person.last_name = response_hash["buyer-billing-address.contact-name"].to_s.split(" ")[1]
        person.zip = response_hash["buyer-billing-address.postal-code"].to_s
        person.address1 = response_hash["buyer-billing-address.address1"].to_s
        person.address2 = response_hash["buyer-billing-address.address2"].to_s
        person.city = response_hash["buyer-billing-address.city"].to_s
        person.state = response_hash["buyer-billing-address.state"].to_s
        person.phone = response_hash["buyer-billing-address.phone"].to_s
        person.anonymous = response_hash["shopping-cart.items.item-1.item-name"].to_s.include?("anonymous")
        person.save
        logger.info "Person saved"
        person.google_serial_ids |= [gs]
        groups = [PersonGroup.find_by_title("Donations").id]
        groups << PersonGroup.find_by_title("Newsletter").id if response_hash["buyer-marketing-preferences.email-allowed"]      
        person.person_group_ids |= groups
        person.save
        logger.info "Created person #{person.id}"
      end
    end
  end
  
  def add_to_cart
    begin
      @product = Product.find params[:id], :conditions => { :active => true, :deleted => false }
      find_cart.add_product(@product, 1)
      redirect_to cart_path
    rescue ActiveRecord::RecordNotFound
      flash[:error] = "That product is not available."
      redirect_to products_path
    end
  end

  private

  def find_page
    @footer_pages = Page.find(:all, :conditions => {:show_in_footer => true}, :order => :footer_pos )
    @page = Page.find_by_permalink!('donations')
    @productcategories = ProductCategory.all
    @topproductcategories = ProductCategory.all(:conditions => {:parent_id => nil})
    # @product_category_tmp = []
    #     build_tree(@product_category)
    #     for product_category in @product_category_tmp.reverse
    #       unless product_category == @product_category
    #         add_breadcrumb product_category.title, product_category_path(product_category)
    #       else  
    #         add_breadcrumb product_category.title
    #       end
    #     end
  end

  def find_cart
    session[:cart] ||= Cart.new
  end

  def build_tree(current_product_category)
    @product_category_tmp << current_product_category
    unless current_product_category.parent_id == nil
      parent_product_category = ProductCategory.find_by_id(current_product_category.parent_id)
      build_tree(parent_product_category)
    end
  end

end

