# Copyright 2015 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


require "delegate"

module Gcloud
  module Dns
    class Change
      ##
      # Change::List is a special case Array with additional values.
      class List < DelegateClass(::Array)
        ##
        # If not empty, indicates that there are more changes that match
        # the request and this value should be passed to continue.
        attr_accessor :token

        ##
        # @private Create a new Change::List with an array of Change instances.
        def initialize arr = []
          super arr
        end

        ##
        # Whether there a next page of zones.
        def next?
          !token.nil?
        end

        ##
        # Retrieve the next page of zones.
        def next
          return nil unless next?
          ensure_zone!
          @zone.changes token: token, max: @max, order: @order
        end

        ##
        # Retrieves all changes by repeatedly loading {#next} until {#next?}
        # returns `false`. Calls the given block once for each change, which is
        # passed as the parameter.
        #
        # An Enumerator is returned if no block is given.
        #
        # This method may make several API calls until all changes are
        # retrieved. Be sure to use as narrow a search criteria as possible.
        # Please use with caution.
        #
        # @example Iterating each change by passing a block:
        #   require "gcloud"
        #
        #   gcloud = Gcloud.new
        #   dns = gcloud.dns
        #   zone = dns.zone "example-com"
        #   changes = zone.changes
        #
        #   changes.all do |change|
        #     puts change.name
        #   end
        #
        # @example Using the enumerator by not passing a block:
        #   require "gcloud"
        #
        #   gcloud = Gcloud.new
        #   dns = gcloud.dns
        #   zone = dns.zone "example-com"
        #   changes = zone.changes
        #
        #   all_names = changes.all.map do |change|
        #     change.name
        #   end
        #
        # @example Limit the number of API calls made:
        #   require "gcloud"
        #
        #   gcloud = Gcloud.new
        #   dns = gcloud.dns
        #   zone = dns.zone "example-com"
        #   changes = zone.changes
        #
        #   changes.all(max_api_calls: 10) do |change|
        #     puts change.name
        #   end
        #
        def all max_api_calls: nil
          max_api_calls = max_api_calls.to_i if max_api_calls
          unless block_given?
            return enum_for(:all, max_api_calls: max_api_calls)
          end
          results = self
          loop do
            results.each { |r| yield r }
            if max_api_calls
              max_api_calls -= 1
              break if max_api_calls < 0
            end
            break unless results.next?
            results = results.next
          end
        end

        ##
        # @private New Changes::List from a response object.
        def self.from_response resp, zone, max = nil, order = nil
          changes = new(Array(resp.data["changes"]).map do |gapi_object|
            Change.from_gapi gapi_object, zone
          end)
          changes.instance_variable_set "@token", resp.data["nextPageToken"]
          changes.instance_variable_set "@zone",  zone
          changes.instance_variable_set "@max",   max
          changes.instance_variable_set "@order", order
          changes
        end

        protected

        ##
        # Raise an error unless an active connection is available.
        def ensure_zone!
          fail "Must have active connection" unless @zone
        end
      end
    end
  end
end
