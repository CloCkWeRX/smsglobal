require 'net/http'
require 'uri'

module SmsGlobal
  class Sender
    include Net

    def initialize(options = {})
      @options = options
      raise ArgumentError.new('missing :user') unless @options[:user]
      raise ArgumentError.new('missing :password') unless @options[:password]
      @options.each {|k,v| @options[k] = v.to_s if v }
      @base = @options[:base] || 'http://www.smsglobal.com/'
    end

    def send_text(text, to, sender = nil, send_at = nil)
      from = sender || @options[:from]
      raise ArgumentError.new('sender is required') unless from
      params = {
        :action => 'sendsms',
        :user => @options[:user],
        :password => @options[:password],
        :from => from,
        :to => to,
        :text => text
      }
      if send_at
        params[:scheduledatetime] = send_at.strftime('%Y-%m-%d %h:%M:%S')
      end
      params[:maxsplit] = @options[:maxsplit] if @options[:maxsplit]
      params[:userfield] = @options[:userfield] if @options[:userfield]
      params[:api] = @options[:api] if @options[:api]

      resp = get(params)

      case resp
      when Net::HTTPSuccess
        if resp.body =~ /^OK: (\d+); ([^\n]+)\s+SMSGlobalMsgID:\s*(\d+)\s*$/
          return {
            :status  => :ok,
            :code    => $1.to_i,
            :message => $2,
            :id      => $3.to_i
          }
        elsif resp.body =~ /^ERROR: (.+)$/
          msg = case $1
          when '402'
            'Invalid username/password'
          when '88'
            'No credits'
          when '102'
            'System time out'
          when '8'
            'Source or destination is too short'
          when '401'
            'Invalid credentials'
          when '13'
            'SMSGlobal was unable to contact the carrier'
          else
            $1
          end
          return {
            :status  => :error,
            :message => msg
          }
        else
          raise "Unable to parse response: '#{resp.body}'"
        end
      else
        return {
          :status  => :failed,
          :code    => resp.code,
          :message => 'Unable to reach SMSGlobal'
        }
      end
    end

    private
    
    def get(params = nil)
      url = URI.join(@base, 'http-api.php')
      if params
        url.query = params.map { |k,v| "%s=%s" % [URI.encode(k.to_s), URI.encode(v.to_s)] }.join("&")
      end
      res = HTTP.start(url.host, url.port) do |http|
        http.get(url.request_uri)
      end
    end
  end

end

