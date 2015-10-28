require 'http'

require './lib/validations'
require './lib/conf'
require './lib/rack-oauth2-bearer'

module Rack::OAuth2::Bearer
  module RequestHelpers
    def heartbeat?
      path.match Conf::HEART_BEAT_REGEX
    end

    def has_token?
      bearer_token?
    end

    def bearer_token?
      !!bearer_token
    end

    def bearer_token
      regexp = Regexp.new(/Bearer\s+(.*)/i)

      if self.env.include?('HTTP_AUTHORIZATION')
        str = self.env['HTTP_AUTHORIZATION']
        matchdata = str.match(regexp)
        matchdata[1] if matchdata
      end
    end

    def valid_token?
      return false unless has_token?

      oauth_token_info_url = Conf::OAUTH_TOKEN_INFO_URL
      raise ArgumentError, 'Need oauth_token_info_url' unless oauth_token_info_url
      response = HTTP.get(oauth_token_info_url + bearer_token)
      response.code == 200
    end
  end
end
