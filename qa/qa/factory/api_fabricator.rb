# frozen_string_literal: true

require 'airborne'
require 'active_support/core_ext/object/deep_dup'
require 'capybara/dsl'

module QA
  module Factory
    module ApiFabricator
      include Airborne
      include Capybara::DSL

      HTTP_STATUS_OK = 200
      HTTP_STATUS_CREATED = 201

      ResourceNotFoundError = Class.new(RuntimeError)
      ResourceFabricationFailedError = Class.new(RuntimeError)
      ResourceURLMissingError = Class.new(RuntimeError)

      attr_reader :api_resource, :api_response

      def api_get_path
        raise NotImplementedError, "Factory #{self.class.name} does not support fabrication via the API!"
      end

      alias_method :api_post_path, :api_get_path
      alias_method :api_post_body, :api_get_path

      def api_support?
        api_get_path && api_post_path && api_post_body && true
      rescue NotImplementedError
        false
      end

      def fabricate_via_api!
        resource_web_url(api_post)
      end

      def eager_load_api_client!
        api_client.tap do |client|
          # Eager-load the API client so that the personal token creation isn't
          # taken in account in the actual resource creation timing.
          client.personal_access_token
        end
      end

      private

      attr_writer :api_resource, :api_response

      def resource_web_url(resource)
        resource.fetch(:web_url) do
          raise ResourceURLMissingError, "API resource for #{self.class.name} does not expose a `web_url` property: `#{resource}`."
        end
      end

      def api_get
        url = Runtime::API::Request.new(api_client, api_get_path).url
        response = get(url)

        unless response.code == HTTP_STATUS_OK
          raise ResourceNotFoundError, "Resource at #{url} could not be found (#{response.code}): `#{response}`."
        end

        process_api_response(parse_body(response))
      end

      def api_post
        response = post(
          Runtime::API::Request.new(api_client, api_post_path).url,
          api_post_body)

        unless response.code == HTTP_STATUS_CREATED
          raise ResourceFabricationFailedError, "Fabrication of #{self.class.name} using the API failed (#{response.code}) with `#{response}`."
        end

        process_api_response(parse_body(response))
      end

      def api_client
        @api_client ||= begin
          Runtime::API::Client.new(:gitlab, is_new_session: !current_url.start_with?('http'))
        end
      end

      def parse_body(response)
        JSON.parse(response.body, symbolize_names: true)
      end

      def process_api_response(parsed_response)
        self.api_response = parsed_response
        self.api_resource = transform_api_resource(parsed_response.deep_dup)
      end

      def transform_api_resource(resource)
        resource
      end
    end
  end
end
