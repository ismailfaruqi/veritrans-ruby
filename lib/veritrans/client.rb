# :nodoc:
module Veritrans

  # :nodoc:
  class Client
    include Config

    # constructor to create instance of Veritrans::Client
    def initialize(&block)
      class <<self
        self
      end.class_eval do
        attr_accessor(:commodity, *PostData::PostParam) 
      end
      
      # return-back to merchant-web
      self.customer_specification_flag = Config::CUSTOMER_SPECIFICATION_FLAG 
      self.settlement_type             = Config::SETTLEMENT_TYPE_CARD

      # if block_given?
      #   yield(self) #self.instance_eval(&block)
      #   return self.get_keys
      # end
    end

    #
    # Example:
    #
    #   client = Veritrans::Client.new
    #   client.order_id     = "dummy#{(0...12).map{65.+(rand(25))}.join}"
    #   client.session_id   = "session#{(0...12).map{65.+(rand(25))}.join}"
    #   client.gross_amount = "10"
    #   client.commodity    = [{
    #     "COMMODITY_ID"    => "IDxx1", 
    #     "COMMODITY_UNIT"  => "10",
    #     "COMMODITY_NUM"   => "1",
    #     "COMMODITY_NAME1" => "Waterbotle",
    #     "COMMODITY_NAME2" => "Waterbottle in Indonesian"}]
    #   client.get_keys
    #
    def get_keys
      init_instance
      
      if customer_specification_flag == "0" && shipping_flag == "0"
        raise "required_shipping_address must be '1'"
      end

      params = prepare_params(PostData::ServerParam,PostData::PostParam)

      if !params[:promo_bins].blank?
        params.merge!({ "promo_bins[]" => params[:promo_bins]})
        params.delete :promo_bins
      end

      if !params[:point_banks].blank?
        params.merge!({ "point_banks[]" => params[:point_banks]})
        params.delete :point_banks
      end

      if !params[:installment_banks].blank?
        params.merge!({ "installment_banks[]" => params[:installment_banks]})
        params.delete :installment_banks
      end

      if !params[:installment_terms].blank?
        params.merge!({ "installment_terms" => params[:installment_terms].to_json })
        params.delete :installment_terms
      end
      
      if !params[:payment_methods].blank?
        params.merge!({ "payment_methods[]" => params[:payment_methods]})
        params.delete :payment_methods
      end
      
      commodity = @commodity.collect do |data|
        data.keys.map do |key|
          if key.downcase == "commodity_id"
            data["item_id[]"] = data[key]            
          end
          
          if key.downcase == "commodity_unit"
            data["price[]"] = data[key]
          end

          if key.downcase == "commodity_num"
            data["quantity[]"] = data[key]
          end

          if key.downcase == "commodity_name1"
            data["item_name1[]"] = data[key]
          end

          if key.downcase == "commodity_name2"
            data["item_name2[]"] = data[key]
          end

          data.delete key
        end        

        # construct commodity
        orders_uri = Addressable::URI.new
        orders_uri.query_values = data
        # return list of commodity as query string format
        orders_uri.query
      end

      uri = Addressable::URI.new
      uri.query_values = params
      query_string = "#{uri.query}&repeat_line=#{commodity.length}&#{commodity.join('&')}"
    
      conn = Faraday.new(:url => server_host)
      @resp = conn.post do |req|
        req.url(Config::REQUEST_KEY_URL)
        req.body = query_string
      end.env
      
      delete_keys
      @resp[:url] = @resp[:url].to_s

      if version.to_i == 1
        @token = JSON.parse(@resp[:body])
      else        
        @token = parse_body(@resp[:body])
      end
    end

    # :nodoc:
    def server_host
      return Client.config["server_host"] ? Client.config["server_host"] : Config::SERVER_HOST
    end

    def redirect_url
      "#{server_host}/web1/paymentStart.action"
    end

    # :nodoc:
    def merchant_id
      return Client.config["merchant_id"]
    end

    # :nodoc:
    def merchant_id= new_merchant_id
      Client.config["merchant_id"] = new_merchant_id
    end

    # :nodoc:
    def merchant_hash_key
      return Client.config["merchant_hash_key"]
    end

    # :nodoc:
    def merchant_hash_key= new_merchant_hash_key
      Client.config["merchant_hash_key"] = new_merchant_hash_key
    end

    # :nodoc:
    def error_payment_return_url
      return Client.config["error_payment_return_url"]
    end

    # :nodoc:
    def finish_payment_return_url
      return Client.config["finish_payment_return_url"]
    end

    # :nodoc:
    def unfinish_payment_return_url
      return Client.config["unfinish_payment_return_url"]
    end

    # :nodoc:
    def token
      return @token
    end

    # :nodoc:
    def billing_address_different_with_shipping_address
      @customer_specification_flag
    end

    # :nodoc:
    def billing_address_different_with_shipping_address=(flag)
      @customer_specification_flag = customer_specification_flag
    end

    # :nodoc:
    def required_shipping_address
      @shipping_flag
    end

    # :nodoc:
    def required_shipping_address=(flag)
      @shipping_flag = flag
    end

    def new_api
      return true
    end

    private
    # Generate merchant hash code
    def merchanthash
      if version.to_i == 1    
        return HashGenerator::generate(merchant_hash_key, merchant_id, order_id);
      else
        return Digest::SHA512.hexdigest("#{merchant_hash_key},#{merchant_id},01,#{order_id},#{gross_amount}")
      end
    end

    # deprecated
    def parse_body(body)
      arrs = body.split("\r\n")
      arrs = arrs[-2,2] if arrs.length > 1
      return Hash[arrs.collect{|x|x.split("=")}]
    end
  
    def init_instance
      @token = nil
    end

    def prepare_params(*arg)
      params = {}
      # extract keys from post data
      arg.flatten.each do |key|
        # retrieve value from client configuration
        value = self.send(key)
        params[key.downcase] = value if value 
      end
      return params
    end

    def delete_keys
      @resp.delete(:ssl)
      @resp.delete(:request)
      @resp.delete(:response)
      @resp.delete(:request_headers)
      @resp.delete(:parallel_manager)
    end

  end
end
